import Foundation

enum OarType: String, Codable, CaseIterable, Identifiable {
    case scull = "Scull"
    case sweep = "Sweep"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .scull:
            return "Scull".localized
        case .sweep:
            return "Sweep".localized
        }
    }
}

struct RiggingConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var date: Date
    var boatType: BoatType
    
    // Oar measurements
    var oarType: OarType
    var oarTotalLengthPort: Double // cm (e.g. 289)
    var oarTotalLengthStarboard: Double
    var oarInboardPort: Double // cm (e.g. 88)
    var oarInboardStarboard: Double
    var oarBladeType: String // e.g. "Smoothie2 Plain"
    var oarSleevePitchPort: Double // degrees (e.g. 0.0 or 4.0)
    var oarSleevePitchStarboard: Double
    var oarGripDiameterPort: Double // mm (e.g. 34.0)
    var oarGripDiameterStarboard: Double
    
    // Boat measurements
    var boatSpan: Double // cm (e.g. 160)
    var boatWorkHeightPort: Double // cm (e.g. 16.5)
    var boatWorkHeightStarboard: Double
    var boatPitchPort: Double // degrees (e.g. 4.0, sternward pitch)
    var boatPitchStarboard: Double
    var boatLateralPitchPort: String // Concept2 oarlock bushing (e.g. "4/4", "6/2")
    var boatLateralPitchStarboard: String
    var boatFootstretch: Double // cm (e.g. 8.0)
    var boatFootplateAngle: Double // degrees (e.g. 42.0)
    var boatFootplateHeight: Double // cm (e.g. 15.0, heels below seat)
    var boatSeatPosition: Double // cm (e.g. 28.0, distance of seat behind pin)
    
    var oarOutboardPort: Double {
        return max(0, oarTotalLengthPort - oarInboardPort)
    }
    
    var oarOutboardStarboard: Double {
        return max(0, oarTotalLengthStarboard - oarInboardStarboard)
    }
    
    init(
        id: UUID = UUID(),
        name: String = "",
        date: Date = Date(),
        boatType: BoatType = .singleSculls,
        oarType: OarType = .scull,
        oarTotalLengthPort: Double = 289.0,
        oarTotalLengthStarboard: Double = 289.0,
        oarInboardPort: Double = 88.0,
        oarInboardStarboard: Double = 88.0,
        oarBladeType: String = "Smoothie2",
        oarSleevePitchPort: Double = 0.0,
        oarSleevePitchStarboard: Double = 0.0,
        oarGripDiameterPort: Double = 34.0,
        oarGripDiameterStarboard: Double = 34.0,
        boatSpan: Double = 160.0,
        boatWorkHeightPort: Double = 16.0,
        boatWorkHeightStarboard: Double = 16.0,
        boatPitchPort: Double = 4.0,
        boatPitchStarboard: Double = 4.0,
        boatLateralPitchPort: String = "4/4",
        boatLateralPitchStarboard: String = "4/4",
        boatFootstretch: Double = 8.0,
        boatFootplateAngle: Double = 42.0,
        boatFootplateHeight: Double = 15.0,
        boatSeatPosition: Double = 28.0
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.boatType = boatType
        self.oarType = oarType
        self.oarTotalLengthPort = oarTotalLengthPort
        self.oarTotalLengthStarboard = oarTotalLengthStarboard
        self.oarInboardPort = oarInboardPort
        self.oarInboardStarboard = oarInboardStarboard
        self.oarBladeType = oarBladeType
        self.oarSleevePitchPort = oarSleevePitchPort
        self.oarSleevePitchStarboard = oarSleevePitchStarboard
        self.oarGripDiameterPort = oarGripDiameterPort
        self.oarGripDiameterStarboard = oarGripDiameterStarboard
        self.boatSpan = boatSpan
        self.boatWorkHeightPort = boatWorkHeightPort
        self.boatWorkHeightStarboard = boatWorkHeightStarboard
        self.boatPitchPort = boatPitchPort
        self.boatPitchStarboard = boatPitchStarboard
        self.boatLateralPitchPort = boatLateralPitchPort
        self.boatLateralPitchStarboard = boatLateralPitchStarboard
        self.boatFootstretch = boatFootstretch
        self.boatFootplateAngle = boatFootplateAngle
        self.boatFootplateHeight = boatFootplateHeight
        self.boatSeatPosition = boatSeatPosition
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, date, boatType, oarType, oarBladeType
        case boatSpan, boatFootstretch, boatFootplateAngle, boatFootplateHeight, boatSeatPosition
        
        // New keys corresponding directly to stored properties
        case oarTotalLengthPort, oarTotalLengthStarboard
        case oarInboardPort, oarInboardStarboard
        case oarSleevePitchPort, oarSleevePitchStarboard
        case oarGripDiameterPort, oarGripDiameterStarboard
        case boatWorkHeightPort, boatWorkHeightStarboard
        case boatPitchPort, boatPitchStarboard
        case boatLateralPitchPort, boatLateralPitchStarboard
    }
    
    enum LegacyCodingKeys: String, CodingKey {
        case oarTotalLength, oarInboard, oarSleevePitch, oarGripDiameter
        case boatWorkHeight, boatPitch, boatLateralPitch
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        boatType = try container.decode(BoatType.self, forKey: .boatType)
        oarType = try container.decode(OarType.self, forKey: .oarType)
        oarBladeType = try container.decode(String.self, forKey: .oarBladeType)
        
        boatSpan = try container.decode(Double.self, forKey: .boatSpan)
        boatFootstretch = try container.decode(Double.self, forKey: .boatFootstretch)
        boatFootplateAngle = try container.decodeIfPresent(Double.self, forKey: .boatFootplateAngle) ?? 42.0
        boatFootplateHeight = try container.decodeIfPresent(Double.self, forKey: .boatFootplateHeight) ?? 15.0
        boatSeatPosition = try container.decodeIfPresent(Double.self, forKey: .boatSeatPosition) ?? 28.0
        
        // Decode Oar Total Length
        if let val = try container.decodeIfPresent(Double.self, forKey: .oarTotalLengthPort) {
            oarTotalLengthPort = val
            oarTotalLengthStarboard = try container.decodeIfPresent(Double.self, forKey: .oarTotalLengthStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .oarTotalLength) ?? (boatType.isScull ? 289.0 : 373.0)
            oarTotalLengthPort = oldVal
            oarTotalLengthStarboard = oldVal
        }
        
        // Decode Oar Inboard
        if let val = try container.decodeIfPresent(Double.self, forKey: .oarInboardPort) {
            oarInboardPort = val
            oarInboardStarboard = try container.decodeIfPresent(Double.self, forKey: .oarInboardStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .oarInboard) ?? (boatType.isScull ? 88.0 : 114.0)
            oarInboardPort = oldVal
            oarInboardStarboard = oldVal
        }
        
        // Decode Sleeve Pitch
        if let val = try container.decodeIfPresent(Double.self, forKey: .oarSleevePitchPort) {
            oarSleevePitchPort = val
            oarSleevePitchStarboard = try container.decodeIfPresent(Double.self, forKey: .oarSleevePitchStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .oarSleevePitch) ?? 0.0
            oarSleevePitchPort = oldVal
            oarSleevePitchStarboard = oldVal
        }
        
        // Decode Grip Diameter
        if let val = try container.decodeIfPresent(Double.self, forKey: .oarGripDiameterPort) {
            oarGripDiameterPort = val
            oarGripDiameterStarboard = try container.decodeIfPresent(Double.self, forKey: .oarGripDiameterStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .oarGripDiameter) ?? 34.0
            oarGripDiameterPort = oldVal
            oarGripDiameterStarboard = oldVal
        }
        
        // Decode Work Height
        if let val = try container.decodeIfPresent(Double.self, forKey: .boatWorkHeightPort) {
            boatWorkHeightPort = val
            boatWorkHeightStarboard = try container.decodeIfPresent(Double.self, forKey: .boatWorkHeightStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .boatWorkHeight) ?? 16.0
            boatWorkHeightPort = oldVal
            boatWorkHeightStarboard = oldVal
        }
        
        // Decode Pitch
        if let val = try container.decodeIfPresent(Double.self, forKey: .boatPitchPort) {
            boatPitchPort = val
            boatPitchStarboard = try container.decodeIfPresent(Double.self, forKey: .boatPitchStarboard) ?? val
        } else {
            let oldVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .boatPitch) ?? 4.0
            boatPitchPort = oldVal
            boatPitchStarboard = oldVal
        }
        
        // Decode Lateral Pitch
        if let val = try container.decodeIfPresent(String.self, forKey: .boatLateralPitchPort) {
            boatLateralPitchPort = val
            boatLateralPitchStarboard = try container.decodeIfPresent(String.self, forKey: .boatLateralPitchStarboard) ?? val
        } else {
            let oldVal: String
            if let stringVal = try legacyContainer?.decodeIfPresent(String.self, forKey: .boatLateralPitch) {
                oldVal = stringVal
            } else if let doubleVal = try legacyContainer?.decodeIfPresent(Double.self, forKey: .boatLateralPitch) {
                if doubleVal == 4.4 { oldVal = "4/4" }
                else if doubleVal == 5.3 { oldVal = "5/3" }
                else if doubleVal == 6.2 { oldVal = "6/2" }
                else if doubleVal == 7.1 { oldVal = "7/1" }
                else { oldVal = String(format: "%.1f", doubleVal) }
            } else {
                oldVal = "4/4"
            }
            boatLateralPitchPort = oldVal
            boatLateralPitchStarboard = oldVal
        }
    }
    
    var isUnchangedFromDefault: Bool {
        let isScull = boatType.isScull
        let defaultOarTotalLength = isScull ? 289.0 : 373.0
        let defaultOarInboard = isScull ? 88.0 : 114.0
        let defaultBoatSpan = isScull ? 160.0 : 84.0
        
        let hasMeasurementChanges = 
            oarTotalLengthPort != defaultOarTotalLength ||
            oarTotalLengthStarboard != defaultOarTotalLength ||
            oarInboardPort != defaultOarInboard ||
            oarInboardStarboard != defaultOarInboard ||
            oarBladeType != "Smoothie2" ||
            oarSleevePitchPort != 0.0 ||
            oarSleevePitchStarboard != 0.0 ||
            oarGripDiameterPort != 34.0 ||
            oarGripDiameterStarboard != 34.0 ||
            boatSpan != defaultBoatSpan ||
            boatWorkHeightPort != 16.0 ||
            boatWorkHeightStarboard != 16.0 ||
            boatPitchPort != 4.0 ||
            boatPitchStarboard != 4.0 ||
            boatLateralPitchPort != "4/4" ||
            boatLateralPitchStarboard != "4/4" ||
            boatFootstretch != 8.0 ||
            boatFootplateAngle != 42.0 ||
            boatFootplateHeight != 15.0 ||
            boatSeatPosition != 28.0
            
        if hasMeasurementChanges {
            return false
        }
        
        // Check if name matches any defaults
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName1 = "Single Scull Default".localized
        let defaultName2 = "Single Scull Default"
        let defaultName3 = "\(boatType.displayName) Setup"
        
        return trimmedName.isEmpty || 
               trimmedName == defaultName1 || 
               trimmedName == defaultName2 || 
               trimmedName == defaultName3
    }
}
