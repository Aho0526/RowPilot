import Foundation
import CoreBluetooth
import Combine

// MARK: - Variable Interval Entry Model
/// Variable Intervalの1インターバル設定
struct VariableIntervalEntry: Identifiable, Equatable {
    let id = UUID()
    var distanceMeters: Int?    // 距離インターバル (m)
    var timeSeconds: Int?       // 時間インターバル (秒)
    var restSeconds: Int        // 休憩時間 (秒, Max 9:55 = 595)
    var targetPace500mSeconds: Int? // ターゲットペース (秒/500m), nilで無設定
    
    static func distanceEntry(meters: Int, rest: Int, pace: Int? = nil) -> VariableIntervalEntry {
        VariableIntervalEntry(distanceMeters: meters, timeSeconds: nil, restSeconds: min(rest, 595), targetPace500mSeconds: pace)
    }
    
    static func timeEntry(seconds: Int, rest: Int, pace: Int? = nil) -> VariableIntervalEntry {
        VariableIntervalEntry(distanceMeters: nil, timeSeconds: seconds, restSeconds: min(rest, 595), targetPace500mSeconds: pace)
    }
}

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
        case polling
        case configuring
        case ready
        case degraded(String)
        case error(String)
    }
    @Published var configStatus: ConfigStatus = .idle
    
    /// CSAFE State Machine State (Table 9 - Response Status Byte Bit-Mapping)
    /// Status byte bits 3-0 から取得される PM5 の状態
    enum PM5MachineState: UInt8 {
        case error = 0x00
        case ready = 0x01
        case idle = 0x02
        case haveID = 0x03
        case inUse = 0x05
        case pause = 0x06
        case finish = 0x07
        case manual = 0x08
        case offline = 0x09
        case unknown = 0xFF
        
        var description: String {
            switch self {
            case .error: return "Error"
            case .ready: return "Ready"
            case .idle: return "Idle"
            case .haveID: return "HaveID"
            case .inUse: return "InUse"
            case .pause: return "Pause"
            case .finish: return "Finish"
            case .manual: return "Manual"
            case .offline: return "Offline"
            case .unknown: return "Unknown"
            }
        }
    }
    @Published var machineState: PM5MachineState = .unknown
    @Published var isMachineBusy: Bool = false

    
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
    @Published var workoutSplitDistance: Int? = nil // スプリット距離
    @Published var workoutSplitTime: Int? = nil     // スプリット時間
    @Published var workoutRestTime: Int? = nil      // 休憩時間（秒）
    
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
    private var pendingWorkoutAfterReset: (distance: Int?, time: Int?, split: Int?)? = nil
    
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
    /// v4: Extended frame (F0) にも対応
    private func validateCSAFEFrame(_ frame: Data) -> Bool {
        let bytes = [UInt8](frame)
        guard (bytes.first == 0xF0 || bytes.first == 0xF1), bytes.last == 0xF2 else {
            print("PM5ManagerVM: 🚨 Invalid CSAFE frame: Missing start/end flags")
            return false
        }
        // Extended frame の場合、アドレス2バイトをスキップしてペイロードを検査
        let skipCount = (bytes.first == 0xF0) ? 3 : 1  // F0 + Dest + Src vs F1
        let payload = Array(bytes.dropFirst(skipCount).dropLast())
        guard payload.count >= 4 else { return true }
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
    
    /// v4: Extended CSAFE Frame を構築 (Concept2仕様 Figure 2)
    /// Structure: F0 [Dest] [Src] [Stuffed(Frame Contents + Checksum)] F2
    /// - Checksum: Frame Contents のみの XOR (アドレスを含まない)
    /// - Byte Stuffing: アドレス + Frame Contents + Checksum に適用
    /// - Dest: 0xFD (Default secondary), Src: 0x00 (Host)
    /// CSAFEフレームを構築（パディング、チェックサム、バイトスタッフィング）
    /// - startFlag: 0xF0 (Standard) または 0xF1 (Extended)
    /// - Byte Stuffing: アドレス + Frame Contents + Checksum に適用
    /// - Dest: 0xFD (Default secondary), Src: 0x00 (Host)
    private func buildCSAFEFrame(payload: Data, startFlag: UInt8 = 0xF0) -> Data? {
        if startFlag == 0xF1 {
            // F1 (Standard/Compact) Frame: F1 [FrameContents] [Checksum] F2
            // 仕様書通り、アドレスバイト(FD 00)なし、payloadのみでチェックサムを計算
            let checksum = calculateCSAFEChecksum(for: payload)
            var frame = Data()
            frame.append(0xF1)  // Standard Start Flag
            frame.append(payload)
            frame.append(checksum)
            frame.append(0xF2)  // Stop Flag
            guard validateCSAFEFrame(frame) else { return nil }
            return frame
        }
        
        // F0 (Extended) Frame: F0 [Dest] [Src] [FrameContents] [Checksum] F2
        // 1. Checksum = XOR of frame contents only (アドレスを含まない)
        let checksum = calculateCSAFEChecksum(for: payload)
        
        // 2. Byte stuffing 対象: [Dest][Src][FrameContents][Checksum]
        var stuffingTarget = Data()
        stuffingTarget.append(0xFD)  // Destination: Default secondary address
        stuffingTarget.append(0x00)  // Source: Host
        stuffingTarget.append(payload)
        stuffingTarget.append(checksum)
        
        let stuffed = byteStuff(stuffingTarget)
        
        // 3. 完全なフレーム: F0 [Stuffed data] F2
        var frame = Data()
        frame.append(0xF0)  // Extended Start Flag
        frame.append(stuffed)
        frame.append(0xF2)  // Stop Flag
        
        guard validateCSAFEFrame(frame) else { return nil }
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
    private func generateWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil, splitMeters: Int? = nil, splitSeconds: Int? = nil) -> Data {
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
            let splitValue = splitMeters ?? dm
            appendUInt32(UInt32(splitValue))
        } else if let tm = timeSeconds {
            payload.append(0x00)
            let splitValue = splitSeconds ?? (tm / 2)
            appendUInt32(UInt32(max(splitValue, 1) * 100))
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
    
    /// 不変インターバル（固定距離/時間）ワークアウトコマンドを生成
    /// 公式ドキュメント (P91/92) に準拠したバイナリレベル・シリアライズ実装
    private func generateIntervalWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil, restSeconds: Int) -> Data {
        var payload = Data()
        
        func appendUInt32(_ value: UInt32) {
            let bytes = withUnsafeBytes(of: value.bigEndian) { Data($0) }
            payload.append(bytes)
        }
        
        // 1. CSAFE_PM_SET_WORKOUTTYPE
        // 公式仕様: 0x06 = Fixed Time Interval, 0x07 = Fixed Distance Interval
        payload.append(contentsOf: [0x01, 0x01])
        payload.append(distanceMeters != nil ? 0x07 : 0x06)
        
        // 2. CSAFE_PM_SET_WORKOUTDURATION
        // Byte 0x03, length=0x05: [Type(1)] + [Value(4, Big Endian)]
        payload.append(contentsOf: [0x03, 0x05])
        if let dist = distanceMeters {
            payload.append(0x80) // Meters
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(0x00) // Time (0.01s units)
            appendUInt32(UInt32(time * 100))
        }
        
        // 3. CSAFE_PM_SET_RESTDURATION
        // 公式仕様: 0x04, length=0x02, [RestHigh][RestLow] (UInt16, Big Endian, 単位:秒)
        // 誤: 0x04 0x03 0x00 XX XX (長づ3バイト)は不正。正しくは length=2
        payload.append(0x04)
        payload.append(0x02)
        let rSec = UInt16(min(restSeconds, 595)) // Max 9:55
        payload.append(UInt8((rSec >> 8) & 0xFF))
        payload.append(UInt8(rSec & 0xFF))
        
        // 4. CSAFE_PM_CONFIGURE_WORKOUT
        payload.append(contentsOf: [0x14, 0x01, 0x01])
        
        // 5. CSAFE_PM_SET_SCREENSTATE
        payload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
        
        // Wrap in CSAFE_SETPMCFG_CMD (0x76): 0x76 [len] [payload]
        // len = payload実サイズ（可変）→ 固定値不使用、必ず自動計算
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        
        let hexStr = fullCommand.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("PM5ManagerVM: [INTERVAL] CSAFE inner payload = \(hexStr)")
        
        return fullCommand
    }
    
    // MARK: - Variable Interval (P93-96)
    
    /// Variable Interval 1インターバル分のCSAFEブロックを生成
    /// 仕様書P93-96: WORKOUTINTERVALCOUNT + SET_INTERVALTYPE + WORKOUTDURATION + RESTDURATION + TARGETPACETIME + CONFIGURE_WORKOUT
    private func buildVariableIntervalBlock(index: Int, entry: VariableIntervalEntry) -> Data {
        var block = Data()
        
        func appendUInt32(_ v: UInt32, to data: inout Data) {
            withUnsafeBytes(of: v.bigEndian) { data.append(contentsOf: $0) }
        }
        
        // CSAFE_PM_WORKOUTINTERVALCOUNT (0x18): インターバル番号（0-indexed）
        block.append(contentsOf: [0x18, 0x01, UInt8(index)])
        
        // CSAFE_PM_SET_INTERVALTYPE (0x17)
        // 仕様書P94: INTERVALTYPE_DIST = 0x01, INTERVALTYPE_TIME = 0x00
        block.append(contentsOf: [0x17, 0x01])
        block.append(entry.distanceMeters != nil ? 0x01 : 0x00) // 0x01=DIST, 0x00=TIME
        
        // CSAFE_PM_SET_WORKOUTDURATION (0x03): 距離 or 時間
        block.append(contentsOf: [0x03, 0x05])
        if let dist = entry.distanceMeters {
            block.append(0x80) // 距離識別子
            appendUInt32(UInt32(dist), to: &block)
        } else if let time = entry.timeSeconds {
            block.append(0x00) // 時間識別子
            appendUInt32(UInt32(time * 100), to: &block) // 0.01s単位
        }
        
        // CSAFE_PM_SET_RESTDURATION (0x04): 休憩時間 (UInt16, 秒)
        block.append(0x04)
        block.append(0x02)
        let rSec = UInt16(min(entry.restSeconds, 595))
        block.append(UInt8((rSec >> 8) & 0xFF))
        block.append(UInt8(rSec & 0xFF))
        
        // CSAFE_PM_SET_TARGETPACETIME (0x06): ターゲットペース (4バイト, 0.01s単位)
        // ペース未設定時は0（PM5デフォルト）
        block.append(contentsOf: [0x06, 0x04])
        if let pace = entry.targetPace500mSeconds {
            appendUInt32(UInt32(pace * 100), to: &block)
        } else {
            appendUInt32(0, to: &block)
        }
        
        // CSAFE_PM_CONFIGURE_WORKOUT (0x14)
        block.append(contentsOf: [0x14, 0x01, 0x01])
        
        return block
    }
    
    /// Variable Interval ワークアウトの完全なCSAFEコマンドを生成
    /// 仕様書P93: WorkoutType=0x08, 各インターバルを繰り返し定義
    func generateVariableIntervalCommand(intervals: [VariableIntervalEntry]) -> Data {
        var payload = Data()
        
        // 1. CSAFE_PM_SET_WORKOUTTYPE: 0x08 = WORKOUTTYPE_VARIABLE_INTERVAL
        payload.append(contentsOf: [0x01, 0x01, 0x08])
        
        // 2. 各インターバルブロックを追加
        for (i, entry) in intervals.enumerated() {
            payload.append(buildVariableIntervalBlock(index: i, entry: entry))
        }
        
        // 3. CSAFE_PM_CONFIGURE_WORKOUT（全体確定）
        payload.append(contentsOf: [0x14, 0x01, 0x01])
        
        // 4. CSAFE_PM_SET_SCREENSTATE
        payload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
        
        // Wrap in 0x76
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        
        let hexStr = fullCommand.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("PM5ManagerVM: [VAR_INTERVAL] CSAFE payload = \(hexStr)")
        
        return fullCommand
    }
    
    /// Variable Interval ワークアウトを全PM5に開始
    func resetAndStartVariableIntervalWorkout(intervals: [VariableIntervalEntry]) {
        print("PM5ManagerVM: Starting Variable Interval workout (\(intervals.count) intervals)")
        
        isSending = true
        showDashboard = true
        workoutDistance = nil
        workoutTime = nil
        workoutRestTime = nil
        workoutSplitDistance = nil
        workoutSplitTime = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for device in connectedDevices {
                    group.addTask {
                        await self.runV4WorkflowVariable(for: device, intervals: intervals)
                    }
                }
            }
            DispatchQueue.main.async {
                self.isSending = false
                self.isSaved = false
            }
        }
    }
    
    /// Variable Interval 専用 v4 ワークフロー
    private func runV4WorkflowVariable(for peripheral: CBPeripheral, intervals: [VariableIntervalEntry]) async {
        let deviceID = peripheral.identifier
        guard let char = controlCharacteristics[deviceID],
              let _ = deviceMetrics[deviceID] else { return }
        
        // PHASE 1: TERMINATE
        guard let terminateFrame = buildTerminateExtendedFrame() else {
            handleV4Failure(deviceID: deviceID, phase: "TERMINATE_GEN"); return
        }
        let terminateCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: terminateFrame, label: "TERMINATE")
        updatePerDeviceStatus(deviceID, to: .resetting)
        let successTerminate = await executeWithRetry(command: terminateCmd, phase: "TERMINATE")
        if !successTerminate { handleV4Failure(deviceID: deviceID, phase: "TERMINATE"); return }
        
        // PHASE 2: POLL
        updatePerDeviceStatus(deviceID, to: .polling)
        let pollFrame = buildGetStatusExtendedFrame()
        let pollCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: pollFrame, label: "POLL_STATUS")
        
        let timeoutLimit: TimeInterval = 9.0
        var deadline = Date().addingTimeInterval(timeoutLimit)
        var isReady = false
        
        while Date() < deadline {
            do {
                try await commandQueue.writeAsync(command: pollCmd)
                try await Task.sleep(nanoseconds: 20_000_000)
                if let m = deviceMetrics[deviceID], m.machineState == .ready {
                    isReady = true; break
                }
            } catch {}
            try? await Task.sleep(nanoseconds: 250_000_000)
            deadline = max(deadline, Date().addingTimeInterval(1.0))
        }
        if !isReady { handleV4Failure(deviceID: deviceID, phase: "POLLING"); return }
        
        // PHASE 3: CONFIG (F1 frame)
        updatePerDeviceStatus(deviceID, to: .configuring)
        let configPayload = generateVariableIntervalCommand(intervals: intervals)
        guard let configFrame = buildCSAFEFrame(payload: configPayload, startFlag: 0xF1) else {
            handleV4Failure(deviceID: deviceID, phase: "CONFIG_GEN"); return
        }
        let configCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: configFrame, label: "CONFIG_VAR_INTERVAL")
        let successConfig = await executeWithRetry(command: configCmd, phase: "CONFIG")
        if successConfig {
            updatePerDeviceStatus(deviceID, to: .ready)
            logV4(deviceID: deviceID, phase: "WORKFLOW", retry: 0, state: "Success", message: "Variable Interval ready.")
        } else {
            handleV4Failure(deviceID: deviceID, phase: "CONFIG")
        }
    }

    
    /// 距離ワークアウトを全PM5に送信（Phase 2: CONFIG）
    private func setWorkoutDistance(meters: Int, split: Int? = nil) {
        let limitedMeters = min(max(meters, 100), 60000)
        let limitedSplit = split != nil ? min(max(split!, 100), limitedMeters) : limitedMeters
        
        // 楽観的UI更新: 送信開始時にダッシュボードを即座に表示
        isSending = true
        workoutDistance = limitedMeters
        workoutSplitDistance = limitedSplit
        workoutTime = nil
        workoutSplitTime = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        guard let workoutFrame = buildCSAFEFrame(payload: generateWorkoutCommand(distanceMeters: limitedMeters, splitMeters: limitedSplit)) else {
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
                print("PM5ManagerVM: ✅ 距離ワークアウト \(limitedMeters)m (Split: \(limitedSplit)m) を全PM5に送信完了")
            }
        }
    }
    
    /// 時間ワークアウトを全PM5に送信（Phase 2: CONFIG）
    private func setWorkoutTime(seconds: Int, split: Int? = nil) {
        let limitedSeconds = min(max(seconds, 20), 36000)
        let limitedSplit = split != nil ? min(max(split!, 10), limitedSeconds) : (limitedSeconds / 2)
        
        // 楽観的UI更新: 送信開始時にダッシュボードを即座に表示
        isSending = true
        workoutTime = limitedSeconds
        workoutSplitTime = limitedSplit
        workoutDistance = nil
        workoutSplitDistance = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        guard let workoutFrame = buildCSAFEFrame(payload: generateWorkoutCommand(timeSeconds: limitedSeconds, splitSeconds: limitedSplit)) else {
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
                print("PM5ManagerVM: ✅ 時間ワークアウト \(limitedSeconds)s (Split: \(limitedSplit)s) を全PM5に送信完了")
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
    
    /// 全デバイスに終了・リセットシーケンスを開始（一括）
    func resetAllDevices() {
        print("PM5ManagerVM: Resetting all devices (Unconditional STOP)")
        lastHaltTime = Date()
        
        guard let terminateFrame = buildTerminateExtendedFrame() else {
            print("PM5ManagerVM: ⛔ Failed to build TERMINATE frame")
            return
        }
        
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
                    metrics.configStatus = .resetting
                }
            }
        }
        
        // Terminate を全デバイスに並行送信
        enqueueToAllDevices(
            frame: terminateFrame,
            label: "TERMINATE_RESET",
            perDeviceStatus: .resetting
        )
    }
    
    /// TERMINATE コマンドの Extended Frame を構築
    /// Concept2仕様: F1 76 04 13 02 01 02 [CS] F2 → Extended: F0 [Dest][Src] 76 04 13 02 01 02 [CS] F2
    private func buildTerminateExtendedFrame() -> Data? {
        // CSAFE_PM_SET_SCREENSTATE: ScreenType=WORKOUT(01), ScreenValue=TERMINATE(02)
        let payload = Data([0x76, 0x04, 0x13, 0x02, 0x01, 0x02])
        return buildCSAFEFrame(payload: payload)
    }
    
    /// GETSTATUS コマンドの Extended Frame を構築
    /// Standard: F1 80 80 F2 → Extended: F0 [Dest][Src] 80 80 F2
    /// Short command (0x80) の checksum = 0x80
    private func buildGetStatusExtendedFrame() -> Data {
        // CSAFE_GETSTATUS_CMD (0x80) は short command
        let payload = Data([0x80])
        // buildCSAFEFrame を使用して extended frame を構築
        // Checksum = 0x80, byte stuffing 適用
        if let frame = buildCSAFEFrame(payload: payload) {
            return frame
        }
        // Fallback: 手動構築 (buildCSAFEFrame が nil を返すことは通常ない)
        let checksum: UInt8 = 0x80
        var stuffingTarget = Data([0xFD, 0x00, 0x80, checksum])
        let stuffed = byteStuff(stuffingTarget)
        var frame = Data([0xF0])
        frame.append(stuffed)
        frame.append(0xF2)
        return frame
    }
    
    /// v4 ワークフローを使用してワークアウトを開始
    func resetAndStartWorkout(distance: Int? = nil, time: Int? = nil, split: Int? = nil) {
        print("PM5ManagerVM: Resetting and starting v4 workflow (Immediate transition to dashboard)")
        
        // 1. 即座にダッシュボードへ遷移 (Optimistic UI)
        isSending = true
        showDashboard = true
        workoutDistance = distance
        workoutSplitDistance = distance != nil ? split : nil
        workoutTime = time
        workoutSplitTime = time != nil ? split : nil
        workoutRestTime = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        // 2. 各デバイスに対して独立した v4 ワークフローを並列実行
        Task {
            await withTaskGroup(of: Void.self) { group in
                for device in connectedDevices {
                    group.addTask {
                        await self.runV4Workflow(for: device, workout: (distance: distance, time: time, split: split, rest: nil))
                    }
                }
            }
            
            // 全体の完了
            DispatchQueue.main.async {
                self.isSending = false
                self.isSaved = false
                print("PM5ManagerVM: v4 Workflow loop completed for all devices.")
            }
        }
    }
    
    /// 不変インターバルワークアウトを開始
    func resetAndStartIntervalWorkout(distance: Int? = nil, time: Int? = nil, rest: Int) {
        print("PM5ManagerVM: Resetting and starting Interval workflow")
        
        isSending = true
        showDashboard = true
        workoutDistance = distance
        workoutTime = time
        workoutRestTime = rest
        workoutSplitDistance = nil
        workoutSplitTime = nil
        workoutStartTime = Date()
        initializeAllMetrics()
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for device in connectedDevices {
                    group.addTask {
                        await self.runV4Workflow(for: device, workout: (distance: distance, time: time, split: nil, rest: rest))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isSending = false
                self.isSaved = false
            }
        }
    }
    
    // MARK: - v4 Architecture Core Logic
    
    private func logV4(deviceID: UUID, phase: String, retry: Int, state: String, message: String) {
        let shortID = deviceID.uuidString.prefix(4)
        print("[Device:\(shortID)][Phase:\(phase)][Retry:\(retry)][State:\(state)] \(message)")
    }
    
    /// 特定のデバイスに対して v4 ワークフロー (TERMINATE -> POLL -> CONFIG) を実行
    private func runV4Workflow(for peripheral: CBPeripheral, workout: (distance: Int?, time: Int?, split: Int?, rest: Int?)) async {
        let deviceID = peripheral.identifier
        guard let char = controlCharacteristics[deviceID],
              let metrics = deviceMetrics[deviceID] else { return }
        
        // PHASE 1: TERMINATE (Extended Frame)
        guard let terminateFrame = buildTerminateExtendedFrame() else {
            handleV4Failure(deviceID: deviceID, phase: "TERMINATE_GEN")
            return
        }
        let terminateCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: terminateFrame, label: "TERMINATE")
        
        updatePerDeviceStatus(deviceID, to: .resetting)
        logV4(deviceID: deviceID, phase: "TERMINATE", retry: 0, state: "Start", message: "Sending mandatory reset (extended frame)...")
        
        let successTerminate = await executeWithRetry(command: terminateCmd, phase: "TERMINATE")
        if !successTerminate {
            handleV4Failure(deviceID: deviceID, phase: "TERMINATE")
            return
        }
        
        // BLE ACK ≠ PM5内部状態遷移完了。ACK は「packet accepted」を意味するのみ。
        // そのため POLLING で実際の Machine Status を確認する。
        
        // PHASE 2: POLLING (Machine Status による状態同期, Extended Frame)
        updatePerDeviceStatus(deviceID, to: .polling)
        let pollFrame = buildGetStatusExtendedFrame()
        let pollCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: pollFrame, label: "POLL_STATUS")
        
        logV4(deviceID: deviceID, phase: "POLLING", retry: 0, state: "Start", message: "Polling Machine Status (v4 State-Aware)...")
        
        let timeoutLimit: TimeInterval = 9.0
        var deadline = Date().addingTimeInterval(timeoutLimit)
        var lastObservedState = metrics.machineState
        var isReady = false
        var communicationActive = true
        
        while Date() < deadline {
            do {
                try await commandQueue.writeAsync(command: pollCmd)
                communicationActive = true
                
                // 応答パース待ち (Delegateからの更新を待つ)
                try await Task.sleep(nanoseconds: 20_000_000)
                
                let currentState = metrics.machineState
                let isBusy = metrics.isMachineBusy
                
                if currentState == .ready {
                    isReady = true
                    break
                }
                
                // 1. 状態変化を検知した場合、カウントダウンをリセット
                if currentState != lastObservedState {
                    logV4(deviceID: deviceID, phase: "POLLING", retry: 0, state: "Progress", message: "State changed \(lastObservedState.description) -> \(currentState.description). Extending deadline.")
                    deadline = Date().addingTimeInterval(timeoutLimit)
                    lastObservedState = currentState
                } 
                // 2. 状態変化がなくても、PM5が「忙しい」状態（Busyフラグ or InUse/Finish/Pause）なら期限を延長
                else if isBusy || currentState == .inUse || currentState == .finish || currentState == .pause {
                    // PM5内部で処理が進行中とみなし、タイムアウトを2秒先送り
                    let extensionDate = Date().addingTimeInterval(2.0)
                    if extensionDate > deadline {
                        deadline = extensionDate
                    }
                }
            } catch {
                // BLEレベルの無応答
                communicationActive = false
                logV4(deviceID: deviceID, phase: "POLLING", retry: 0, state: "NoResponse", message: "BLE write failed. Dead limit: \(Int(deadline.timeIntervalSinceNow))s")
            }
            
            // 4Hz polling interval
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        
        if !isReady {
            let reason = communicationActive ? "State stagnation at \(metrics.machineState.description)" : "Communication failure"
            logV4(deviceID: deviceID, phase: "POLLING", retry: 0, state: "Timeout", message: "Failed to reach Ready state. \(reason)")
            handleV4Failure(deviceID: deviceID, phase: "POLLING")
            return
        }
        
        logV4(deviceID: deviceID, phase: "POLLING", retry: 0, state: "Ready", message: "Synchronized. Proceeding to CONFIG.")
        
        // PHASE 3: CONFIG
        updatePerDeviceStatus(deviceID, to: .configuring)
        let configPayload: Data
        
        if let rest = workout.rest {
            // Interval Workout
            configPayload = generateIntervalWorkoutCommand(distanceMeters: workout.distance, timeSeconds: workout.time, restSeconds: rest)
        } else if let dist = workout.distance {
            configPayload = generateWorkoutCommand(distanceMeters: dist, splitMeters: workout.split)
        } else if let time = workout.time {
            configPayload = generateWorkoutCommand(timeSeconds: time, splitSeconds: workout.split)
        } else {
            return
        }
        
        
        let startFlag: UInt8 = workout.rest != nil ? 0xF1 : 0xF0
        guard let configFrame = buildCSAFEFrame(payload: configPayload, startFlag: startFlag) else {
            handleV4Failure(deviceID: deviceID, phase: "CONFIG_GEN")
            return
        }
        
        let configCmd = CSAFECommandQueue.Command(peripheral: peripheral, characteristic: char, frame: configFrame, label: "CONFIG")
        
        let successConfig = await executeWithRetry(command: configCmd, phase: "CONFIG")
        if successConfig {
            updatePerDeviceStatus(deviceID, to: .ready)
            logV4(deviceID: deviceID, phase: "WORKFLOW", retry: 0, state: "Success", message: "Ready to row.")
        } else {
            handleV4Failure(deviceID: deviceID, phase: "CONFIG")
        }
    }
    
    /// 指数バックオフ付きリトライ実行
    private func executeWithRetry(command: CSAFECommandQueue.Command, phase: String) async -> Bool {
        let deviceID = command.peripheral.identifier
        let maxRetries = 2
        
        for attempt in 0...maxRetries {
            if attempt > 0 {
                // 指数バックオフ: 100ms, 200ms
                let backoffMs = pow(2.0, Double(attempt - 1)) * 100
                logV4(deviceID: deviceID, phase: phase, retry: attempt, state: "Backoff", message: "Waiting \(Int(backoffMs))ms...")
                try? await Task.sleep(nanoseconds: UInt64(backoffMs * 1_000_000))
            }
            
            do {
                try await commandQueue.writeAsync(command: command)
                return true
            } catch {
                logV4(deviceID: deviceID, phase: phase, retry: attempt, state: "Error", message: "Write failed: \(error.localizedDescription)")
            }
        }
        return false
    }
    
    private func updatePerDeviceStatus(_ deviceID: UUID, to status: PM5DeviceMetrics.ConfigStatus) {
        DispatchQueue.main.async {
            self.deviceMetrics[deviceID]?.configStatus = status
        }
    }
    
    private func handleV4Failure(deviceID: UUID, phase: String) {
        logV4(deviceID: deviceID, phase: phase, retry: 0, state: "Failed", message: "Marking as Degraded.")
        DispatchQueue.main.async {
            self.deviceMetrics[deviceID]?.configStatus = .degraded("Failed at \(phase)")
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
        } else if characteristic.uuid == C2_CHAR_DATA_POINT {
            parseManagerDataPoint(data, for: deviceID)
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
    
    /// Data Point (0x22): CSAFE 応答をパースして Machine Status を更新
    /// v4: Extended frame response にも対応
    /// Response format:
    ///   Standard: F1 [Status] [CmdResponse...] [Checksum] F2
    ///   Extended: F0 [Src] [Dest] [Status] [CmdResponse...] [Checksum] F2
    ///   Raw contents: [Status] [CmdResponse...] (framing stripped by BLE stack)
    private func parseManagerDataPoint(_ data: Data, for deviceID: UUID) {
        guard !data.isEmpty else { return }
        
        let bytes = [UInt8](data)
        let statusByte: UInt8
        
        if bytes[0] == 0xF0 && bytes.count >= 4 {
            // Extended frame response: F0 [Src] [Dest] [Status] ...
            statusByte = bytes[3]
        } else if bytes[0] == 0xF1 && bytes.count >= 2 {
            // Standard frame response: F1 [Status] ...
            statusByte = bytes[1]
        } else {
            // Raw frame contents (BLE stack がフレーミングを除去済み)
            statusByte = bytes[0]
        }
        
        let stateValue = statusByte & 0x0F
        let busyFlag = (statusByte & 0x20) != 0
        
        if let state = PM5DeviceMetrics.PM5MachineState(rawValue: stateValue) {
            DispatchQueue.main.async { [weak self] in
                if let metrics = self?.deviceMetrics[deviceID] {
                    metrics.machineState = state
                    metrics.isMachineBusy = busyFlag
                }
            }
        }
    }
}

