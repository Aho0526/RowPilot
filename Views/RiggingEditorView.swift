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
    @State private var oarTotalLengthPort: Double
    @State private var oarTotalLengthStarboard: Double
    @State private var oarInboardPort: Double
    @State private var oarInboardStarboard: Double
    @State private var oarBladeType: String
    @State private var oarSleevePitchPort: Double
    @State private var oarSleevePitchStarboard: Double
    @State private var oarGripDiameterPort: Double
    @State private var oarGripDiameterStarboard: Double
    
    // Boat
    @State private var boatSpan: Double
    @State private var boatWorkHeightPort: Double
    @State private var boatWorkHeightStarboard: Double
    @State private var boatPitchPort: Double
    @State private var boatPitchStarboard: Double
    @State private var boatLateralPitchPort: String
    @State private var boatLateralPitchStarboard: String
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
        case oarTotalLengthPort, oarTotalLengthStarboard
        case oarInboardPort, oarInboardStarboard
        case oarBladeType
        case oarSleevePitchPort, oarSleevePitchStarboard
        case oarGripDiameterPort, oarGripDiameterStarboard
        case boatSpan
        case boatWorkHeightPort, boatWorkHeightStarboard
        case boatPitchPort, boatPitchStarboard
        case boatLateralPitchPort, boatLateralPitchStarboard
        case boatFootstretch
        case boatFootplateAngle
        case boatFootplateHeight
        case boatSeatPosition
    }
    @FocusState private var focusedField: Field?
    
    private var activeSide: RiggingSide {
        guard let focused = focusedField else { return .starboard }
        switch focused {
        case .oarTotalLengthPort, .oarInboardPort, .oarSleevePitchPort, .oarGripDiameterPort, .boatWorkHeightPort, .boatPitchPort, .boatLateralPitchPort:
            return .port
        default:
            return .starboard
        }
    }
    
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
        
        _oarTotalLengthPort = State(initialValue: config.oarTotalLengthPort)
        _oarTotalLengthStarboard = State(initialValue: config.oarTotalLengthStarboard)
        _oarInboardPort = State(initialValue: config.oarInboardPort)
        _oarInboardStarboard = State(initialValue: config.oarInboardStarboard)
        _oarBladeType = State(initialValue: config.oarBladeType)
        _oarSleevePitchPort = State(initialValue: config.oarSleevePitchPort)
        _oarSleevePitchStarboard = State(initialValue: config.oarSleevePitchStarboard)
        _oarGripDiameterPort = State(initialValue: config.oarGripDiameterPort)
        _oarGripDiameterStarboard = State(initialValue: config.oarGripDiameterStarboard)
        
        _boatSpan = State(initialValue: config.boatSpan)
        _boatWorkHeightPort = State(initialValue: config.boatWorkHeightPort)
        _boatWorkHeightStarboard = State(initialValue: config.boatWorkHeightStarboard)
        _boatPitchPort = State(initialValue: config.boatPitchPort)
        _boatPitchStarboard = State(initialValue: config.boatPitchStarboard)
        _boatLateralPitchPort = State(initialValue: config.boatLateralPitchPort)
        _boatLateralPitchStarboard = State(initialValue: config.boatLateralPitchStarboard)
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
            _oarTotalLengthPort = State(initialValue: 289.0)
            _oarTotalLengthStarboard = State(initialValue: 289.0)
            _oarInboardPort = State(initialValue: 88.0)
            _oarInboardStarboard = State(initialValue: 88.0)
            _boatSpan = State(initialValue: 160.0)
        } else {
            _oarTotalLengthPort = State(initialValue: 373.0)
            _oarTotalLengthStarboard = State(initialValue: 373.0)
            _oarInboardPort = State(initialValue: 114.0)
            _oarInboardStarboard = State(initialValue: 114.0)
            _boatSpan = State(initialValue: 84.0)
        }
        
        _oarBladeType = State(initialValue: "Smoothie2")
        _oarSleevePitchPort = State(initialValue: 0.0)
        _oarSleevePitchStarboard = State(initialValue: 0.0)
        _oarGripDiameterPort = State(initialValue: 34.0)
        _oarGripDiameterStarboard = State(initialValue: 34.0)
        
        _boatWorkHeightPort = State(initialValue: 16.0)
        _boatWorkHeightStarboard = State(initialValue: 16.0)
        _boatPitchPort = State(initialValue: 4.0)
        _boatPitchStarboard = State(initialValue: 4.0)
        _boatLateralPitchPort = State(initialValue: "4/4")
        _boatLateralPitchStarboard = State(initialValue: "4/4")
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
                                        oarTotalLengthPort = 289.0
                                        oarTotalLengthStarboard = 289.0
                                        oarInboardPort = 88.0
                                        oarInboardStarboard = 88.0
                                        boatSpan = 160.0
                                    } else {
                                        oarTotalLengthPort = 373.0
                                        oarTotalLengthStarboard = 373.0
                                        oarInboardPort = 114.0
                                        oarInboardStarboard = 114.0
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
                                totalLength: activeSide == .port ? oarTotalLengthPort : oarTotalLengthStarboard,
                                inboard: activeSide == .port ? oarInboardPort : oarInboardStarboard,
                                bladeType: selectedBladePreset == "Other" ? customBladeName : selectedBladePreset,
                                sleevePitch: activeSide == .port ? oarSleevePitchPort : oarSleevePitchStarboard,
                                selectedField: activeOarField
                            )
                            
                            VStack(spacing: 14) {
                                // Total Length (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Total Length".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $oarTotalLengthPort, suffix: "cm", focusedField: $focusedField, fieldType: .oarTotalLengthPort)
                                        SideNumericField(title: "Starboard".localized, value: $oarTotalLengthStarboard, suffix: "cm", focusedField: $focusedField, fieldType: .oarTotalLengthStarboard)
                                    }
                                }
                                
                                // Inboard (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Inboard".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $oarInboardPort, suffix: "cm", focusedField: $focusedField, fieldType: .oarInboardPort)
                                        SideNumericField(title: "Starboard".localized, value: $oarInboardStarboard, suffix: "cm", focusedField: $focusedField, fieldType: .oarInboardStarboard)
                                    }
                                }
                                
                                // Outboard (Port & Starboard Display)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Outboard".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideTextDisplayField(title: "Port".localized, valueText: String(format: "%.1f cm", max(0, oarTotalLengthPort - oarInboardPort)))
                                        SideTextDisplayField(title: "Starboard".localized, valueText: String(format: "%.1f cm", max(0, oarTotalLengthStarboard - oarInboardStarboard)))
                                    }
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
                                
                                // Sleeve Pitch (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Sleeve Pitch".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $oarSleevePitchPort, suffix: "°", focusedField: $focusedField, fieldType: .oarSleevePitchPort)
                                        SideNumericField(title: "Starboard".localized, value: $oarSleevePitchStarboard, suffix: "°", focusedField: $focusedField, fieldType: .oarSleevePitchStarboard)
                                    }
                                }
                                
                                // Grip Diameter (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Grip Diameter".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $oarGripDiameterPort, suffix: "mm", focusedField: $focusedField, fieldType: .oarGripDiameterPort)
                                        SideNumericField(title: "Starboard".localized, value: $oarGripDiameterStarboard, suffix: "mm", focusedField: $focusedField, fieldType: .oarGripDiameterStarboard)
                                    }
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
                                workHeightPort: boatWorkHeightPort,
                                workHeightStarboard: boatWorkHeightStarboard,
                                pitchPort: boatPitchPort,
                                pitchStarboard: boatPitchStarboard,
                                lateralPitchPort: boatLateralPitchPort,
                                lateralPitchStarboard: boatLateralPitchStarboard,
                                footstretch: boatFootstretch,
                                footplateAngle: boatFootplateAngle,
                                footplateHeight: boatFootplateHeight,
                                oarTotalLengthPort: oarTotalLengthPort,
                                oarTotalLengthStarboard: oarTotalLengthStarboard,
                                oarInboardPort: oarInboardPort,
                                oarInboardStarboard: oarInboardStarboard,
                                oarGripDiameterPort: oarGripDiameterPort,
                                oarGripDiameterStarboard: oarGripDiameterStarboard,
                                oarType: oarType,
                                selectedField: activeBoatField,
                                activeSide: activeSide,
                                seatPosition: $boatSeatPosition,
                                currentTab: $boatDiagramTab
                            )
                            
                            VStack(spacing: 14) {
                                HStack {
                                    Text(oarType == .scull ? "Span / Spread".localized + " (Pin-to-Pin)" : "Span / Spread".localized + " (Center-to-Pin)")
                                        .foregroundColor(Theme.textSecondary)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    NumericTextField(value: $boatSpan, suffix: "cm")
                                        .focused($focusedField, equals: .boatSpan)
                                }
                                
                                // Work Height (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Work Height".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $boatWorkHeightPort, suffix: "cm", focusedField: $focusedField, fieldType: .boatWorkHeightPort)
                                        SideNumericField(title: "Starboard".localized, value: $boatWorkHeightStarboard, suffix: "cm", focusedField: $focusedField, fieldType: .boatWorkHeightStarboard)
                                    }
                                }
                                
                                // Pitch (Port & Starboard)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Pitch".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SideNumericField(title: "Port".localized, value: $boatPitchPort, suffix: "°", focusedField: $focusedField, fieldType: .boatPitchPort)
                                        SideNumericField(title: "Starboard".localized, value: $boatPitchStarboard, suffix: "°", focusedField: $focusedField, fieldType: .boatPitchStarboard)
                                    }
                                }
                                
                                // Lateral Pitch (Port & Starboard Picker)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("Lateral Pitch".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        SidePickerField(title: "Port".localized, selection: $boatLateralPitchPort, focusedField: $focusedField, fieldType: .boatLateralPitchPort, options: ["4/4", "5/3", "6/2", "7/1"])
                                        SidePickerField(title: "Starboard".localized, selection: $boatLateralPitchStarboard, focusedField: $focusedField, fieldType: .boatLateralPitchStarboard, options: ["4/4", "5/3", "6/2", "7/1"])
                                    }
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
                    case .boatSpan, .boatFootstretch, .oarGripDiameterPort, .oarGripDiameterStarboard, .oarTotalLengthPort, .oarTotalLengthStarboard, .oarInboardPort, .oarInboardStarboard, .boatSeatPosition:
                        boatDiagramTab = 0 // Top View
                    case .boatFootplateAngle, .boatFootplateHeight:
                        boatDiagramTab = 1 // Diagonal View
                    case .boatWorkHeightPort, .boatWorkHeightStarboard, .boatPitchPort, .boatPitchStarboard, .boatLateralPitchPort, .boatLateralPitchStarboard:
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
        case .oarTotalLengthPort, .oarTotalLengthStarboard: return .totalLength
        case .oarInboardPort, .oarInboardStarboard: return .inboard
        case .oarBladeType: return .bladeType
        case .oarSleevePitchPort, .oarSleevePitchStarboard: return .sleevePitch
        case .oarGripDiameterPort, .oarGripDiameterStarboard: return .gripDiameter
        default: return nil
        }
    }
    
    private var activeBoatField: BoatRiggingField? {
        guard let focused = focusedField else { return nil }
        switch focused {
        case .boatSpan: return .span
        case .boatWorkHeightPort, .boatWorkHeightStarboard: return .workHeight
        case .boatPitchPort, .boatPitchStarboard: return .pitch
        case .boatLateralPitchPort, .boatLateralPitchStarboard: return .lateralPitch
        case .boatFootstretch: return .footstretch
        case .boatFootplateAngle: return .footplateAngle
        case .boatFootplateHeight: return .footplateHeight
        case .boatSeatPosition: return .seatPosition
        case .oarTotalLengthPort, .oarTotalLengthStarboard: return .oarLength
        case .oarInboardPort, .oarInboardStarboard: return .oarInboard
        case .oarGripDiameterPort, .oarGripDiameterStarboard: return .oarGripDiameter
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
            oarTotalLengthPort: oarTotalLengthPort,
            oarTotalLengthStarboard: oarTotalLengthStarboard,
            oarInboardPort: oarInboardPort,
            oarInboardStarboard: oarInboardStarboard,
            oarBladeType: finalBlade,
            oarSleevePitchPort: oarSleevePitchPort,
            oarSleevePitchStarboard: oarSleevePitchStarboard,
            oarGripDiameterPort: oarGripDiameterPort,
            oarGripDiameterStarboard: oarGripDiameterStarboard,
            boatSpan: boatSpan,
            boatWorkHeightPort: boatWorkHeightPort,
            boatWorkHeightStarboard: boatWorkHeightStarboard,
            boatPitchPort: boatPitchPort,
            boatPitchStarboard: boatPitchStarboard,
            boatLateralPitchPort: boatLateralPitchPort,
            boatLateralPitchStarboard: boatLateralPitchStarboard,
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
            Spacer()
            TextField("", text: $textString)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.textMain)
                .fixedSize(horizontal: true, vertical: false)
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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(width: 110, alignment: .trailing)
        .background(Color.white.opacity(0.1))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
    
    private func formatDouble(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: val)) ?? String(format: "%.1f", val)
    }
}

// MARK: - Side Components

struct SideNumericField: View {
    let title: String
    @Binding var value: Double
    let suffix: String
    var focusedField: FocusState<RiggingEditorView.Field?>.Binding
    let fieldType: RiggingEditorView.Field
    
    @State private var textString: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 4) {
                TextField("", text: $textString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMain)
                    .focused(focusedField, equals: fieldType)
                    .onChange(of: textString) { _, newValue in
                        let sanitized = newValue.replacingOccurrences(of: ",", with: ".")
                        if let parsed = Double(sanitized) {
                            value = parsed
                        }
                    }
                    .onChange(of: value) { _, newValue in
                        let currentParsed = Double(textString.replacingOccurrences(of: ",", with: ".")) ?? -999999.9
                        if abs(currentParsed - newValue) > 0.0001 {
                            textString = formatDouble(newValue)
                        }
                    }
                    .onChange(of: focusedField.wrappedValue) { _, focused in
                        if focused != fieldType {
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
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            .onTapGesture {
                focusedField.wrappedValue = fieldType
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04).cornerRadius(8))
    }
    
    private func formatDouble(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: val)) ?? String(format: "%.1f", val)
    }
}

struct SideTextDisplayField: View {
    let title: String
    let valueText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack {
                Text(valueText)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textMain.opacity(0.8))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04).cornerRadius(8))
    }
}

struct SidePickerField: View {
    let title: String
    @Binding var selection: String
    var focusedField: FocusState<RiggingEditorView.Field?>.Binding
    let fieldType: RiggingEditorView.Field
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack {
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(Theme.accent)
                .focused(focusedField, equals: fieldType)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04).cornerRadius(8))
    }
}

#Preview {
    NavigationStack {
        RiggingEditorView()
    }
}
