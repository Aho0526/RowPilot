import Foundation
import CoreBluetooth
import CoreNFC
import Combine

class RowErgManager: NSObject, ObservableObject {
    // Concept2 UUIDs
    private let C2_SERVICE_UUID = CBUUID(string: "CE060030-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_GENERAL_STATUS = CBUUID(string: "CE060031-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_ROWING_STATUS_0x32 = CBUUID(string: "CE060032-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_STROKE_DATA = CBUUID(string: "CE060035-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_POWER_DATA_0x33 = CBUUID(string: "CE060033-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_ADDITIONAL_STROKE_DATA_0x36 = CBUUID(string: "CE060036-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_FORCE_CURVE = CBUUID(string: "CE06003D-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_CONTROL_POINT = CBUUID(string: "CE060021-43E5-11E4-916C-0800200C9A66")
    private let C2_CHAR_DATA_POINT = CBUUID(string: "CE060022-43E5-11E4-916C-0800200C9A66")
    private let C2_DEVICE_CONTROL_SERVICE = CBUUID(string: "CE060020-43E5-11E4-916C-0800200C9A66")
    
    // CoreBluetooth
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var controlCharacteristic: CBCharacteristic?
    private var targetPeripheralName: String?
    private var isWaitingForCsafeResponse: Bool = false
    private var csafeCompletion: (() -> Void)?
    private var csafeSequenceNumber: UInt8 = 0
    
    // Characteristic readiness flags
    private var isControlPointReady: Bool = false
    private var isDataPointReady: Bool = false
    
    // Initialization state tracking
    private var hasReceivedInitialGeneralStatus: Bool = false
    private var hasReceivedInitialStrokeData: Bool = false
    private var communicationStartTime: Date?
    private var activeMetricsStartTime: Date?
    
    // CoreNFC
    private var nfcSession: NFCNDEFReaderSession?
    
    // Published Connect State
    @Published var isBluetoothPoweredOn: Bool = false
    @Published var isScanning: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredDevices: [CBPeripheral] = []
    
    // Published Metric Data
    @Published var strokeRate: Int = 0
    @Published var pace500m: Double = 0.0
    @Published var distance: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    @Published var power: Int = 0
    
    // Target Values (Workout Setup)
    @Published var targetDistance: Double? = nil
    @Published var targetTime: Double? = nil
    @Published var showingWorkoutExecution: Bool = false
    
    /// ワークアウトが終了したかどうかを判定
    var isWorkoutFinished: Bool {
        if let targetDist = targetDistance {
            return distance >= targetDist
        } else if let targetT = targetTime {
            return elapsedTime >= targetT
        }
        return false
    }
    
    // Debug Data
    @Published var lastRawBytes: String = ""
    @Published var lastGeneralStatusBytes: String = ""
    @Published var lastStrokeDataBytes: String = ""
    @Published var lastStrokeData0x33Bytes: String = ""
    @Published var lastStrokeData0x36Bytes: String = ""
    @Published var lastReceivedAt: Date = Date()
    
    // Specific Byte Monitor
    @Published var generalStatusBytes3to5: String = "-- -- --"
    @Published var strokeDataBytes10to11: String = "-- --"
    @Published var strokeDataBytes6to7: String = "-- --"
    
    // Calculation State
    private var lastStrokeCount: Int = -1
    private var lastStrokeTime: Double = 0
    private var lastStrokeDistance: Double = 0
    
    // Force Curve State
    @Published var completedForceCurve: [ForcePoint] = []
    private var forceCurveBuffer: [UInt8] = []
    private var endOfStrokeWorkItem: DispatchWorkItem?
    
    // BLE Research Sandbox
    struct ResearchLogEntry: Identifiable {
        enum EntryType {
            case tx
            case rx
            case stateChange
        }
        
        let id = UUID()
        let timestamp: Date
        let type: EntryType
        let content: String // Hex payload or State description
        let machineState: String? // Optional state context at that moment
    }
    
    @Published var researchLogs: [ResearchLogEntry] = []
    @Published var isResearchWriteBusy: Bool = false
    @Published var researchCooldownRemaining: Int = 0
    private var cooldownTimer: Timer?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - NFC Methods
    func startNFCScan() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("RowErgManager: NFC not available")
            return
        }
        print("RowErgManager: Start NFC Scan")
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        nfcSession?.alertMessage = "PM5モニターの上部にあるNFCタグにiPhoneを近づけてください。"
        nfcSession?.begin()
    }

    // MARK: - BLE Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        if !isScanning {
            print("RowErgManager: Start Scanning (All Services)")
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            isScanning = true
        }
    }
    
    func stopScanning() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
    }
    
    func connect(_ peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - Workout Control
    
    enum WorkoutType: UInt8 {
        case justRow = 0x00
        case singleDistance = 0x01
        case singleTime = 0x02
    }
    
    enum PM5MachineState: UInt8 {
        case error = 0
        case ready = 1
        case idle = 2
        case service = 3
        case rowing = 4 // Matches PM5 "In Use"
        case pause = 5
        case finished = 6
        case manual = 7
        case unknown = 0xFF
        
        var description: String {
            switch self {
            case .error: return "Error"
            case .ready: return "Ready"
            case .idle: return "Idle"
            case .service: return "Service"
            case .rowing: return "Rowing"
            case .pause: return "Pause"
            case .finished: return "Finished"
            case .manual: return "Manual"
            case .unknown: return "Unknown"
            }
        }
    }
    
    @Published var currentMachineState: PM5MachineState = .unknown
    
    // MARK: - BLE Research Sandbox Actions
    
    func clearResearchLogs() {
        researchLogs.removeAll()
    }
    
    func sendResearchWrite(data: Data) {
        guard let peripheral = connectedPeripheral, 
              let char = controlCharacteristic,
              !isResearchWriteBusy else {
            print("RowErgManager: Research Write skipped (Not connected or Busy)")
            return
        }
        
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("RowErgManager: [RESEARCH] Sending to 0021: \(hex)")
        
        let stateCurrent = currentMachineState.description
        isResearchWriteBusy = true
        researchCooldownRemaining = 3
        
        // Log TX
        let logEntry = ResearchLogEntry(
            timestamp: Date(),
            type: .tx,
            content: hex,
            machineState: stateCurrent
        )
        researchLogs.insert(logEntry, at: 0)
        
        // Perform Write (Explicitly .withoutResponse for CSAFE Control Point)
        peripheral.writeValue(data, for: char, type: .withoutResponse)
        
        // Start Cooldown Timer
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                if self.researchCooldownRemaining > 0 {
                    self.researchCooldownRemaining -= 1
                } else {
                    self.isResearchWriteBusy = false
                    timer.invalidate()
                }
            }
        }
    }
    
    // Internal Helper for Logging
    private func logResearchRX(hex: String) {
        let entry = ResearchLogEntry(
            timestamp: Date(),
            type: .rx,
            content: hex,
            machineState: currentMachineState.description
        )
        DispatchQueue.main.async {
            self.researchLogs.insert(entry, at: 0)
        }
    }
    
    private func logResearchState(old: PM5MachineState, new: PM5MachineState) {
        let content = "\(old.description) -> \(new.description)"
        let entry = ResearchLogEntry(
            timestamp: Date(),
            type: .stateChange,
            content: content,
            machineState: new.description
        )
        DispatchQueue.main.async {
            self.researchLogs.insert(entry, at: 0)
        }
    }
    
    // MARK: - CSAFE Chunked Transmission (Correct BLE Protocol)
    
    /// CSAFEフレームを構築し、20バイトごとに分割して送信する
    /// Structure: F1 | 00 (Status) | Payload | Checksum | F2
    /// Note: Checksum includes the 00 Status Byte.
    /// CSAFEフレームを構築し、20バイトごとに分割して送信する
    /// Structure: F1 | 00 (Status) | Payload | Checksum | F2
    /// Note: Checksum includes the 00 Status Byte.
    /// CSAFEフレームを構築し、分割せずに一括で送信する（バイトスタッフィング付き）
    /// Structure: F1 | Stuffed(Payload + Checksum) | F2
    func sendCSAFESingle(payload: Data, completion: (() -> Void)? = nil) {
        let checksum = calculateCSAFEChecksum(for: payload)
        
        var checksummedPayload = Data()
        checksummedPayload.append(payload)
        checksummedPayload.append(checksum)
        
        // ペイロード内の特殊バイト (0xF0-0xF3) をエスケープ
        let stuffed = byteStuff(checksummedPayload)
        
        var frame = Data()
        frame.append(0xF1) // Start Flag
        frame.append(stuffed)
        frame.append(0xF2) // Stop Flag
        
        let hexFull = frame.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("RowErgManager: [CSAFE] Single Frame: \(hexFull)")
        
        // Check for byte stuffing activity
        let payloadBytes = [UInt8](payload)
        let specialBytes = payloadBytes.enumerated().filter { [0xF0, 0xF1, 0xF2, 0xF3].contains($0.element) }
        if !specialBytes.isEmpty {
            print("RowErgManager: [CSAFE] ⚠️ Byte stuffing applied for special bytes:")
            for (idx, byte) in specialBytes {
                print("  Offset \(idx): 0x\(String(format: "%02X", byte))")
            }
        }
        
        // Log the TX attempt
        let logEntry = ResearchLogEntry(
            timestamp: Date(),
            type: .tx,
            content: "[SINGLE] \(hexFull)",
            machineState: currentMachineState.description
        )
        DispatchQueue.main.async {
            self.researchLogs.insert(logEntry, at: 0)
        }
        
        guard let peripheral = connectedPeripheral,
              let char = controlCharacteristic else {
            print("RowErgManager: [CSAFE] Abort - BLE not ready")
            return
        }
        
        isResearchWriteBusy = true
        peripheral.writeValue(frame, for: char, type: .withoutResponse)
        
        // Cooldown managed for UI/Interaction safety
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isResearchWriteBusy = false
            completion?()
        }
    }
    
    /// CSAFEフレームを構築し、20バイトごとに分割して送信する
    
    /// Sends a sequence of logical CSAFE payloads one by one
    func sendCSAFEChunkedSequence(payloads: [Data]) {
        guard !payloads.isEmpty else { return }
        var remaining = payloads
        let current = remaining.removeFirst()
        
        print("RowErgManager: [SEQUENCE] Sending frame, \(remaining.count) remaining...")
        sendCSAFEChunked(payload: current) { [weak self] in
            // Add a small safety delay between Frames (PM5 processing time)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.sendCSAFEChunkedSequence(payloads: remaining)
            }
        }
    }
    
    /// Chunk and send a CSAFE payload in 20-byte BLE-compliant frames
    func sendCSAFEChunked(payload: Data, completion: (() -> Void)? = nil) {
        // Split the payload into 20-byte chunks (BLE MTU)
        var chunks: [Data] = []
        let mtu = 20
        var idx = 0
        while idx < payload.count {
            let end = min(idx + mtu, payload.count)
            chunks.append(payload.subdata(in: idx..<end))
            idx += mtu
        }
        // Use the recursive sender
        sendChunksRecursively(chunks: chunks, index: 0, completion: completion)
    }
    
    private func sendChunksRecursively(chunks: [Data], index: Int, completion: (() -> Void)? = nil) {
        guard index < chunks.count else {
            print("RowErgManager: [CSAFE] All chunks sent.")
            isResearchWriteBusy = false
            completion?()
            return
        }
        
        guard let peripheral = connectedPeripheral,
              let char = controlCharacteristic else {
            print("RowErgManager: [CSAFE] Abort - BLE not ready")
            isResearchWriteBusy = false
            return
        }
        
        let chunk = chunks[index]
        let hexChunk = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("RowErgManager: [CSAFE] Sending Chunk \(index + 1)/\(chunks.count): \(hexChunk)")
        
        // Busy flag managed by caller usually, but we ensure it here
        isResearchWriteBusy = true
        
        peripheral.writeValue(chunk, for: char, type: .withoutResponse)
        
        // Small delay between chunks to ensure order and processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.sendChunksRecursively(chunks: chunks, index: index + 1, completion: completion)
        }
    }
    
    /// CSAFEチェックサムを計算 (OpcodeからDataまでのXOR)
    func calculateCSAFEChecksum(for data: Data) -> UInt8 {
        var checksum: UInt8 = 0
        for byte in data {
            checksum ^= byte
        }
        return checksum
    }
    
    enum CSAFEFrameMode {
        case short    // F1 [Cmd] [CS] F2
        case standard // F1 [Cmd] [Len] [Data] [CS] F2
        case extended // F1 F0 [Cmd] [Len] [Data] [CS] F2
    }
    
    /// CSAFEフレームを構築
    func buildFrame(mode: CSAFEFrameMode, opcode: UInt8, payload: Data = Data(), checksumOverride: UInt8? = nil) -> Data {
        var content = Data()
        
        switch mode {
        case .short:
            content.append(opcode)
        case .standard, .extended:
            content.append(opcode)
            content.append(UInt8(payload.count))
            content.append(payload)
        }
        
        let checksum = checksumOverride ?? calculateCSAFEChecksum(for: content)
        
        var frame = Data()
        frame.append(0xF1) // Start
        
        if mode == .extended {
            frame.append(0xF0) // Extended Frame Indicator
        }
        
        frame.append(content)
        frame.append(checksum)
        frame.append(0xF2) // End
        return frame
    }

    /// CSAFEコマンドパケットを構築する ([Cmd] [Len] [Data...])
    private func buildCSAFECommand(commandID: UInt8, data: Data = Data()) -> Data {
        var cmdData = Data()
        cmdData.append(commandID)
        cmdData.append(UInt8(data.count))   // Length (必須)
        if !data.isEmpty {
            cmdData.append(data)
        }
        return cmdData
    }
    

    /// CSAFE Byte Stuffing: Escape special control characters
    private func byteStuff(_ data: Data) -> Data {
        var stuffed = Data()
        for byte in data {
            switch byte {
            case 0xF0:
                stuffed.append(contentsOf: [0xF3, 0x00])
            case 0xF1:
                stuffed.append(contentsOf: [0xF3, 0x01])
            case 0xF2:
                stuffed.append(contentsOf: [0xF3, 0x02])
            case 0xF3:
                stuffed.append(contentsOf: [0xF3, 0x03])
            default:
                stuffed.append(byte)
            }
        }
        return stuffed
    }

    private func sendCSAFEFrame(_ commandContent: Data,
                                description: String,
                                completion: @escaping () -> Void) {

        guard let char = controlCharacteristic,
              let peripheral = connectedPeripheral else {
            print("RowErgManager: BLE Not Ready for \(description)")
            return
        }

        // EXTENDED CSAFE Frame Structure:
        // [F0] [Dest 0x01] [Src 0x00] [Cmd] [Len] [Data] [Checksum] [F2]
        
        // 1. Construct Payload (Dest + Src + CommandContent)
        var payload = Data()
        payload.append(0x01) // Destination: PM5
        payload.append(0x00) // Source: Host
        payload.append(commandContent)
        
        // 2. Calculate Checksum on Unstuffed Payload (XOR)
        var checksum: UInt8 = 0
        for byte in payload {
            checksum ^= byte
        }
        payload.append(checksum)
        
        // 3. Apply Byte Stuffing to Payload + Checksum
        let stuffedPayload = byteStuff(payload)
        
        // 4. Wrap in Flags
        var frame = Data()
        frame.append(0xF0) // Extended Start Flag
        frame.append(stuffedPayload)
        frame.append(0xF2) // Stop Flag

        print("RowErgManager: \(description) [State: \(currentMachineState.description)]")
        print("RowErgManager: SENDING EXTENDED Frame: \(frame.map { String(format: "%02X", $0) }.joined(separator: " "))")

        isWaitingForCsafeResponse = true
        csafeCompletion = completion

        // Internal tracking only
        csafeSequenceNumber = csafeSequenceNumber &+ 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self,
                  self.isWaitingForCsafeResponse,
                  self.csafeCompletion != nil else { return }
            print("RowErgManager: WARNING - CSAFE Timeout or No Notification Received")
        }

        peripheral.writeValue(frame, for: char, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("RowErgManager: Write Failed to \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("RowErgManager: Write Success to \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("RowErgManager: Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        guard let rawValue = characteristic.value, !rawValue.isEmpty else {
            return
        }

        let hexString = rawValue.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        // UI用に生データのバックアップ
        DispatchQueue.main.async {
            self.lastRawBytes = "[\(characteristic.uuid.uuidString.prefix(4))] \(hexString)"
            self.lastReceivedAt = Date()
            
            // Log RX for Research
            if characteristic.uuid == self.C2_CHAR_CONTROL_POINT || characteristic.uuid == self.C2_CHAR_DATA_POINT {
                self.logResearchRX(hex: hexString)
            }
        }

        if characteristic.uuid == C2_CHAR_DATA_POINT {
            print("RowErgManager: [DATA_POINT] RECEIVED: \(hexString)")
            isWaitingForCsafeResponse = false
            
            // Minimal: treat whole packet as response content
            parseCSAFEStatus(data: rawValue)
            
            csafeCompletion?()
            csafeCompletion = nil
            return
        }
        
        if characteristic.uuid == C2_CHAR_GENERAL_STATUS {
            parseGeneralStatus(rawValue)
        } else if characteristic.uuid == C2_CHAR_ROWING_STATUS_0x32 {
            parseRowingStatus0x32(rawValue)
        } else if characteristic.uuid == C2_CHAR_STROKE_DATA {
            parseStrokeData(rawValue)
        } else if characteristic.uuid == C2_CHAR_ADDITIONAL_STROKE_DATA_0x36 {
            parseStrokeData0x36(rawValue)
        } else if characteristic.uuid == C2_CHAR_FORCE_CURVE {
            parseForceCurve(rawValue)
        }
    }
    
    private func parseCSAFEStatus(data: Data) {
        // The instruction implies stripping all CSAFE framing and sending bare minimum [80, 00]
        // This means the response might just be the status byte directly.
        // Assuming the first byte is the status byte.
        guard let statusByte = data.first else {
            print("RowErgManager: parseCSAFEStatus: No data received.")
            return
        }
        print("RowErgManager: parseCSAFEStatus Data Content: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        let stateValue = statusByte & 0x0F
        print("RowErgManager: Candidate StatusByte=\(String(format: "%02X", statusByte)) -> StateValue=\(stateValue)")
        
        if let state = PM5MachineState(rawValue: stateValue) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.currentMachineState != state {
                    let oldState = self.currentMachineState
                    print("RowErgManager: Machine State Updated: \(oldState.description) -> \(state.description)")
                    self.logResearchState(old: oldState, new: state)
                    self.currentMachineState = state
                }
            }
        } else {
            print("RowErgManager: INVALID machine state value \(stateValue) from status byte \(String(format: "%02X", statusByte))")
        }
    }
    
    // MARK: - Force Curve Parsing
    
    private func parseForceCurve(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("RowErgManager: [ForceCurve RAW Chunk] \(hex)")
        
        // ヘッダー情報(1バイト目)とシーケンス番号(2バイト目)を除外
        guard data.count > 2 else { return }
        let body = data.dropFirst(2)
        
        // BLEパケットの余白埋め(0x00)や異常値によるデータ間の0を排除し、有効なデータのみ抽出
        let bytes = [UInt8](body).filter { $0 > 0 }
        forceCurveBuffer.append(contentsOf: bytes)
        
        // 2. Detect Stroke Completion via Timeout (Debouncing)
        endOfStrokeWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.processCompletedStroke()
        }
        endOfStrokeWorkItem = workItem
        
        // If 100ms pass without another packet, assume burst/stroke is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    private func processCompletedStroke() {
        guard !forceCurveBuffer.isEmpty else { return }
        
        let finalBuffer = forceCurveBuffer
        print("RowErgManager: [ForceCurve Full Stroke] Bytes count: \(finalBuffer.count)")
        forceCurveBuffer.removeAll(keepingCapacity: true)
        
        let curvePoints = convertBufferToForcePoints(buffer: finalBuffer)
        
        DispatchQueue.main.async {
            self.completedForceCurve = curvePoints
        }
    }
    
    private func convertBufferToForcePoints(buffer: [UInt8]) -> [ForcePoint] {
        let timeIncrement = 0.015625
        guard !buffer.isEmpty else { return [] }
        
        let rawValues = buffer.map { Double($0) }
        
        // 1パス目: 3点移動平均によるスムージング処理
        var smoothedValues: [Double] = []
        smoothedValues.reserveCapacity(rawValues.count)
        for i in 0..<rawValues.count {
            let start = max(0, i - 1)
            let end = min(rawValues.count - 1, i + 1)
            var sum = 0.0
            for j in start...end {
                sum += rawValues[j]
            }
            smoothedValues.append(sum / Double(end - start + 1))
        }
        
        // 2パス目: さらに滑らかな正弦波のような曲線を出すための移動平均
        var doublySmoothed: [Double] = []
        doublySmoothed.reserveCapacity(smoothedValues.count)
        for i in 0..<smoothedValues.count {
            let start = max(0, i - 1)
            let end = min(smoothedValues.count - 1, i + 1)
            var sum = 0.0
            for j in start...end {
                sum += smoothedValues[j]
            }
            doublySmoothed.append(sum / Double(end - start + 1))
        }
        
        var points: [ForcePoint] = []
        
        // グラフが常に0から立ち上がるように始点を追加 (エリア描画を綺麗にするため)
        points.append(ForcePoint(timeRaw: 0, forceLbf: 0))
        
        for (index, force) in doublySmoothed.enumerated() {
            let timeInSeconds = Double(index + 1) * timeIncrement
            points.append(ForcePoint(timeRaw: timeInSeconds, forceLbf: Int(force)))
        }
        
        // グラフが最後に0へ綺麗に戻るように終点を追加
        let lastTime = Double(doublySmoothed.count + 1) * timeIncrement
        points.append(ForcePoint(timeRaw: lastTime, forceLbf: 0))
        
        return points
    }
    
    // MARK: - CSAFE Workout Commands
    
    /// 距離（m）または時間（秒）を指定してワークアウトコマンドを生成する
    private func generateWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil, splitMeters: Int? = nil, splitSeconds: Int? = nil) -> Data {
        var payload = Data()
        
        // Helper: Append a 32-bit Big-Endian value
        func appendUInt32(_ value: UInt32) {
            let val = value.bigEndian
            withUnsafeBytes(of: val) { payload.append(contentsOf: $0) }
        }

        // 1. CSAFE_PM_SET_WORKOUTTYPE (0x01)
        // User requested: Distance -> 0x03 (FIXEDDIST_SPLITS), Time -> 0x05 (FIXEDTIME_SPLITS)
        payload.append(contentsOf: [0x01, 0x01])
        payload.append(distanceMeters != nil ? 0x03 : 0x05)
        
        // 2. CSAFE_PM_SET_WORKOUTDURATION (0x03)
        // [Cmd, Len(5), Type, B0, B1, B2, B3]
        payload.append(contentsOf: [0x03, 0x05])
        if let dist = distanceMeters {
            payload.append(0x80) // Duration Type: Distance
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(0x00) // Duration Type: Time (Strict PM5 Positive Example)
            appendUInt32(UInt32(time * 100)) // centi-seconds
        }
        
        // 3. CSAFE_PM_SET_SPLITDURATION (0x05)
        // [Cmd, Len(5), Type, B0, B1, B2, B3]
        // PM5 ではスプリット設定が必須（または明示的な設定が必要）。
        payload.append(contentsOf: [0x05, 0x05])
        if let dm = distanceMeters {
            payload.append(0x80) // Distance Split Type
            // 指示に基づき、未指定時はトータル距離を設定（Single Split）
            let sVal = splitMeters.map { min($0, dm) } ?? dm
            appendUInt32(UInt32(sVal))
        } else if let tm = timeSeconds {
            payload.append(0x00) // Time Split Type (Strict PM5 Positive Example)
            // 指示に基づき、未指定時はトータル時間の半分を設定（2 Splits）
            // 0 よりも安定し、PM5 の構成エラー (64-1/161-1) を回避します。
            let sVal = splitSeconds.map { min($0, tm - 1) } ?? (tm / 2)
            appendUInt32(UInt32(max(sVal, 1) * 100)) // centi-seconds
        }
        
        // 4. CSAFE_PM_CONFIGURE_WORKOUT (0x14)
        payload.append(contentsOf: [0x14, 0x01, 0x01])
        
        // 5. CSAFE_PM_SET_SCREENSTATE (0x13)
        // ScreenState: 0x01 (Workout), WorkoutState: 0x01 (Prepare to Row)
        payload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
        
        // Wrap in Extended Command 0x76 (SETPMBYTE)
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        
        // For debugging: Hex string representation
        let hexString = fullCommand.map { String(format: "%02x", $0) }.joined()
        print("RowErgManager: Generated CSAFE Payload: \(hexString)")
        
        return fullCommand
    }

    func setWorkoutDistance(meters: Int, split: Int? = nil) {
        let limitedMeters = min(max(meters, 100), 60000)
        print("RowErgManager: Setting workout distance to \(limitedMeters)m (Split: \(split?.description ?? "None"))")
        
        DispatchQueue.main.async {
            self.targetDistance = Double(limitedMeters)
            self.targetTime = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = [] // 新しいワークアウト開始時に前回のデータを消去
        }
        
        // ワークアウト変更・開始前に強制終了コマンドを送信
        sendTerminateWorkout()
        
        let cmd = generateWorkoutCommand(distanceMeters: limitedMeters, splitMeters: split)
        // PM5の処理待ちのため遅延させて送信（Terminateからの状態遷移を待つ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd) {
                print("RowErgManager: Workout distance command sent.")
            }
        }
    }
    
    func setWorkoutTime(seconds: Int, split: Int? = nil) {
        let limitedSeconds = min(max(seconds, 20), 36000)
        print("RowErgManager: Setting workout time to \(limitedSeconds)s (Split: \(split?.description ?? "None"))")
        
        DispatchQueue.main.async {
            self.targetTime = Double(limitedSeconds)
            self.targetDistance = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = [] // 新しいワークアウト開始時に前回のデータを消去
        }
        
        // ワークアウト変更・開始前に強制終了コマンドを送信
        sendTerminateWorkout()
        
        let cmd = generateWorkoutCommand(timeSeconds: limitedSeconds, splitSeconds: split)
        // PM5の処理待ちのため遅延させて送信（Terminateからの状態遷移を待つ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd) {
                print("RowErgManager: Workout time command sent.")
            }
        }
    }
    
    func setWorkoutTime(minutes: Int, splitMinutes: Int? = nil) {
        setWorkoutTime(seconds: minutes * 60, split: splitMinutes.map { $0 * 60 })
    }
    
    /// ワークアウトを保存/破棄後に同じ設定で再開する
    func resetAndStartWorkout(distance: Double?, time: Double?) {
        print("RowErgManager: Resetting and queuing new workout with 1s delay")
        
        // リセット送信し、数値をゼロに戻す (targetDistance/Timeは一旦nilになる)
        resetWorkout()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if let dist = distance {
                self.setWorkoutDistance(meters: Int(dist))
            } else if let t = time {
                self.setWorkoutTime(seconds: Int(t))
            }
        }
    }
    
    /// ワークアウトをリセットし、PM5に強制終了コマンドを送信する
    func resetWorkout() {
        print("RowErgManager: Resetting workout and sending TERMINATE command")
        sendTerminateWorkout()
        
        DispatchQueue.main.async {
            self.targetDistance = nil
            self.targetTime = nil
            self.distance = 0
            self.elapsedTime = 0
            self.strokeRate = 0
            self.power = 0
            self.lastStrokeCount = -1
        }
    }
    
    /// PM5に強制終了コマンド (F1 76 04 13 02 01 02 60 F2) を送信
    private func sendTerminateWorkout() {
        // payload = 76 04 13 02 01 02
        // Wrapper opcode: 0x76
        // Payload for 0x76: [0x13, 0x02, 0x01, 0x02] (ScreenState: Workout, State: Terminate/End)
        var payload = Data()
        payload.append(0x13) // CSAFE_PM_SET_SCREENSTATE
        payload.append(0x02) // Length
        payload.append(0x01) // Screen State: Workout
        payload.append(0x02) // Workout State: Terminate/Reset
        
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        
        print("RowErgManager: Sending MANDATORY TERMINATE command")
        sendCSAFESingle(payload: fullCommand)
    }
    
    // MARK: - Device Control Service (Session Management)
    
    /// CP + DP が準備完了したらCSAFE送信開始
    private func checkAllCharacteristicsReady() {
        guard isControlPointReady && isDataPointReady else { return }
        // General Status または Stroke Data のいずれか一方だけでも受信できていればOKとする
        guard hasReceivedInitialGeneralStatus || hasReceivedInitialStrokeData else { return }
        
        if currentMachineState == .unknown {
            print("RowErgManager: ℹ️  Characteristics ready and Notification received. State is Unknown, but proceeding with inference mode.")
            if communicationStartTime == nil {
                communicationStartTime = Date()
            }
        }
        
        print("RowErgManager: ✅ All prerequisites met [CP+DP ready, Notification received, State=\(currentMachineState.description)]")
        print("RowErgManager: ⏱️  Adding 1.0s delay before finalizing initialization...")
        
        // PM5のCSAFEハンドラが完全に初期化されるまで待機
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("RowErgManager: 🚀 Starting CSAFE communication")
            self.executeSimpleCsafeTest()
        }
    }
    
    // MARK: - BLE Initialization Complete
    
    /// BLE接続が完全に確立されたことを確認
    /// BLEではWorkout制御を行わず、データ監視のみを行う
    func executeSimpleCsafeTest() {
        print(">>> BLE CONNECTION FULLY ESTABLISHED <<<")
        print("RowErgManager: BLE is ready for data monitoring (General Status, Stroke Data)")
        print("RowErgManager: Workout control is NOT supported over BLE - use USB/CSAFE for workout setup")
        print("RowErgManager: Current State: \(currentMachineState.description)")
        
        // BLEでは制御コマンドを送信せず、データ受信のみを行う
        // General Status と Stroke Data の Notify が自動的にデータを配信する
    }


}

// MARK: - NFCNDEFReaderSessionDelegate
extension RowErgManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError, nfcError.code != .readerSessionInvalidationErrorUserCanceled {
             print("RowErgManager: NFC Session Invalidated -> \(error.localizedDescription)")
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        var foundName: String?
        for message in messages {
            for record in message.records {
                if record.typeNameFormat == .nfcWellKnown,
                   let type = String(data: record.type, encoding: .utf8), type == "T" {
                    let payload = record.payload
                    if payload.count > 1 {
                        let statusByte = payload[0]
                        let languageCodeLength = Int(statusByte & 0x3F)
                        let textEncoding = (statusByte & 0x80) == 0 ? String.Encoding.utf8 : String.Encoding.utf16
                        if payload.count > 1 + languageCodeLength {
                            let textData = payload.dropFirst(1 + languageCodeLength)
                            if let text = String(data: textData, encoding: textEncoding) {
                                print("RowErgManager: NFC Parsed Text -> \(text)")
                                if text.contains("PM5") {
                                    foundName = text
                                    break
                                }
                            }
                        }
                    }
                } else if let string = String(data: record.payload, encoding: .utf8) ?? String(data: record.payload, encoding: .ascii) {
                    if string.contains("PM5") {
                         foundName = string
                         break
                    }
                }
            }
            if foundName != nil { break }
        }
        
        if let name = foundName {
            session.alertMessage = "PM5を検出: \(name)\n接続を開始します..."
            DispatchQueue.main.async {
                self.targetPeripheralName = name
                if !self.isScanning {
                    self.startScanning()
                } else {
                    if let existing = self.discoveredDevices.first(where: { ($0.name ?? "").contains(name) }) {
                        self.connect(existing)
                    }
                }
            }
        } else {
             session.alertMessage = "PM5情報を読み取れませんでした。"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension RowErgManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("RowErgManager: State Updated -> \(central.state.rawValue)")
        isBluetoothPoweredOn = (central.state == .poweredOn)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let isPM5 = name.contains("PM5")
        
        if isPM5 || targetPeripheralName != nil {
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("RowErgManager: Discovered -> \(name)")
                discoveredDevices.append(peripheral)
                
                if let target = targetPeripheralName, name.contains(target) {
                    print("RowErgManager: Target Matched via NFC! Connecting...")
                    connect(peripheral)
                    targetPeripheralName = nil
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("RowErgManager: Connected to \(peripheral.name ?? "Unknown")")
        connectionState = .connected
        
        // スキャンを明示的に停止
        stopScanning()
        
        // 初期化フラグをリセット
        isControlPointReady = false
        isDataPointReady = false
        hasReceivedInitialGeneralStatus = false
        hasReceivedInitialStrokeData = false
        communicationStartTime = nil
        activeMetricsStartTime = nil
        csafeSequenceNumber = 0
        
        peripheral.delegate = self
        // Device Control (0020) と RowErg (0030) の両方のサービスを探す
        peripheral.discoverServices([C2_SERVICE_UUID, C2_DEVICE_CONTROL_SERVICE])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("RowErgManager: Failed to connect -> \(error?.localizedDescription ?? "")")
        connectionState = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("RowErgManager: Disconnected from \(peripheral.name ?? "Unknown")")
        connectionState = .disconnected
        connectedPeripheral = nil
        controlCharacteristic = nil
        strokeRate = 0
        pace500m = 0.0
        power = 0
        lastStrokeCount = -1
        lastStrokeTime = 0
        lastStrokeDistance = 0
    }
}

// MARK: - CBPeripheralDelegate
extension RowErgManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == C2_SERVICE_UUID {
                peripheral.discoverCharacteristics([C2_CHAR_GENERAL_STATUS, C2_CHAR_ROWING_STATUS_0x32, C2_CHAR_STROKE_DATA, C2_CHAR_ADDITIONAL_STROKE_DATA_0x36, C2_CHAR_FORCE_CURVE], for: service)
            } else if service.uuid == C2_DEVICE_CONTROL_SERVICE {
                // Device Control Service から Control Point, Data Point を探す
                peripheral.discoverCharacteristics([C2_CHAR_CONTROL_POINT, C2_CHAR_DATA_POINT], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        print("RowErgManager: Discovered \(characteristics.count) characteristics for service \(service.uuid)")
        
        for characteristic in characteristics {
            print("RowErgManager:   - Char: \(characteristic.uuid) Properties: \(characteristic.properties.rawValue)")
            
            if characteristic.uuid == C2_CHAR_GENERAL_STATUS ||
               characteristic.uuid == C2_CHAR_ROWING_STATUS_0x32 ||
               characteristic.uuid == C2_CHAR_STROKE_DATA ||
               characteristic.uuid == C2_CHAR_ADDITIONAL_STROKE_DATA_0x36 ||
               characteristic.uuid == C2_CHAR_FORCE_CURVE ||
               characteristic.uuid == C2_CHAR_DATA_POINT {
                print("RowErgManager: Subscribing to Notify for \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == C2_CHAR_CONTROL_POINT {
                print("RowErgManager: Control Point Found (Properties: \(characteristic.properties.rawValue))")
                controlCharacteristic = characteristic
                isControlPointReady = true
                // 0021もNotify/Indicateを持っている可能性があるため購読を試みる
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    print("RowErgManager: Subscribing to Notify for Control Point (0021)")
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
            if characteristic.uuid == C2_CHAR_DATA_POINT {
                // ... (Existing 0022 logic)
                print("RowErgManager: Data Point Found (Subscribing...)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // すべての特性を処理した後にチェック
        checkAllCharacteristicsReady()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("RowErgManager: Error setting notify for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        print("RowErgManager: Notification state updated for \(characteristic.uuid): \(characteristic.isNotifying)")
        
        // Data Point (0022) の通知が有効になったら準備完了フラグを立てる
        if characteristic.uuid == C2_CHAR_DATA_POINT && characteristic.isNotifying {
            isDataPointReady = true
            print("RowErgManager: Data Point Notify ON")
            checkAllCharacteristicsReady()
        }
    }
    
    
    private func parseGeneralStatus(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        DispatchQueue.main.async { self.lastGeneralStatusBytes = hex }
        
        // 初回通知を受信したことを記録
        if !hasReceivedInitialGeneralStatus {
            hasReceivedInitialGeneralStatus = true
            print("RowErgManager: 📡 [0031] First notification received from General Status")
            // 初回通知を受信した時点で通信開始時間を記録（まだ記録されていない場合）
            if communicationStartTime == nil {
                communicationStartTime = Date()
            }
            checkAllCharacteristicsReady()
        }
        
        if data.count >= 6 {
            let b3 = data[3]
            let b4 = data[4]
            let b5 = data[5]
            
            // Correct distance calculation from General Status (0x31) byte[3-5]
            // Format: Little Endian, Unit: 0.1m
            let distRaw = UInt32(b3) | (UInt32(b4) << 8) | (UInt32(b5) << 16)
            let distMeters = Double(distRaw) * 0.1
            
            DispatchQueue.main.async {
                self.generalStatusBytes3to5 = String(format: "%02X %02X %02X", b3, b4, b5)
                self.distance = distMeters // Update the main distance property
            }
            
            let s = data.startIndex
            let timeVal = (UInt32(data[s]) | (UInt32(data[s+1]) << 8) | (UInt32(data[s+2]) << 16))
            let timeSec = Double(timeVal) * 0.01
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.elapsedTime = timeSec
                
                // --- State Inference Logic (Stabilized) ---
                let now = Date()
                let commStart = self.communicationStartTime ?? now
                let elapsedSinceComm = now.timeIntervalSince(commStart)
                
                // 1. Stabilization Period: Don't infer anything for the first 2.0s
                if elapsedSinceComm < 2.0 {
                    if self.currentMachineState != .ready {
                        self.currentMachineState = .ready
                    }
                    return
                }
                
                // 2. Ready Logic (Metric Side)
                // Only set Ready if metrics are 0 AND we are NOT already Rowing.
                // We do NOT promote to Rowing here; only Stroke Data triggers Rowing.
                if timeSec > 0 || distMeters > 0 {
                    // Active metrics, but we wait for Stroke Data to confirm Rowing.
                    // If we are already Rowing, we do nothing (maintain state).
                } else {
                    // Metrics are clear (0.0)
                    // If we are NOT Rowing, we can go to Ready.
                    if self.currentMachineState != .rowing && self.currentMachineState != .ready {
                        print("RowErgManager: 🧠 Inferring 'Ready' state (Metrics are zero)")
                        self.currentMachineState = .ready
                    }
                }
            }
        }
    }

    private func parseRowingStatus0x32(_ data: Data) {
        // SPM from byte 5, Pace from byte[7-8]
        // User formula for Pace: ((Byte 8 * 256) + Byte 7) / 100
        guard data.count >= 9 else { return }
        let rate = Int(data[5])
        let paceRaw = UInt16(data[7]) | (UInt16(data[8]) << 8)
        let paceSec = Double(paceRaw) / 100.0
        
        DispatchQueue.main.async {
            if rate > 0 {
                self.strokeRate = rate
                
                // Active stroke detected -> definitely rowing
                if self.currentMachineState != .rowing {
                    let now = Date()
                    let commStart = self.communicationStartTime ?? now
                    let elapsedSinceComm = now.timeIntervalSince(commStart)
                    if elapsedSinceComm >= 2.0 {
                        print("RowErgManager: 🧠 Inferring 'Rowing' state from 0x32 active stroke (SPM:\(rate))")
                        self.currentMachineState = .rowing
                    }
                }
            }
            
            if paceRaw > 0 {
                self.pace500m = paceSec
            } else {
                self.pace500m = 0.0
            }
        }
    }

    private func parseStrokeData(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        DispatchQueue.main.async { self.lastStrokeDataBytes = hex }
        
        if data.count >= 12 {
            let b6 = data[6]
            let b7 = data[7]
            let b10 = data[10]
            let b11 = data[11]
            DispatchQueue.main.async {
                self.strokeDataBytes6to7 = String(format: "%02X %02X", b6, b7)
                self.strokeDataBytes10to11 = String(format: "%02X %02X", b10, b11)
            }
        }
    }

    private func parseStrokeData0x36(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        DispatchQueue.main.async { self.lastStrokeData0x36Bytes = hex }
        
        // Target: byte[3-4] for Watts (Little Endian)
        if data.count >= 5 {
            let wattsRaw = UInt16(data[3]) | (UInt16(data[4]) << 8)
            let watts = Int(wattsRaw)
            
            DispatchQueue.main.async {
                self.power = watts
            }
        }
    }
}
