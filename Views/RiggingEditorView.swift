import SwiftUI

struct RiggingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var riggingManager = RiggingManager.shared
    
    // Config being edited
    @State private var configId: UUID
    @State private var name: String
    @State private var date: Date
    @State private var boatType: BoatType
    @State private var oarType: OarType
    
    // Oar
    @State private var oarTotalLength: Double
    @State private var oarInboard: Double
    @State private var oarBladeType: String
    @State private var oarSleevePitch: Double
    @State private var oarGripDiameter: Double
    
    // Boat
    @State private var boatSpan: Double
    @State private var boatWorkHeight: Double
    @State private var boatPitch: Double
    @State private var boatLateralPitch: String
    @State private var boatFootstretch: Double
    @State private var boatFootplateAngle: Double
    @State private var boatFootplateHeight: Double
    @State private var boatSeatPosition: Double
    
    // Blade Preset State
    @State private var selectedBladePreset: String = "Smoothie2"
    @State private var customBladeName: String = ""
    
    // Focused states
    enum Field: Hashable {
        case name
        case oarTotalLength
        case oarInboard
        case oarBladeType
        case oarSleevePitch
        case oarGripDiameter
        case boatSpan
        case boatWorkHeight
        case boatPitch
        case boatLateralPitch
        case boatFootstretch
        case boatFootplateAngle
        case boatFootplateHeight
        case boatSeatPosition
    }
    @FocusState private var focusedField: Field?
    
    // Interactive diagram states
    @State private var boatDiagramTab: Int = 0 // 0: Top, 1: Side
    
    private var isNew: Bool
    private let bladePresets = ["Smoothie2", "Comp", "Macon", "Other"]
    
    private var isJA: Bool {
        LocalizationManager.shared.language == .japanese
    }
    
    // Initializer for editing existing
    init(config: RiggingConfig) {
        _configId = State(initialValue: config.id)
        _name = State(initialValue: config.name)
        _date = State(initialValue: config.date)
        _boatType = State(initialValue: config.boatType)
        _oarType = State(initialValue: config.oarType)
        
        _oarTotalLength = State(initialValue: config.oarTotalLength)
        _oarInboard = State(initialValue: config.oarInboard)
        _oarBladeType = State(initialValue: config.oarBladeType)
        _oarSleevePitch = State(initialValue: config.oarSleevePitch)
        _oarGripDiameter = State(initialValue: config.oarGripDiameter)
        
        _boatSpan = State(initialValue: config.boatSpan)
        _boatWorkHeight = State(initialValue: config.boatWorkHeight)
        _boatPitch = State(initialValue: config.boatPitch)
        _boatLateralPitch = State(initialValue: config.boatLateralPitch)
        _boatFootstretch = State(initialValue: config.boatFootstretch)
        _boatFootplateAngle = State(initialValue: config.boatFootplateAngle)
        _boatFootplateHeight = State(initialValue: config.boatFootplateHeight)
        _boatSeatPosition = State(initialValue: config.boatSeatPosition)
        
        isNew = false
        
        // Blade Type Preset determination
        let blade = config.oarBladeType
        if ["smoothie2", "comp", "macon"].contains(blade.lowercased()) {
            // Find correct casing preset
            if blade.lowercased() == "smoothie2" {
                _selectedBladePreset = State(initialValue: "Smoothie2")
            } else if blade.lowercased() == "comp" {
                _selectedBladePreset = State(initialValue: "Comp")
            } else {
                _selectedBladePreset = State(initialValue: "Macon")
            }
        } else {
            _selectedBladePreset = State(initialValue: "Other")
            _customBladeName = State(initialValue: blade)
        }
    }
    
    // Initializer for creating new
    init(boatType: BoatType = .singleSculls) {
        _configId = State(initialValue: UUID())
        _name = State(initialValue: "")
        _date = State(initialValue: Date())
        _boatType = State(initialValue: boatType)
        _oarType = State(initialValue: boatType.isScull ? .scull : .sweep)
        
        // Standard defaults based on scull vs sweep
        if boatType.isScull {
            _oarTotalLength = State(initialValue: 289.0)
            _oarInboard = State(initialValue: 88.0)
            _boatSpan = State(initialValue: 160.0)
        } else {
            _oarTotalLength = State(initialValue: 373.0)
            _oarInboard = State(initialValue: 114.0)
            _boatSpan = State(initialValue: 84.0)
        }
        
        _oarBladeType = State(initialValue: "Smoothie2")
        _oarSleevePitch = State(initialValue: 0.0)
        _oarGripDiameter = State(initialValue: 34.0)
        
        _boatWorkHeight = State(initialValue: 16.0)
        _boatPitch = State(initialValue: 4.0)
        _boatLateralPitch = State(initialValue: "4/4")
        _boatFootstretch = State(initialValue: 8.0)
        _boatFootplateAngle = State(initialValue: 42.0)
        _boatFootplateHeight = State(initialValue: 15.0)
        _boatSeatPosition = State(initialValue: 28.0)
        
        isNew = true
        _selectedBladePreset = State(initialValue: "Smoothie2")
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile Info".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Setup Name".localized)
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 90, alignment: .leading)
                                    TextField("e.g. My Single Scull Setup", text: $name)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .focused($focusedField, equals: .name)
                                        .foregroundColor(Theme.textMain)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Picker("Boat Type".localized, selection: $boatType) {
                                    ForEach(BoatType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(Theme.accent)
                                .onChange(of: boatType) { _, newType in
                                    oarType = newType.isScull ? .scull : .sweep
                                    if newType.isScull {
                                        oarTotalLength = 289.0
                                        oarInboard = 88.0
                                        boatSpan = 160.0
                                    } else {
                                        oarTotalLength = 373.0
                                        oarInboard = 114.0
                                        boatSpan = 84.0
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Oar Rigging Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Oar Rigging".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                            
                            OarDiagramView(
                                totalLength: oarTotalLength,
                                inboard: oarInboard,
                                bladeType: selectedBladePreset == "Other" ? customBladeName : selectedBladePreset,
                                sleevePitch: oarSleevePitch,
                                selectedField: activeOarField
                            )
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Total Length".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $oarTotalLength, suffix: "cm")
                                        .focused($focusedField, equals: .oarTotalLength)
                                }
                                
                                HStack {
                                    Text("Inboard".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $oarInboard, suffix: "cm")
                                        .focused($focusedField, equals: .oarInboard)
                                }
                                
                                HStack {
                                    Text("Outboard".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.1f cm", max(0, oarTotalLength - oarInboard)))
                                        .foregroundColor(Theme.textMain.opacity(0.8))
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Blade Type".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Picker("", selection: $selectedBladePreset) {
                                        ForEach(bladePresets, id: \.self) { preset in
                                            Text(preset).tag(preset)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .tint(Theme.accent)
                                }
                                
                                if selectedBladePreset == "Other" {
                                    HStack {
                                        Text(isJA ? "カスタム名" : "Custom Name")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        TextField("e.g. Cleaver", text: $customBladeName)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .focused($focusedField, equals: .oarBladeType)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundColor(Theme.textMain)
                                            .frame(width: 140)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .transition(.opacity)
                                }
                                
                                HStack {
                                    Text("Sleeve Pitch".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $oarSleevePitch, suffix: "°")
                                        .focused($focusedField, equals: .oarSleevePitch)
                                }
                                
                                HStack {
                                    Text("Grip Diameter".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $oarGripDiameter, suffix: "mm")
                                        .focused($focusedField, equals: .oarGripDiameter)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Boat Rigging Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Boat Rigging".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                            
                            BoatRiggingDiagramView(
                                span: boatSpan,
                                workHeight: boatWorkHeight,
                                pitch: boatPitch,
                                lateralPitch: boatLateralPitch,
                                footstretch: boatFootstretch,
                                footplateAngle: boatFootplateAngle,
                                footplateHeight: boatFootplateHeight,
                                oarTotalLength: oarTotalLength,
                                oarInboard: oarInboard,
                                oarGripDiameter: oarGripDiameter,
                                oarType: oarType,
                                selectedField: activeBoatField,
                                seatPosition: $boatSeatPosition,
                                currentTab: $boatDiagramTab
                            )
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text(oarType == .scull ? "Span / Spread".localized + " (Pin-to-Pin)" : "Span / Spread".localized + " (Center-to-Pin)")
                                        .foregroundColor(Theme.textSecondary)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    NumericTextField(value: $boatSpan, suffix: "cm")
                                        .focused($focusedField, equals: .boatSpan)
                                }
                                
                                HStack {
                                    Text("Work Height".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatWorkHeight, suffix: "cm")
                                        .focused($focusedField, equals: .boatWorkHeight)
                                }
                                
                                HStack {
                                    Text("Pitch".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatPitch, suffix: "°")
                                        .focused($focusedField, equals: .boatPitch)
                                }
                                
                                HStack {
                                    Text("Lateral Pitch".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Picker("", selection: $boatLateralPitch) {
                                        Text("4/4").tag("4/4")
                                        Text("5/3").tag("5/3")
                                        Text("6/2").tag("6/2")
                                        Text("7/1").tag("7/1")
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .tint(Theme.accent)
                                    .frame(width: 110, alignment: .trailing)
                                    .focused($focusedField, equals: .boatLateralPitch)
                                }
                                
                                HStack {
                                    Text("Footstretch".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatFootstretch, suffix: "cm")
                                        .focused($focusedField, equals: .boatFootstretch)
                                }
                                
                                HStack {
                                    Text("Footplate Angle".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatFootplateAngle, suffix: "°")
                                        .focused($focusedField, equals: .boatFootplateAngle)
                                }
                                
                                HStack {
                                    Text("Footplate Height".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatFootplateHeight, suffix: "cm")
                                        .focused($focusedField, equals: .boatFootplateHeight)
                                }
                                
                                HStack {
                                    Text("Seat Position".localized)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    NumericTextField(value: $boatSeatPosition, suffix: "cm")
                                        .focused($focusedField, equals: .boatSeatPosition)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.vertical)
                }
                
                // Bottom Button Panel
                VStack {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    Button(action: saveSetup) {
                        Text("Save Setup".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryGradient)
                            .cornerRadius(12)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.3))
            }
        }
        .navigationTitle(isNew ? "Create New Setup".localized : "Edit Setup".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel".localized) {
                    dismiss()
                }
                .foregroundColor(Theme.accent)
            }
        }
        .onChange(of: focusedField) { _, newValue in
            // Auto switch boat tab depending on focused field
            if let val = newValue {
                withAnimation(.easeInOut) {
                    switch val {
                    case .boatSpan, .boatFootstretch, .oarGripDiameter, .oarTotalLength, .oarInboard, .boatSeatPosition:
                        boatDiagramTab = 0 // Top View
                    case .boatFootplateAngle, .boatFootplateHeight:
                        boatDiagramTab = 1 // Diagonal View
                    case .boatWorkHeight, .boatPitch, .boatLateralPitch:
                        boatDiagramTab = 2 // Side View
                    default:
                        break
                    }
                }
            }
        }
        .onChange(of: selectedBladePreset) { _, newPreset in
            if newPreset == "Other" {
                focusedField = .oarBladeType
            } else {
                focusedField = nil
            }
        }
    }
    
    // MARK: - Focused fields mapping to diagram highlight fields
    
    private var activeOarField: OarField? {
        guard let focused = focusedField else { return nil }
        switch focused {
        case .oarTotalLength: return .totalLength
        case .oarInboard: return .inboard
        case .oarBladeType: return .bladeType
        case .oarSleevePitch: return .sleevePitch
        case .oarGripDiameter: return .gripDiameter
        default: return nil
        }
    }
    
    private var activeBoatField: BoatRiggingField? {
        guard let focused = focusedField else { return nil }
        switch focused {
        case .boatSpan: return .span
        case .boatWorkHeight: return .workHeight
        case .boatPitch: return .pitch
        case .boatLateralPitch: return .lateralPitch
        case .boatFootstretch: return .footstretch
        case .boatFootplateAngle: return .footplateAngle
        case .boatFootplateHeight: return .footplateHeight
        case .boatSeatPosition: return .seatPosition
        case .oarTotalLength: return .oarLength
        case .oarInboard: return .oarInboard
        case .oarGripDiameter: return .oarGripDiameter
        default: return nil
        }
    }
    
    // MARK: - Save Action
    
    private func saveSetup() {
        let finalBlade = selectedBladePreset == "Other" 
            ? (customBladeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Cleaver" : customBladeName)
            : selectedBladePreset
            
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "\(boatType.displayName) Setup" 
            : name
            
        let config = RiggingConfig(
            id: configId,
            name: finalName,
            date: Date(),
            boatType: boatType,
            oarType: oarType,
            oarTotalLength: oarTotalLength,
            oarInboard: oarInboard,
            oarBladeType: finalBlade,
            oarSleevePitch: oarSleevePitch,
            oarGripDiameter: oarGripDiameter,
            boatSpan: boatSpan,
            boatWorkHeight: boatWorkHeight,
            boatPitch: boatPitch,
            boatLateralPitch: boatLateralPitch,
            boatFootstretch: boatFootstretch,
            boatFootplateAngle: boatFootplateAngle,
            boatFootplateHeight: max(0.0, min(25.0, boatFootplateHeight)),
            boatSeatPosition: boatSeatPosition
        )
        
        if isNew {
            riggingManager.addConfig(config)
        } else {
            riggingManager.updateConfig(config)
        }
        
        dismiss()
    }
}

// MARK: - Numeric TextField Component for clean numeric inputs

struct NumericTextField: View {
    @Binding var value: Double
    let suffix: String
    
    @State private var textString: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $textString)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.textMain)
                .frame(width: 70)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .focused($isFocused)
                .onChange(of: textString) { _, newValue in
                    let sanitized = newValue.replacingOccurrences(of: ",", with: ".")
                    if let parsed = Double(sanitized) {
                        value = parsed
                    }
                }
                .onChange(of: value) { _, newValue in
                    // If the value changes from outside (e.g., preset change) and doesn't match our parsed value, update string
                    let currentParsed = Double(textString.replacingOccurrences(of: ",", with: ".")) ?? -999999.9
                    if abs(currentParsed - newValue) > 0.0001 {
                        textString = formatDouble(newValue)
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Re-format cleanly on focus lost
                        textString = formatDouble(value)
                    }
                }
                .onAppear {
                    textString = formatDouble(value)
                }
                .onSubmit {
                    textString = formatDouble(value)
                }
            
            Text(suffix)
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 30, alignment: .leading)
        }
        .frame(width: 110, alignment: .trailing)
    }
    
    private func formatDouble(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: val)) ?? String(format: "%.1f", val)
    }
}
#Preview {
    NavigationStack {
        RiggingEditorView()
    }
}
