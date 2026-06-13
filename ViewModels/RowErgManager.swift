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
    @Published var isNFCConnecting: Bool = false
    
    // Published Metric Data
    @Published var strokeRate: Int = 0
    @Published var pace500m: Double = 0.0
    @Published var distance: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    @Published var power: Int = 0
    @Published var dragFactor: Int = 0
    @Published var heartRate: Int = 0
    @Published var totalCalories: Double = 0.0
    @Published var averagePower: Double = 0.0
    @Published var projectedWorkTime: Double = 0.0
    @Published var projectedWorkDistance: Double = 0.0
    
    // Target Values (Workout Setup)
    @Published var targetDistance: Double? = nil
    @Published var targetTime: Double? = nil
    @Published var targetCalories: Double? = nil
    @Published var targetSplitDistance: Int? = nil
    @Published var targetSplitTime: Int? = nil
    @Published var targetSplitCalories: Int? = nil
    @Published var showingWorkoutExecution: Bool = false
    
    // High-frequency workout data logging
    @Published var workoutDataPoints: [WorkoutDataPoint] = []
    private var dataRecordingTimer: Timer?
    
    /// ワークアウトが終了したかどうかを判定
    var isWorkoutFinished: Bool {
        if let targetDist = targetDistance {
            return distance >= targetDist
        } else if let targetT = targetTime {
            return elapsedTime >= targetT
        } else if let targetC = targetCalories {
            return totalCalories >= targetC
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
        } else if characteristic.uuid == C2_CHAR_POWER_DATA_0x33 {
            parseStrokeData0x33(rawValue)
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
    
    /// 距離（m）、時間（秒）、またはカロリー（cal）を指定してワークアウトコマンドを生成する
    private func generateWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil, calories: Int? = nil, splitMeters: Int? = nil, splitSeconds: Int? = nil, splitCalories: Int? = nil) -> Data {
        var payload = Data()
        
        // Helper: Append a 32-bit Big-Endian value
        func appendUInt32(_ value: UInt32) {
            let val = value.bigEndian
            withUnsafeBytes(of: val) { payload.append(contentsOf: $0) }
        }

        // 1. CSAFE_PM_SET_WORKOUTTYPE (0x01)
        // User requested: Distance -> 0x03 (FIXEDDIST_SPLITS), Time -> 0x05 (FIXEDTIME_SPLITS), Calories -> 0x0A (FIXEDCALORIE_SPLITS)
        payload.append(contentsOf: [0x01, 0x01])
        if distanceMeters != nil {
            payload.append(0x03)
        } else if timeSeconds != nil {
            payload.append(0x05)
        } else {
            payload.append(0x0A)
        }
        
        // 2. CSAFE_PM_SET_WORKOUTDURATION (0x03)
        // [Cmd, Len(5), Type, B0, B1, B2, B3]
        payload.append(contentsOf: [0x03, 0x05])
        if let dist = distanceMeters {
            payload.append(0x80) // Duration Type: Distance
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(0x00) // Duration Type: Time (Strict PM5 Positive Example)
            appendUInt32(UInt32(time * 100)) // centi-seconds
        } else if let cals = calories {
            payload.append(0x40) // Duration Type: Calories
            appendUInt32(UInt32(cals))
        }
        
        // 3. CSAFE_PM_SET_SPLITDURATION (0x05)
        // [Cmd, Len(5), Type, B0, B1, B2, B3]
        payload.append(contentsOf: [0x05, 0x05])
        if let dm = distanceMeters {
            payload.append(0x80) // Distance Split Type
            // Ensure minimum 100m split and maximum 50 splits
            let minSplit = max(100, Int(ceil(Double(dm) / 50.0)))
            let sVal = splitMeters.map { min(max($0, minSplit), dm) } ?? dm
            appendUInt32(UInt32(sVal))
        } else if let tm = timeSeconds {
            payload.append(0x00) // Time Split Type
            // Ensure minimum 20s split and maximum 50 splits
            let minSplit = max(20, Int(ceil(Double(tm) / 50.0)))
            let sVal = splitSeconds.map { min(max($0, minSplit), tm) } ?? tm
            appendUInt32(UInt32(sVal * 100)) // centi-seconds
        } else if let cals = calories {
            payload.append(0x40) // Calories Split Type
            let minSplit = max(5, Int(ceil(Double(cals) / 50.0)))
            let sVal = splitCalories.map { min(max($0, minSplit), cals) } ?? cals
            appendUInt32(UInt32(sVal))
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
        let minSplit = max(100, Int(ceil(Double(limitedMeters) / 50.0)))
        let limitedSplit = split != nil ? min(max(split!, minSplit), limitedMeters) : min(max(limitedMeters / 5, minSplit), limitedMeters)
        print("RowErgManager: Setting workout distance to \(limitedMeters)m (Split: \(limitedSplit)m)")
        
        DispatchQueue.main.async {
            self.targetDistance = Double(limitedMeters)
            self.targetSplitDistance = limitedSplit
            self.targetTime = nil
            self.targetSplitTime = nil
            self.targetCalories = nil
            self.targetSplitCalories = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = [] // 新しいワークアウト開始時に前回のデータを消去
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        
        // ワークアウト変更・開始前に強制終了コマンドを送信
        sendTerminateWorkout()
        
        let cmd = generateWorkoutCommand(distanceMeters: limitedMeters, splitMeters: limitedSplit)
        // PM5の処理待ちのため遅延させて送信（Terminateからの状態遷移を待つ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd) {
                print("RowErgManager: Workout distance command sent.")
            }
        }
    }
    
    func setWorkoutTime(seconds: Int, split: Int? = nil) {
        let limitedSeconds = min(max(seconds, 20), 36000)
        let minSplit = max(20, Int(ceil(Double(limitedSeconds) / 50.0)))
        let limitedSplit = split != nil ? min(max(split!, minSplit), limitedSeconds) : min(max(limitedSeconds / 5, minSplit), limitedSeconds)
        print("RowErgManager: Setting workout time to \(limitedSeconds)s (Split: \(limitedSplit)s)")
        
        DispatchQueue.main.async {
            self.targetTime = Double(limitedSeconds)
            self.targetSplitTime = limitedSplit
            self.targetDistance = nil
            self.targetSplitDistance = nil
            self.targetCalories = nil
            self.targetSplitCalories = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = [] // 新しいワークアウト開始時に前回のデータを消去
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        
        // ワークアウト変更・開始前に強制終了コマンドを送信
        sendTerminateWorkout()
        
        let cmd = generateWorkoutCommand(timeSeconds: limitedSeconds, splitSeconds: limitedSplit)
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

    func setWorkoutCalories(calories: Int, split: Int? = nil) {
        let limitedCalories = min(max(calories, 5), 65535)
        let minSplit = max(5, Int(ceil(Double(limitedCalories) / 50.0)))
        let limitedSplit = split != nil ? min(max(split!, minSplit), limitedCalories) : min(max(limitedCalories / 5, minSplit), limitedCalories)
        print("RowErgManager: Setting workout calories to \(limitedCalories)cal (Split: \(limitedSplit)cal)")
        
        DispatchQueue.main.async {
            self.targetCalories = Double(limitedCalories)
            self.targetSplitCalories = limitedSplit
            self.targetDistance = nil
            self.targetSplitDistance = nil
            self.targetTime = nil
            self.targetSplitTime = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = []
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        sendTerminateWorkout()
        
        let cmd = generateWorkoutCommand(calories: limitedCalories, splitCalories: limitedSplit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd) {
                print("RowErgManager: Workout calories command sent.")
            }
        }
    }
    
    // MARK: - Interval Methods

    private func generateIntervalWorkoutCommand(distanceMeters: Int? = nil, timeSeconds: Int? = nil, calories: Int? = nil, restSeconds: Int) -> Data {
        var payload = Data()
        func appendUInt32(_ value: UInt32) {
            let val = value.bigEndian
            withUnsafeBytes(of: val) { payload.append(contentsOf: $0) }
        }

        // 1. CSAFE_PM_SET_WORKOUTTYPE (0x01)
        // Distance Interval -> 0x07, Time Interval -> 0x06, Calories Interval -> 0x0C
        payload.append(contentsOf: [0x01, 0x01])
        if distanceMeters != nil {
            payload.append(0x07)
        } else if timeSeconds != nil {
            payload.append(0x06)
        } else {
            payload.append(0x0C)
        }
        
        // 2. CSAFE_PM_SET_WORKOUTDURATION (0x03)
        payload.append(contentsOf: [0x03, 0x05])
        if let dist = distanceMeters {
            payload.append(0x80)
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(0x00)
            appendUInt32(UInt32(time * 100))
        } else if let cals = calories {
            payload.append(0x40)
            appendUInt32(UInt32(cals))
        }
        
        // 3. CSAFE_PM_SET_SPLITDURATION (0x05)
        // Calories Interval does not use Split Duration per spec
        if let dist = distanceMeters {
            payload.append(contentsOf: [0x05, 0x05, 0x80])
            appendUInt32(UInt32(dist))
        } else if let time = timeSeconds {
            payload.append(contentsOf: [0x05, 0x05, 0x00])
            appendUInt32(UInt32(time * 100))
        }
        
        // 4. CSAFE_PM_SET_RESTDURATION (0x04)
        // [04, 02, B0, B1] (UInt16 seconds)
        payload.append(0x04)
        payload.append(0x02)
        let rVal = UInt16(min(restSeconds, 595))
        payload.append(UInt8((rVal >> 8) & 0xFF))
        payload.append(UInt8(rVal & 0xFF))
        
        // 4. CSAFE_PM_CONFIGURE_WORKOUT (0x14)
        payload.append(contentsOf: [0x14, 0x01, 0x01])
        
        // 5. CSAFE_PM_SET_SCREENSTATE (0x13)
        payload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
        
        var fullCommand = Data()
        fullCommand.append(0x76)
        fullCommand.append(UInt8(payload.count))
        fullCommand.append(payload)
        return fullCommand
    }

    func setFixedIntervalDistance(meters: Int, rest: Int) {
        let limitedMeters = min(max(meters, 100), 60000)
        let limitedRest = min(max(rest, 0), 595)
        
        DispatchQueue.main.async {
            self.targetDistance = Double(limitedMeters)
            self.targetTime = nil
            self.targetCalories = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = []
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        sendTerminateWorkout()
        
        let cmd = generateIntervalWorkoutCommand(distanceMeters: limitedMeters, restSeconds: limitedRest)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd)
        }
    }

    func setFixedIntervalTime(seconds: Int, rest: Int) {
        let limitedSeconds = min(max(seconds, 20), 36000)
        let limitedRest = min(max(rest, 0), 595)
        
        DispatchQueue.main.async {
            self.targetTime = Double(limitedSeconds)
            self.targetDistance = nil
            self.targetCalories = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = []
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        sendTerminateWorkout()
        
        let cmd = generateIntervalWorkoutCommand(timeSeconds: limitedSeconds, restSeconds: limitedRest)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd)
        }
    }

    func setFixedIntervalCalories(calories: Int, rest: Int) {
        let limitedCalories = min(max(calories, 5), 65535)
        let limitedRest = min(max(rest, 0), 595)
        
        DispatchQueue.main.async {
            self.targetCalories = Double(limitedCalories)
            self.targetDistance = nil
            self.targetTime = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = []
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        sendTerminateWorkout()
        
        let cmd = generateIntervalWorkoutCommand(calories: limitedCalories, restSeconds: limitedRest)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFESingle(payload: cmd)
        }
    }

    // MARK: - Variable Interval (Stateful Builder)

    private func buildVariableIntervalBlock(index: Int, entry: VariableIntervalEntry) -> Data {
        var block = Data()
        func appendUInt32(_ v: UInt32) {
            withUnsafeBytes(of: v.bigEndian) { block.append(contentsOf: $0) }
        }
        
        block.append(contentsOf: [0x18, 0x01, UInt8(index)])
        block.append(contentsOf: [0x17, 0x01])
        if entry.distanceMeters != nil {
            block.append(0x01) // Distance
        } else if entry.timeSeconds != nil {
            block.append(0x00) // Time
        } else if entry.calories != nil {
            block.append(0x06) // Calorie
        } else {
            block.append(0x00)
        }
        
        block.append(contentsOf: [0x03, 0x05])
        if let dist = entry.distanceMeters {
            block.append(0x80)
            appendUInt32(UInt32(dist))
        } else if let time = entry.timeSeconds {
            block.append(0x00)
            appendUInt32(UInt32(time * 100))
        } else if let cals = entry.calories {
            block.append(0x40)
            appendUInt32(UInt32(cals))
        }
        
        block.append(0x04)
        block.append(0x02)
        let rSec = UInt16(min(entry.restSeconds, 595))
        block.append(UInt8((rSec >> 8) & 0xFF))
        block.append(UInt8(rSec & 0xFF))
        
        block.append(contentsOf: [0x06, 0x04])
        if let pace = entry.targetPace500mSeconds {
            appendUInt32(UInt32(pace * 100))
        } else {
            appendUInt32(0)
        }
        
        block.append(contentsOf: [0x14, 0x01, 0x01])
        return block
    }

    func generateVariableIntervalPayloads(intervals: [VariableIntervalEntry]) -> [Data] {
        var payloads: [Data] = []
        let intervalsPerFrame = 2
        var currentPayload = Data()
        var currentIntervalCount = 0
        
        for (i, entry) in intervals.enumerated() {
            if i == 0 {
                currentPayload.append(contentsOf: [0x01, 0x01, 0x08])
            }
            currentPayload.append(buildVariableIntervalBlock(index: i, entry: entry))
            currentIntervalCount += 1
            let isLastInterval = (i == intervals.count - 1)
            
            if currentIntervalCount == intervalsPerFrame || isLastInterval {
                if isLastInterval {
                    currentPayload.append(contentsOf: [0x13, 0x02, 0x01, 0x01])
                }
                var fullCommand = Data()
                fullCommand.append(0x76)
                fullCommand.append(UInt8(currentPayload.count))
                fullCommand.append(currentPayload)
                payloads.append(fullCommand)
                currentPayload = Data()
                currentIntervalCount = 0
            }
        }
        return payloads
    }

    func setVariableIntervalWorkout(intervals: [VariableIntervalEntry]) {
        DispatchQueue.main.async {
            self.targetDistance = nil
            self.targetTime = nil
            self.showingWorkoutExecution = true
            self.completedForceCurve = []
            self.workoutDataPoints = []
        }
        
        startDataRecordingTimer()
        sendTerminateWorkout()
        
        let payloads = generateVariableIntervalPayloads(intervals: intervals)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendCSAFEChunkedSequence(payloads: payloads)
        }
    }

    /// ワークアウトを保存/破棄後に同じ設定で再開する
    func resetAndStartWorkout(distance: Double?, time: Double?, calories: Double?, split: Int? = nil) {
        print("RowErgManager: Resetting and queuing new workout with 1s delay")
        
        // リセット送信し、数値をゼロに戻す (targetDistance/Time/Caloriesは一旦nilになる)
        resetWorkout()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if let dist = distance {
                self.setWorkoutDistance(meters: Int(dist), split: split)
            } else if let t = time {
                self.setWorkoutTime(seconds: Int(t), split: split)
            } else if let c = calories {
                self.setWorkoutCalories(calories: Int(c), split: split)
            }
        }
    }
    
    /// ワークアウトをリセットし、PM5に強制終了コマンドを送信する
    func resetWorkout() {
        print("RowErgManager: Resetting workout and sending TERMINATE command")
        sendTerminateWorkout()
        stopDataRecordingTimer()
        DispatchQueue.main.async {
            self.targetDistance = nil
            self.targetTime = nil
            self.targetCalories = nil
            self.targetSplitCalories = nil
            self.distance = 0
            self.elapsedTime = 0
            self.strokeRate = 0
            self.power = 0
            self.dragFactor = 0
            self.heartRate = 0
            self.totalCalories = 0.0
            self.averagePower = 0.0
            self.projectedWorkTime = 0.0
            self.projectedWorkDistance = 0.0
            self.lastStrokeCount = -1
        }
    }
    
    // MARK: - Data Recording Timer
    private func startDataRecordingTimer() {
        stopDataRecordingTimer()
        DispatchQueue.main.async {
            self.dataRecordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.recordDataPoint()
            }
        }
    }
    
    private func stopDataRecordingTimer() {
        DispatchQueue.main.async {
            self.dataRecordingTimer?.invalidate()
            self.dataRecordingTimer = nil
        }
    }
    
    private func recordDataPoint() {
        // Record only when actively rowing (or when time is advancing)
        guard currentMachineState == .rowing || currentMachineState == .ready || currentMachineState == .idle else { return }
        
        let point = WorkoutDataPoint(
            timeOffset: elapsedTime,
            pace: pace500m,
            spm: strokeRate,
            power: power,
            distance: distance
        )
        
        DispatchQueue.main.async {
            self.workoutDataPoints.append(point)
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
        var foundSerial: String?
        for message in messages {
            for record in message.records {
                var payloadString: String?
                
                // 1. Textレコード (Type "T") のパース
                if record.typeNameFormat == .nfcWellKnown,
                   let type = String(data: record.type, encoding: .utf8), type == "T" {
                    let payload = record.payload
                    if payload.count > 1 {
                        let statusByte = payload[0]
                        let languageCodeLength = Int(statusByte & 0x3F)
                        let textEncoding = (statusByte & 0x80) == 0 ? String.Encoding.utf8 : String.Encoding.utf16
                        if payload.count > 1 + languageCodeLength {
                            let textData = payload.dropFirst(1 + languageCodeLength)
                            payloadString = String(data: textData, encoding: textEncoding)
                        }
                    }
                }
                // 2. URIレコード (Type "U") のパース
                else if record.typeNameFormat == .nfcWellKnown,
                        let type = String(data: record.type, encoding: .utf8), type == "U" {
                    let payload = record.payload
                    if payload.count > 1 {
                        // 1バイト目はプレフィックスなのでスキップ
                        let uriData = payload.dropFirst(1)
                        payloadString = String(data: uriData, encoding: .utf8)
                    }
                }
                // 3. その他のレコードタイプ（フォールバック：バイナリ形式のExternalレコード等を含む）
                else {
                    let payload = record.payload
                    // PM5のBLEペアリングExternalレコード（BLE MACアドレス(6)+タイプ(1)=7バイトの後にデバイス名が続く）
                    if payload.count > 7 {
                        let nameData = payload.dropFirst(7)
                        if let nameStr = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {
                            // 制御文字を除去
                            let cleaned = nameStr.trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleaned.localizedCaseInsensitiveContains("PM5") {
                                payloadString = cleaned
                                print("RowErgManager: NFC Parsed Name from External Payload -> \(cleaned)")
                            }
                        }
                    }
                    
                    // それでも取得できない場合は、全体を単純文字列化
                    if payloadString == nil {
                        payloadString = String(data: payload, encoding: .utf8) ?? String(data: payload, encoding: .ascii)
                    }
                }
                
                if let str = payloadString {
                    print("RowErgManager: NFC Raw Payload String -> \(str)")
                    
                    // シリアル番号 (Concept2 PM5のシリアルは通常9桁の数字) を探す
                    if let range = str.range(of: "\\d{9}", options: .regularExpression) {
                        foundSerial = String(str[range])
                        print("RowErgManager: NFC Found Serial Number (9 digits) -> \(foundSerial!)")
                        break
                    }
                    
                    // URLのパスからpm5の直後の数字を取り出す (9桁以外でも対応できるように)
                    // 例: pm5/1234567890
                    if let range = str.range(of: "(?i)pm5/([0-9a-zA-Z]+)", options: .regularExpression) {
                        let matched = String(str[range])
                        let clean = matched.replacingOccurrences(of: "pm5/", with: "", options: .caseInsensitive)
                        foundSerial = clean
                        print("RowErgManager: NFC Found Serial (from URL path) -> \(clean)")
                        break
                    }
                    
                    // フォールバック: "PM5"または"pm5"を含む文字列全体
                    if str.localizedCaseInsensitiveContains("PM5") {
                        foundSerial = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("RowErgManager: NFC Fallback text contains PM5 -> \(foundSerial!)")
                        break
                    }
                }
            }
            if foundSerial != nil { break }
        }
        
        if let serial = foundSerial {
            session.alertMessage = "PM5を検出しました。\n接続を開始します..."
            print("RowErgManager: NFC Matched Serial -> \(serial)")
            DispatchQueue.main.async {
                self.targetPeripheralName = serial
                self.isNFCConnecting = true
                if !self.isScanning {
                    self.startScanning()
                } else {
                    if let existing = self.discoveredDevices.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains(serial) }) {
                        self.connect(existing)
                    }
                }
            }
        } else {
             session.alertMessage = "PM5シリアル番号を読み取れませんでした。"
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
        let isTarget = targetPeripheralName != nil && name.localizedCaseInsensitiveContains(targetPeripheralName!)
        
        if isPM5 || isTarget {
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                print("RowErgManager: Discovered -> \(name)")
                discoveredDevices.append(peripheral)
                
                if let target = targetPeripheralName, name.localizedCaseInsensitiveContains(target) {
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
        isNFCConnecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("RowErgManager: Disconnected from \(peripheral.name ?? "Unknown")")
        connectionState = .disconnected
        connectedPeripheral = nil
        controlCharacteristic = nil
        strokeRate = 0
        pace500m = 0.0
        power = 0
        isNFCConnecting = false
        // Internal tracking cleanup
        lastStrokeCount = -1
        stopDataRecordingTimer()
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
                peripheral.discoverCharacteristics([C2_CHAR_GENERAL_STATUS, C2_CHAR_ROWING_STATUS_0x32, C2_CHAR_POWER_DATA_0x33, C2_CHAR_STROKE_DATA, C2_CHAR_ADDITIONAL_STROKE_DATA_0x36, C2_CHAR_FORCE_CURVE], for: service)
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
               characteristic.uuid == C2_CHAR_POWER_DATA_0x33 ||
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
        
        // Drag Factor: Byte 18
        if data.count >= 19 {
            let drag = Int(data[18])
            DispatchQueue.main.async {
                self.dragFactor = drag
            }
        }
        
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
        let hr = Int(data[6])
        let paceRaw = UInt16(data[7]) | (UInt16(data[8]) << 8)
        let paceSec = Double(paceRaw) / 100.0
        
        DispatchQueue.main.async {
            self.heartRate = hr
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
        
        // Projected Work Time: bytes 9-11, Projected Work Distance: bytes 12-14
        if data.count >= 15 {
            let timeRaw = UInt32(data[9]) | (UInt32(data[10]) << 8) | (UInt32(data[11]) << 16)
            let distRaw = UInt32(data[12]) | (UInt32(data[13]) << 8) | (UInt32(data[14]) << 16)
            
            DispatchQueue.main.async {
                self.projectedWorkTime = Double(timeRaw)
                self.projectedWorkDistance = Double(distRaw)
            }
        }
    }

    private func parseStrokeData0x33(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        DispatchQueue.main.async { self.lastStrokeData0x33Bytes = hex }
        
        // Extra Status 2: avgPower is byte 4-5, totalCalories is byte 6-7
        if data.count >= 8 {
            let avgPowerRaw = UInt16(data[4]) | (UInt16(data[5]) << 8)
            let totalCalRaw = UInt16(data[6]) | (UInt16(data[7]) << 8)
            
            DispatchQueue.main.async {
                self.averagePower = Double(avgPowerRaw)
                self.totalCalories = Double(totalCalRaw)
            }
        }
    }
}
