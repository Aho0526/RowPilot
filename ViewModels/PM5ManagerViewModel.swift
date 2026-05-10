import Foundation
import CoreBluetooth
import Combine

// MARK: - Per-Device Metrics Model
/// 各PM5デバイスのリアルタイムメトリクスを保持
class PM5DeviceMetrics: ObservableObject, Identifiable {
    let id: UUID
    let name: String
    
    @Published var isConnected: Bool = true
    @Published var distance: Double = 0.0        // メートル
    @Published var elapsedTime: Double = 0.0      // 秒
    @Published var pace500m: Double = 0.0          // 秒 (500mペース)
    @Published var power: Int = 0                 // ワット
    @Published var strokeRate: Int = 0            // SPM
    @Published var workoutState: UInt8 = 0       // index 8 of 0x31
    
    /// ワークアウト送信ステータス
    enum ConfigStatus: Equatable {
        case idle
        case resetting
        case configuring
        case ready
        case error(String)
    }
    @Published var configStatus: ConfigStatus = .idle
    
    // Debug Data
    @Published var lastStrokeDataBytes: String = ""
    
    /// 表示番号（ユーザーが設定可能）
    @Published var displayNumber: Int = 0
    
    // Stroke計算用内部状態
    var lastStrokeCount: Int = -1
    var lastStrokeTime: Double = 0
    var lastStrokeDistance: Double = 0
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// マネージャー用PM5複数台接続管理ViewModel
/// Bluetooth管理クラスとViewModelを統合し、複数PM5の同時接続に対応
class PM5ManagerViewModel: NSObject, ObservableObject {
    
    // MARK: - Concept2 UUIDs
    private let C2_SERVICE_UUID = CBUUID(string: "CE060030-43E5-11E4-916C-0800200C9A66")
    private let C2_DEVICE_CONTROL_SERVICE = CBUUID(string: "CE060020-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_CONTROL_POINT = CBUUID(string: "CE060021-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_DATA_POINT = CBUUID(string: "CE060022-43E5-11E4-916C-0800200C9A66")
    
    // データ監視用 Characteristic UUIDs
    private let C2_CHAR_GENERAL_STATUS = CBUUID(string: "CE060031-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_ROWING_STATUS_0x32 = CBUUID(string: "CE060032-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_STROKE_DATA = CBUUID(string: "CE060035-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_POWER_DATA = CBUUID(string: "CE060033-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_ADDITIONAL_STROKE_DATA_0x36 = CBUUID(string: "CE060036-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_END_OF_WORKOUT = CBUUID(string: "CE060037-43E5-11E4-916C-0800200C9A66")
    
    // MARK: - CoreBluetooth
    private var centralManager: CBCentralManager!
    
    /// デバイスごとのControl Point Characteristicを保持
    private var controlCharacteristics: [UUID: CBCharacteristic] = [:]
    
    // MARK: - Published State（3層分離）
    
    /// BLEスキャンで検出されたPM5デバイス一覧
    @Published var discoveredDevices: [CBPeripheral] = []
    
    /// 接続試行中のデバイスID集合
    @Published var connectingDeviceIDs: Set<UUID> = []
    
    /// 接続成功したPM5デバイス一覧（切断されたものも含む）
    @Published var connectedDevices: [CBPeripheral] = []
    
    /// 切断中のデバイスID集合（グレー表示用）
    @Published var disconnectedDeviceIDs: Set<UUID> = []
    
    /// 意図的に削除され、自動再接続を許可しないデバイスのID集合
    @Published var ignoredDeviceIDs: Set<UUID> = []
    
    /// Bluetoothの電源状態
    @Published var isBluetoothPoweredOn: Bool = false
    
    /// スキャン中フラグ
    @Published var isScanning: Bool = false
    
    /// エラーメッセージ（接続失敗時に表示）
    @Published var errorMessage: String? = nil
    
    /// CSAFE送信中フラグ
    @Published var isSending: Bool = false
    
    /// 各デバイスのリアルタイムメトリクス
    @Published var deviceMetrics: [UUID: PM5DeviceMetrics] = [:]
    
    /// ワークアウト設定値
    @Published var workoutDistance: Int? = nil  // メートル
    @Published var workoutTime: Int? = nil      // 秒
    
    /// ダッシュボード表示フラグ
    @Published var showDashboard: Bool = false
    
    /// 保存済みフラグ
    @Published var isSaved: Bool = false
    
    /// デバイスごとの表示番号
    @Published var deviceNumbers: [UUID: Int] = [:]
    
    /// デバイスごとのカスタム名（Key: BLE名, Value: カスタム名）
    @Published var deviceCustomNames: [String: String] = [:]
    
    /// ワークアウト開始時間
    var workoutStartTime: Date? = nil
    
    /// CSAFE コマンドのシリアライズキュー（複数デバイスへの送信を1台ずつ順次実行）
    private let commandQueue = CSAFECommandQueue()
    
    private var pollingTimer: Timer?
    private var lastHaltTime: Date? = nil
    
    /// GoReady完了後に送信するワークアウト設定（イベント駆動用）
    private var pendingWorkoutAfterReset: (distance: Int?, time: Int?)? = nil
    
    // MARK: - Computed Properties
    
    /// 番号順にソートされた接続デバイス一覧
    var sortedConnectedDevices: [CBPeripheral] {
        connectedDevices.sorted { a, b in
            let numA = deviceNumbers[a.identifier] ?? Int.max
            let numB = deviceNumbers[b.identifier] ?? Int.max
            return numA < numB
        }
    }
    
    /// 検出済みリストから接続済み・接続試行中を除外した表示用リスト
    var availableDevices: [CBPeripheral] {
        let excludedIDs = Set(connectedDevices.map { $0.identifier }).union(connectingDeviceIDs)
        return discoveredDevices.filter { !excludedIDs.contains($0.identifier) }
    }
    
    /// 「次へ」ボタンの有効状態
    var canProceed: Bool {
        !connectedDevices.isEmpty
    }
    
    // MARK: - Init
    
    override init() {
        super.init()
        loadCustomNames()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    deinit {
        disconnectAll()
    }
    
    // MARK: - Scanning
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        if !isScanning {
            // 既存の検出リストをクリア（再スキャン時）
            discoveredDevices.removeAll()
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            isScanning = true
            print("PM5ManagerVM: スキャン開始")
        }
    }
    
    func stopScanning() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
            print("PM5ManagerVM: スキャン停止")
        }
    }
    
    
    // MARK: - CSAFE Command Generation
    
    /// PM5デバイスを追加（接続試行）
    func addDevice(_ peripheral: CBPeripheral) {
        guard !connectingDeviceIDs.contains(peripheral.identifier),
              !connectedDevices.contains(where: { $0.identifier == peripheral.identifier }) else {
            return
        }
        
        errorMessage = nil
        ignoredDeviceIDs.remove(peripheral.identifier)
        connectingDeviceIDs.insert(peripheral.identifier)
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        print("PM5ManagerVM: 接続試行 → \(peripheral.name ?? "Unknown")")
    }
    
    /// 接続済みPM5を削除（切断）
    func removeDevice(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
        connectedDevices.removeAll { $0.identifier == peripheral.identifier }
        disconnectedDeviceIDs.remove(peripheral.identifier)
        controlCharacteristics.removeValue(forKey: peripheral.identifier)
        deviceMetrics.removeValue(forKey: peripheral.identifier)
        ignoredDeviceIDs.insert(peripheral.identifier)
        // 再スキャンまで検出一覧には戻さない
        
        // 番号の振り直し
        reassignDeviceNumbers()
        
        print("PM5ManagerVM: 削除 → \(peripheral.name ?? "Unknown")")
    }
    
    /// デバイスの順序を入れ替え
    func moveDevice(from source: IndexSet, to destination: Int) {
        connectedDevices.move(fromOffsets: source, toOffset: destination)
        reassignDeviceNumbers()
        print("PM5ManagerVM: デバイス順序変更")
    }
    
    private func reassignDeviceNumbers() {
        for (index, device) in connectedDevices.enumerated() {
            deviceNumbers[device.identifier] = index + 1
        }
    }
    
    // MARK: - Custom Name Management
    
    private static let customNamesKey = "PM5DeviceCustomNames"
    
    /// カスタム名を取得（未設定の場合はBLE名を返す）
    func displayName(for peripheral: CBPeripheral) -> String {
        let bleName = peripheral.name ?? "Unknown PM5"
        return deviceCustomNames[bleName] ?? bleName
    }
    
    /// カスタム名を設定して永続化
    func setCustomName(_ customName: String, for bleName: String) {
        if customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deviceCustomNames.removeValue(forKey: bleName)
        } else {
            deviceCustomNames[bleName] = customName
        }
        saveCustomNames()
    }
    
    /// UserDefaultsからカスタム名を読み込む
    private func loadCustomNames() {
        if let saved = UserDefaults.standard.dictionary(forKey: Self.customNamesKey) as? [String: String] {
            deviceCustomNames = saved
        }
    }
    
    /// UserDefaultsにカスタム名を保存する
    private func saveCustomNames() {
        UserDefaults.standard.set(deviceCustomNames, forKey: Self.customNamesKey)
    }
    
    /// 全PM5を切断してリストをクリア
    func disconnectAll() {
        for device in connectedDevices {
            centralManager.cancelPeripheralConnection(device)
        }
        connectedDevices.removeAll()
        connectingDeviceIDs.removeAll()
        disconnectedDeviceIDs.removeAll()
        ignoredDeviceIDs.removeAll()
        controlCharacteristics.removeAll()
        discoveredDevices.removeAll()
        deviceMetrics.removeAll()
        showDashboard = false
        workoutDistance = nil
        workoutTime = nil
        workoutStartTime = nil
        stopScanning()
        print("PM5ManagerVM: 全PM5切断・リストクリア")
    }
    
    // MARK: - CSAFE Workout Commands（全PM5に共通送信）
    
    /// CSAFEチェックサムを計算
    private func calculateCSAFEChecksum(for data: Data) -> UInt8 {
        var checksum: UInt8 = 0
        for byte in data {
            checksum ^= byte
        }
        return checksum
    }
    
    /// CSAFE Byte Stuffing: ペイロード内の特殊制御バイトをエスケープ
    private func byteStuff(_ data: Data) -> Data {
        var stuffed = Data()
        for byte in data {
            switch byte {
            case 0xF0: stuffed.append(contentsOf: [0xF3, 0x00])
            case 0xF1: stuffed.append(contentsOf: [0xF3, 0x01])
            case 0xF2: stuffed.append(contentsOf: [0xF3, 0x02])
            case 0xF3: stuffed.append(contentsOf: [0xF3, 0x03])
            default:   stuffed.append(byte)
            }
        }
        return stuffed
    }
    
    /// フレーム送信前に意図しない SET_SCREENSTATE (ScreenType=3) を検出
    private func validateCSAFEFrame(_ frame: Data) -> Bool {
        let bytes = [UInt8](frame)
        guard bytes.first == 0xF1, bytes.last == 0xF2 else {
            print("PM5ManagerVM: 🚨 Invalid CSAFE frame: Missing start/end flags")
            return false
        }
        let payload = Array(bytes.dropFirst().dropLast())
        for i in 0..<(payload.count - 3) {
            if payload[i] == 0x13 && payload[i+1] == 0x02 {
                let param1 = payload[i+2]
                let param2 = payload[i+3]
                if param1 == 0x03 || param2 == 0x03 {
                    print("PM5ManagerVM: 🚨 BLOCKED: SET_SCREENSTATE would trigger CSAFE User ID screen!")
                    print("   Params: ScreenType=\(String(format: "0x%02X", param1)), ScreenValue=\(String(format: "0x%02X", param2))")
                    return false
                }
            }
        }
        return true
    }
    
    /// ペイロードからバイトスタッフィング＋バリデーション済みの完全なCSAFEフレームを構築
    private func buildCSAFEFrame(payload: Data) -> Data? {
        let checksum = calculateCSAFEChecksum(for: payload)
        var checksummedPayload = Data()
        checksummedPayload.append(payload)
        checksummedPayload.append(checksum)
        
        let stuffed = byteStuff(checksummedPayload)
        
        var frame = Data()
        frame.append(0xF1)
        frame.append(stuffed)
        frame.append(0xF2)
        
        guard validateCSAFEFrame(frame) else {
            return nil
        }
        return frame
    }
    
    /// 全接続デバイスに対するCSAFEコマンド配列を構築しキューに投入する
    private func enqueueToAllDevices(
        frame: Data,
        label: String,
        devices: [CBPeripheral]? = nil,
        perDeviceStatus: PM5DeviceMetrics.ConfigStatus? = nil,
        completion: (() -> Void)? = nil
    ) {
        let targets = devices ?? connectedDevices
        var commands: [CSAFECommandQueue.Command] = []
        
        for device in targets {
            guard let char = controlCharacteristics[device.identifier] else {
                print("PM5ManagerVM: Control Point未発見 → \(device.name ?? "Unknown") (\(label))")
                continue
            }
            
            // 送信開始時にステータスを更新
            if let initialStatus = perDeviceStatus {
                DispatchQueue.main.async {
                    self.deviceMetrics[device.identifier]?.configStatus = initialStatus
                }
            }
            
            commands.append(CSAFECommandQueue.Command(
                peripheral: device,
                characteristic: char,
                frame: frame,
                label: label
            ))
        }
        
        if commands.isEmpty {
            completion?()
            return
        }
        
        commandQueue.enqueueSequential(commands, perDeviceCompletion: { [weak self] peripheral, isSuccess in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let metrics = self.deviceMetrics[peripheral.identifier] {
                    // Phaseに応じて適切な完了ステータスへ遷移させるためのフック
                    // (ここでは簡易的に成功時はそのまま、失敗時はエラーを表示)
                    if !isSuccess {
                        metrics.configStatus = .error("Timeout")
                    } else if label.contains("WORKOUT") {
                        metrics.configStatus = .ready
                    }
                }
            }
        }, completion: completion)
    }
    
    /// ワークアウトコマンドを生成
    private func generateWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil) -> Data {
        var payload = Data()
        
        func appendUInt32(_ value: UInt32) {
            let val = value.bigEndian
            withUnsafeBytes(of: val) { payload.append(contentsOf: $0) }
        }
        
        // 1. CSAFE_PM_SET_WORKOUTTYPE
        payload.append(contentsOf: [0x01, 0x01])
        payload.append(distanceMeters != nil ? 0x03 : 0x05)
        
        // 2. CSAFE_PM_SET_WORKOUTDURATION
        payload.append(contentsOf: [0x03, 0x05])
        if let dist = distanceMeters {
            payload.append(0x80)
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(0x00)
            appendUInt32(UInt32(time * 100))
        }
        
        // 3. CSAFE_PM_SET_SPLITDURATION
        payload.append(contentsOf: [0x05, 0x05])
        if let dm = distanceMeters {
            payload.append(0x80)
            appendUInt32(UInt32(dm))
        } else if let tm = timeSeconds {
            payload.append(0x00)
            appendUInt32(UInt32(max(tm / 2, 1) * 100))
        }
        
        // 4. CSAFE_PM_CONFIGURE_WORKOUT
        payload.append(contentsOf: [0x14, 0x01, 0x01])
        
        // 5. CSAFE_PM_SET_SCREENSTATE
        payload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
        
        // Wrap in Extended Command
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        
        return fullCommand
    }
    
    /// 距離ワークアウトを全PM5に送信（Phase 2: CONFIG）
    private func setWorkoutDistance(meters: Int) {
        let limitedMeters = min(max(meters, 100), 60000)
        
        // 楽観的UI更新: 送信開始時にダッシュボードを即座に表示
        isSending = true
        workoutDistance = limitedMeters
        workoutTime = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        guard let workoutFrame = buildCSAFEFrame(payload: generateWorkoutCommand(distanceMeters: limitedMeters)) else {
            print("PM5ManagerVM: ⛔ Workout frame construction failed")
            isSending = false
            return
        }
        
        // ワークアウト設定を全デバイスに送信 (並行)
        enqueueToAllDevices(
            frame: workoutFrame,
            label: "WORKOUT_DIST_\(limitedMeters)m",
            perDeviceStatus: .configuring
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSending = false
                self.isSaved = false
                print("PM5ManagerVM: ✅ 距離ワークアウト \(limitedMeters)m を全PM5に送信完了")
            }
        }
    }
    
    /// 時間ワークアウトを全PM5に送信（Phase 2: CONFIG）
    private func setWorkoutTime(seconds: Int) {
        let limitedSeconds = min(max(seconds, 20), 36000)
        
        // 楽観的UI更新: 送信開始時にダッシュボードを即座に表示
        isSending = true
        workoutTime = limitedSeconds
        workoutDistance = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        guard let workoutFrame = buildCSAFEFrame(payload: generateWorkoutCommand(timeSeconds: limitedSeconds)) else {
            print("PM5ManagerVM: ⛔ Workout frame construction failed")
            isSending = false
            return
        }
        
        // ワークアウト設定を全デバイスに送信 (並行)
        enqueueToAllDevices(
            frame: workoutFrame,
            label: "WORKOUT_TIME_\(limitedSeconds)s",
            perDeviceStatus: .configuring
        ) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSending = false
                self.isSaved = false
                print("PM5ManagerVM: ✅ 時間ワークアウト \(limitedSeconds)s を全PM5に送信完了")
            }
        }
    }
    
    /// 全デバイスのメトリクスを初期化
    private func initializeAllMetrics() {
        for device in connectedDevices {
            if deviceMetrics[device.identifier] == nil {
                deviceMetrics[device.identifier] = PM5DeviceMetrics(
                    id: device.identifier, name: device.name ?? "Unknown PM5"
                )
            }
        }
    }
    
    /// 全デバイスに終了・リセットシーケンスを開始（シリアライズキュー経由）
    func resetAllDevices() {
        print("PM5ManagerVM: Resetting all devices (Unconditional STOP)")
        lastHaltTime = Date()
        
        let terminateFrame = Data([0xF1, 0x76, 0x04, 0x13, 0x02, 0x01, 0x02, 0x60, 0xF2])
        
        // 全デバイスのメトリクスをクリア
        for device in connectedDevices {
            if let metrics = deviceMetrics[device.identifier] {
                DispatchQueue.main.async {
                    metrics.distance = 0
                    metrics.elapsedTime = 0
                    metrics.pace500m = 0
                    metrics.power = 0
                    metrics.strokeRate = 0
                    metrics.lastStrokeCount = -1
                }
            }
        }
        
        // Terminate を全デバイスに並行送信
        enqueueToAllDevices(
            frame: terminateFrame,
            label: "TERMINATE_RESET",
            perDeviceStatus: .resetting
        ) { [weak self] in
            print("PM5ManagerVM: TERMINATE sent to all devices.")
            self?.onAllDevicesReadyAfterReset()
        }
    }
    
    /// 全接続済みデバイスに強制終了コマンドを順次送信（内部用）
    private func sendTerminateToAllDevices(completion: (() -> Void)? = nil) {
        let terminateFrame = Data([0xF1, 0x76, 0x04, 0x13, 0x02, 0x01, 0x02, 0x60, 0xF2])
        print("PM5ManagerVM: Sending MANDATORY TERMINATE command to ALL connected devices (serialized)")
        enqueueToAllDevices(frame: terminateFrame, label: "TERMINATE", completion: completion)
    }
    
    /// リセットした後に同じ設定でワークアウトを再開する（イベント駆動）
    /// GoReady完了後に1秒待機してからワークアウトを送信
    func resetAndStartWorkout(distance: Int? = nil, time: Int? = nil) {
        print("PM5ManagerVM: Resetting and queuing new workout (Immediate transition to dashboard)")
        
        // 1. 即座にダッシュボードへ遷移
        isSending = true
        showDashboard = true
        workoutDistance = distance
        workoutTime = time
        workoutStartTime = Date()
        initializeAllMetrics()
        
        // 全デバイスのステータスを初期化
        for device in connectedDevices {
            deviceMetrics[device.identifier]?.configStatus = .resetting
        }
        
        // 2. ペンディングワークアウトを保存（GoReady完了後に使用）
        pendingWorkoutAfterReset = (distance: distance, time: time)
        
        // 3. リセット送信
        resetAllDevices()
    }
    
    /// 全デバイスに終了コマンドが送信された後に呼ばれる
    private func onAllDevicesReadyAfterReset() {
        guard let pending = pendingWorkoutAfterReset else {
            print("PM5ManagerVM: No pending workout after reset.")
            return
        }
        pendingWorkoutAfterReset = nil
        
        print("PM5ManagerVM: ✅ All devices TERMINATE sent. Waiting 0.8s for PM5 internal state transition...")
        
        // Terminate後のPM5内部状態遷移を待つ（0.8秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            print("PM5ManagerVM: Post-Terminate delay complete. Sending pending workout.")
            
            if let dist = pending.distance {
                self.setWorkoutDistance(meters: dist)
            } else if let t = pending.time {
                self.setWorkoutTime(seconds: t)
            }
        }
    }
    
    /// 全デバイスの記録を保存
    func saveAllRecords(recordManager: RecordManager) {
        print("PM5ManagerVM: Saving records for all connected devices")
        for (_, metrics) in deviceMetrics {
            if metrics.distance > 0 || metrics.elapsedTime > 0 {
                let recordDate: Date = workoutStartTime ?? Date()
                let recordDuration: TimeInterval = metrics.elapsedTime
                let recordDistance: Double = metrics.distance
                let recordSPM: Int = metrics.strokeRate
                let recordSpeed: Double = (metrics.distance / max(metrics.elapsedTime, 1)) * 3.6
                let recordPace: TimeInterval = metrics.pace500m
                let recordPower: Int? = metrics.power > 0 ? metrics.power : nil
                let recordType: String = workoutDistance != nil ? "distance" : (workoutTime != nil ? "time" : "justRow")
                let recordNotes: String = "Indoor Workout (Manager Mode) - \(metrics.name)"
                let recordTags: [String] = ["ManagerMode", "Indoor"]
                
                let record = RowingRecord(
                    id: UUID(),
                    date: recordDate,
                    duration: recordDuration,
                    distance: recordDistance,
                    averageSPM: recordSPM,
                    averageSpeed: recordSpeed,
                    averagePace: recordPace,
                    startLocation: nil,
                    endLocation: nil,
                    notes: "\(recordNotes) | Type: \(recordType) | Power: \(recordPower.map { "\($0)W" } ?? "N/A")",
                    tags: recordTags
                )
                recordManager.addRecord(record)
            }
        }
        isSaved = true
    }
}

// MARK: - CBCentralManagerDelegate
extension PM5ManagerViewModel: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothPoweredOn = (central.state == .poweredOn)
        print("PM5ManagerVM: Bluetooth状態 → \(central.state.rawValue)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        guard name.contains("PM5") else { return }
        
        // 重複チェック
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
            print("PM5ManagerVM: PM5検出 → \(name)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("PM5ManagerVM: 接続成功 → \(peripheral.name ?? "Unknown")")
        
        connectingDeviceIDs.remove(peripheral.identifier)
        
        // 切断状態から復帰
        disconnectedDeviceIDs.remove(peripheral.identifier)
        
        // メトリクスの接続状態を更新
        deviceMetrics[peripheral.identifier]?.isConnected = true
        
        // 接続済みリストに追加（重複防止）
        if !connectedDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            // 番号が未割り当てなら自動付与
            if deviceNumbers[peripheral.identifier] == nil {
                let nextNumber = (deviceNumbers.values.max() ?? 0) + 1
                deviceNumbers[peripheral.identifier] = nextNumber
            }
            connectedDevices.append(peripheral)
        }
        
        // サービス検出（Control + Data）
        peripheral.delegate = self
        peripheral.discoverServices([C2_DEVICE_CONTROL_SERVICE, C2_SERVICE_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("PM5ManagerVM: 接続失敗 → \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "")")
        
        connectingDeviceIDs.remove(peripheral.identifier)
        errorMessage = "\(peripheral.name ?? "Unknown") への接続に失敗しました"
        
        // 3秒後にエラーメッセージをクリア
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("PM5ManagerVM: 切断検出 → \(peripheral.name ?? "Unknown")")
        
        // リストから消さずに切断状態としてマーク
        disconnectedDeviceIDs.insert(peripheral.identifier)
        controlCharacteristics.removeValue(forKey: peripheral.identifier)
        
        // メトリクスの接続状態を更新
        deviceMetrics[peripheral.identifier]?.isConnected = false
        
        // 意図的な削除でなければ自動再接続を試行
        if !ignoredDeviceIDs.contains(peripheral.identifier) {
            centralManager.connect(peripheral, options: nil)
            print("PM5ManagerVM: 自動再接続試行 → \(peripheral.name ?? "Unknown")")
        } else {
            print("PM5ManagerVM: 意図的な削除のため自動再接続をスキップ → \(peripheral.name ?? "Unknown")")
        }
    }
}

// MARK: - CBPeripheralDelegate
extension PM5ManagerViewModel: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == C2_DEVICE_CONTROL_SERVICE {
                peripheral.discoverCharacteristics([C2_CHAR_CONTROL_POINT, C2_CHAR_DATA_POINT], for: service)
            }
            if service.uuid == C2_SERVICE_UUID {
                peripheral.discoverCharacteristics(
                    [C2_CHAR_GENERAL_STATUS, C2_CHAR_ROWING_STATUS_0x32, C2_CHAR_STROKE_DATA, C2_CHAR_ADDITIONAL_STROKE_DATA_0x36, C2_CHAR_END_OF_WORKOUT],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == C2_CHAR_CONTROL_POINT {
                controlCharacteristics[peripheral.identifier] = characteristic
                print("PM5ManagerVM: Control Point発見 → \(peripheral.name ?? "Unknown")")
            }
            if characteristic.uuid == C2_CHAR_DATA_POINT {
                peripheral.setNotifyValue(true, for: characteristic)
                print("PM5ManagerVM: Data Point発見 & Notify購読開始 → \(peripheral.name ?? "Unknown")")
            }
            // データ監視用: Notify購読
            if [C2_CHAR_GENERAL_STATUS, C2_CHAR_ROWING_STATUS_0x32, C2_CHAR_STROKE_DATA, C2_CHAR_ADDITIONAL_STROKE_DATA_0x36].contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("PM5ManagerVM: Notify購読開始 → \(characteristic.uuid.uuidString.prefix(8)) on \(peripheral.name ?? "Unknown")")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        
        let deviceID = peripheral.identifier
        
        // メトリクスオブジェクトがなければ作成
        if deviceMetrics[deviceID] == nil {
            let metrics = PM5DeviceMetrics(id: deviceID, name: peripheral.name ?? "Unknown PM5")
            DispatchQueue.main.async {
                self.deviceMetrics[deviceID] = metrics
            }
        }
        
        if characteristic.uuid == C2_CHAR_GENERAL_STATUS {
            parseManagerGeneralStatus(data, for: deviceID)
        } else if characteristic.uuid == C2_CHAR_ROWING_STATUS_0x32 {
            parseManagerRowingStatus0x32(data, for: deviceID)
        } else if characteristic.uuid == C2_CHAR_STROKE_DATA {
            parseManagerStrokeData(data, for: deviceID)
        } else if characteristic.uuid == C2_CHAR_ADDITIONAL_STROKE_DATA_0x36 {
            parseManagerStrokeData0x36(data, for: deviceID)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("PM5ManagerVM: Notify設定エラー \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        print("PM5ManagerVM: Notify状態更新 \(characteristic.uuid.uuidString.prefix(8)): \(characteristic.isNotifying) on \(peripheral.name ?? "Unknown")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // コマンドキューに対して書き込み完了を通知
        commandQueue.handleWriteComplete(for: peripheral, error: error)
    }
}

// MARK: - BLE Data Parsing (per-device)
extension PM5ManagerViewModel {
    
    
    /// General Status (0x31): 距離と経過時間をパース
    private func parseManagerGeneralStatus(_ data: Data, for deviceID: UUID) {
        guard data.count >= 6 else { return }
        
        // 経過時間: byte[0-2], Little Endian, 0.01秒単位
        let timeVal = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16)
        let timeSec = Double(timeVal) * 0.01
        
        // 距離: byte[3-5], Little Endian, 0.1m単位
        let distRaw = UInt32(data[3]) | (UInt32(data[4]) << 8) | (UInt32(data[5]) << 16)
        let distMeters = Double(distRaw) * 0.1
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let metrics = self.deviceMetrics[deviceID] else { return }
            metrics.elapsedTime = timeSec
            metrics.distance = distMeters
            
            if data.count >= 9 {
                let ws = data[8]
                let previousWorkoutState = metrics.workoutState
                metrics.workoutState = ws
                // Note: Removed non-existent properties lastGeneralStatusByte8, isWaitingForResetAfterHalt, and resetRowingMetrics for compile success.
            }
            self.objectWillChange.send()
        }
    }
    
    /// Rowing Status (0x32): レート(SPM)をパース（byte 5）, ペースをパース（byte[7-8]）
    private func parseManagerRowingStatus0x32(_ data: Data, for deviceID: UUID) {
        // User formula: ((Byte 8 * 256) + Byte 7) / 100
        guard data.count >= 9 else { return }
        let rate = Int(data[5])
        let paceRaw = UInt16(data[7]) | (UInt16(data[8]) << 8)
        let paceSec = Double(paceRaw) / 100.0
        
        DispatchQueue.main.async { [weak self] in
            guard let metrics = self?.deviceMetrics[deviceID] else { return }
            if rate > 0 {
                metrics.strokeRate = rate
            }
            if paceRaw > 0 {
                metrics.pace500m = paceSec
            } else {
                metrics.pace500m = 0.0
            }
            self?.objectWillChange.send()
        }
    }

    /// Stroke Data (0x35): 生データを保持（デバッグ用）
    private func parseManagerStrokeData(_ data: Data, for deviceID: UUID) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        DispatchQueue.main.async { [weak self] in
            guard let metrics = self?.deviceMetrics[deviceID] else { return }
            metrics.lastStrokeDataBytes = hex
            self?.objectWillChange.send()
        }
    }

    /// Additional Stroke Data (0x36): ワット数と精密ペースをパース
    private func parseManagerStrokeData0x36(_ data: Data, for deviceID: UUID) {
        // Target: byte[3-4] for Watts (Little Endian)
        guard data.count >= 5 else { return }
        
        let wattsRaw = UInt16(data[3]) | (UInt16(data[4]) << 8)
        let watts = Int(wattsRaw)
        
        DispatchQueue.main.async { [weak self] in
            guard let metrics = self?.deviceMetrics[deviceID] else { return }
            metrics.power = watts
            self?.objectWillChange.send()
        }
    }
}

