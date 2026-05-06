import SwiftUI

struct ResearchSandboxView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var customHex: String = ""
    @State private var researchOpcode: String = "80"
    @State private var researchPayload: String = ""
    @State private var researchMode: RowErgManager.CSAFEFrameMode = .standard
    @State private var useManualChecksum: Bool = false
    @State private var manualChecksum: String = ""
    @State private var innerOpcodeInt: Int = 0x8C // Default start for scan
    @State private var payload9C: Int = 0x01 // Default payload for 0x9C
    @State private var scanOpcode: Int = 0x9C // Target for 0x98-0x9C scan
    @Environment(\.dismiss) var dismiss
    
    private let presetCommands: [(name: String, hex: String)] = [
        ("Empty", ""),
        ("0x00", "00"),
        ("0xFF", "FF"),
        ("2k","f17618010103030580000007d0050580000001f4140101130201014cf2"),
        ("Minimal Syntax", "F1 00 F2"),
        ("WorkoutState","F1 76 01 8D FA F2"),
        ("ScreenState","F1 7E 01 86 F9 F2"),
        ("Ping/Known loop", "F1 01 80 F2"),
        ("Status Cmd", "F1 80 00 F2"),
        ("Short Seq", "01 02 03")
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Machine Status")) {
                HStack {
                    Text("Connection")
                    Spacer()
                    Text(ergManager.connectionState == .connected ? "Connected" : "Disconnected")
                        .foregroundColor(ergManager.connectionState == .connected ? .green : .red)
                }
                HStack {
                    Text("Current State")
                    Spacer()
                    Text(ergManager.currentMachineState.description)
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Safety Controls")) {
                Button(role: .destructive) {
                    ergManager.disconnect()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Emergency Disconnect")
                    }
                }
            }
            Section(header: Text("Unified CSAFE Frame Builder")) {
                Picker("Frame Mode", selection: $researchMode) {
                    Text("Short").tag(RowErgManager.CSAFEFrameMode.short)
                    Text("Standard").tag(RowErgManager.CSAFEFrameMode.standard)
                    Text("Extended").tag(RowErgManager.CSAFEFrameMode.extended)
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Opcode (Hex)")
                    Spacer()
                    TextField("80", text: $researchOpcode)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                
                if researchMode != .short {
                    HStack {
                        Text("Payload (Hex)")
                        Spacer()
                        TextField("Data", text: $researchPayload)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Toggle("Manual Checksum", isOn: $useManualChecksum)
                
                if useManualChecksum {
                    HStack {
                        Text("Checksum ?? (Hex)")
                        Spacer()
                        TextField("8F", text: $manualChecksum)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                
                let frameStr = getGeneratedFramePreview()
                if !frameStr.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(frameStr)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.orange)
                            .bold()
                    }
                }
                
                Button("Send Frame") {
                    sendUnifiedFrame()
                }
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected || researchOpcode.isEmpty)
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected || researchOpcode.isEmpty)
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected || researchOpcode.isEmpty)
            }
            
            Section(header: Text("PM Proprietary Scan (Wrapper 0x76)")) {
                Stepper(value: $innerOpcodeInt, in: 0x80...0x9F) {
                    HStack {
                        Text("Inner Opcode:")
                        Text(String(format: "%02X", innerOpcodeInt))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.purple)
                            .bold()
                    }
                }
                
                let scanFrameStr = getGeneratedScanFrame()
                if !scanFrameStr.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Preview (F1 76 01 [XX] CS F2):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scanFrameStr)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.purple)
                            .bold()
                    }
                }
                
                Button("Send 0x76 Command") {
                    sendScanFrame()
                }
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected)
            }
            
            Section(header: Text("Workout Control Scan (0x98-0x9F)")) {
                Stepper(value: $scanOpcode, in: 0x98...0x9F) {
                    HStack {
                        Text("Target Opcode:")
                        Text(String(format: "%02X", scanOpcode))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.pink)
                            .bold()
                    }
                }
                
                Stepper(value: $payload9C, in: 0x00...0xFF) {
                    HStack {
                        Text("Payload Byte:")
                        Text(String(format: "%02X", payload9C))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.pink)
                            .bold()
                    }
                }
                
                let frame9C = getGenerated9CFrame()
                if !frame9C.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Preview (F1 76 02 [Op] [Py] CS F2):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(frame9C)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.pink)
                            .bold()
                    }
                }
                
                Button("Send 0x9C Command") {
                    send9CFrame()
                }
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected)
            }
            
            Section(header: Text("Advanced CSAFE Test (Literal)")) {
                Text("Sends the Concept2 Specification bitstream EXACTLY as provided, without Status Byte, automated framing, or manual chunking.")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button("Test Literal Spec Frame") {
                    // Concept2 EXACT HEX: F1 76 18 01 01 05 03 05 00 00 00 2E E0 05 05 00 00 00 17 70 14 01 01 13 02 01 01 C1 F2
                    let literalHex = "F1 76 18 01 01 05 03 05 00 00 00 2E E0 05 05 00 00 00 17 70 14 01 01 13 02 01 01 C1 F2"
                    let cleaned = literalHex.replacingOccurrences(of: " ", with: "")
                    if let data = cleaned.hexData() {
                        ergManager.sendResearchWrite(data: data)
                    }
                }
                .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected)
            }
            
            Section(header: Text("Research Logs")) {
                if ergManager.isResearchWriteBusy {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("Cooldown: \(ergManager.researchCooldownRemaining)s")
                            .foregroundColor(.orange)
                            .bold()
                    }
                }
                
                ForEach(presetCommands, id: \.name) { cmd in
                    Button {
                        sendHex(cmd.hex)
                    } label: {
                        HStack {
                            Text(cmd.name)
                            Spacer()
                            Text(cmd.hex).font(.caption).foregroundColor(.gray)
                        }
                    }
                    .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected)
                }
                
                HStack {
                    TextField("Custom Hex (e.g. 01 AF)", text: $customHex)
                        .font(.system(.body, design: .monospaced))
                    
                    Button("Send") {
                        sendHex(customHex)
                    }
                    .disabled(ergManager.isResearchWriteBusy || ergManager.connectionState != .connected || customHex.isEmpty)
                }
                
                if ergManager.researchLogs.isEmpty {
                    Text("No logs yet").foregroundColor(.gray)
                } else {
                    Button("Clear logs") {
                        ergManager.clearResearchLogs()
                    }
                    
                    ForEach(ergManager.researchLogs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                if let state = log.machineState {
                                    Text(state)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            switch log.type {
                            case .tx:
                                HStack(alignment: .top) {
                                    Text("TX")
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 4)
                                        .background(Color.cyan.opacity(0.2))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(4)
                                    Text(log.content)
                                        .font(.system(.caption, design: .monospaced))
                                }
                            case .rx:
                                HStack(alignment: .top) {
                                    Text("RX")
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 4)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                    Text(log.content)
                                        .font(.system(.caption, design: .monospaced))
                                }
                            case .stateChange:
                                HStack(alignment: .top) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                    Text(log.content)
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Research Sandbox")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendHex(_ hex: String) {
        let cleaned = hex.replacingOccurrences(of: " ", with: "")
        guard let data = cleaned.hexData() else {
            print("RowErgManager: Invalid HEX input")
            return
        }
        ergManager.sendResearchWrite(data: data)
    }
    
    private func getGeneratedFramePreview() -> String {
        let opcodeCleaned = researchOpcode.replacingOccurrences(of: " ", with: "")
        guard let opcodeByte = UInt8(opcodeCleaned, radix: 16) else { return "" }
        
        let payloadCleaned = researchPayload.replacingOccurrences(of: " ", with: "")
        let payload = payloadCleaned.hexData() ?? Data()
        
        var csOverride: UInt8? = nil
        if useManualChecksum {
            let csCleaned = manualChecksum.replacingOccurrences(of: " ", with: "")
            csOverride = UInt8(csCleaned, radix: 16)
        }
        
        let frame = ergManager.buildFrame(mode: researchMode, opcode: opcodeByte, payload: payload, checksumOverride: csOverride)
        return frame.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    private func sendUnifiedFrame() {
        let opcodeCleaned = researchOpcode.replacingOccurrences(of: " ", with: "")
        guard let opcodeByte = UInt8(opcodeCleaned, radix: 16) else { return }
        
        let payloadCleaned = researchPayload.replacingOccurrences(of: " ", with: "")
        let payload = payloadCleaned.hexData() ?? Data()
        
        var csOverride: UInt8? = nil
        if useManualChecksum {
            let csCleaned = manualChecksum.replacingOccurrences(of: " ", with: "")
            csOverride = UInt8(csCleaned, radix: 16)
        }
        
        let frame = ergManager.buildFrame(mode: researchMode, opcode: opcodeByte, payload: payload, checksumOverride: csOverride)
        ergManager.sendResearchWrite(data: frame)
    }
    
    private func getGeneratedScanFrame() -> String {
        // Standard Frame: Wrapper 0x76, Payload = [InnerOpcode]
        // Length 0x01 is auto-added by buildFrame(.standard)
        let wrapperOpcode: UInt8 = 0x76
        let payload = Data([UInt8(innerOpcodeInt)])
        
        let frame = ergManager.buildFrame(mode: .standard, opcode: wrapperOpcode, payload: payload, checksumOverride: nil)
        return frame.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    private func sendScanFrame() {
        let wrapperOpcode: UInt8 = 0x76
        let payload = Data([UInt8(innerOpcodeInt)])
        
        let frame = ergManager.buildFrame(mode: .standard, opcode: wrapperOpcode, payload: payload, checksumOverride: nil)
        ergManager.sendResearchWrite(data: frame)
    }
    
    private func getGenerated9CFrame() -> String {
        // Wrapper 0x76, Payload = [scanOpcode] [payload9C]
        let wrapperOpcode: UInt8 = 0x76
        let payload = Data([UInt8(scanOpcode), UInt8(payload9C)])
        
        let frame = ergManager.buildFrame(mode: .standard, opcode: wrapperOpcode, payload: payload, checksumOverride: nil)
        return frame.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    private func send9CFrame() {
        let wrapperOpcode: UInt8 = 0x76
        let payload = Data([UInt8(scanOpcode), UInt8(payload9C)])
        
        let frame = ergManager.buildFrame(mode: .standard, opcode: wrapperOpcode, payload: payload, checksumOverride: nil)
        ergManager.sendResearchWrite(data: frame)
    }
}

// Helper to convert hex string to Data
extension String {
    func hexData() -> Data? {
        var data = Data()
        var hex = self
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }
        
        for i in stride(from: 0, to: hex.count, by: 2) {
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2)
            let hexByte = hex[start..<end]
            if let byte = UInt8(hexByte, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        return data
    }
}
