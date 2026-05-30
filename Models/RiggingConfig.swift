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
    var oarTotalLength: Double // cm (e.g. 289)
    var oarInboard: Double // cm (e.g. 88)
    var oarBladeType: String // e.g. "Smoothie2 Plain"
    var oarSleevePitch: Double // degrees (e.g. 0.0 or 4.0)
    var oarGripDiameter: Double // mm (e.g. 34.0)
    
    // Boat measurements
    var boatSpan: Double // cm (e.g. 160)
    var boatWorkHeight: Double // cm (e.g. 16.5)
    var boatPitch: Double // degrees (e.g. 4.0, sternward pitch)
    var boatLateralPitch: String // Concept2 oarlock bushing (e.g. "4/4", "6/2")
    var boatFootstretch: Double // cm (e.g. 8.0)
    var boatFootplateAngle: Double // degrees (e.g. 42.0)
    var boatFootplateHeight: Double // cm (e.g. 15.0, heels below seat)
    var boatSeatPosition: Double // cm (e.g. 28.0, distance of seat behind pin)
    
    var oarOutboard: Double {
        return max(0, oarTotalLength - oarInboard)
    }
    
    init(
        id: UUID = UUID(),
        name: String = "",
        date: Date = Date(),
        boatType: BoatType = .singleSculls,
        oarType: OarType = .scull,
        oarTotalLength: Double = 289.0,
        oarInboard: Double = 88.0,
        oarBladeType: String = "Smoothie2",
        oarSleevePitch: Double = 0.0,
        oarGripDiameter: Double = 34.0,
        boatSpan: Double = 160.0,
        boatWorkHeight: Double = 16.0,
        boatPitch: Double = 4.0,
        boatLateralPitch: String = "4/4",
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
        self.oarTotalLength = oarTotalLength
        self.oarInboard = oarInboard
        self.oarBladeType = oarBladeType
        self.oarSleevePitch = oarSleevePitch
        self.oarGripDiameter = oarGripDiameter
        self.boatSpan = boatSpan
        self.boatWorkHeight = boatWorkHeight
        self.boatPitch = boatPitch
        self.boatLateralPitch = boatLateralPitch
        self.boatFootstretch = boatFootstretch
        self.boatFootplateAngle = boatFootplateAngle
        self.boatFootplateHeight = boatFootplateHeight
        self.boatSeatPosition = boatSeatPosition
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, date, boatType, oarType, oarTotalLength, oarInboard, oarBladeType, oarSleevePitch, oarGripDiameter
        case boatSpan, boatWorkHeight, boatPitch, boatLateralPitch, boatFootstretch, boatFootplateAngle, boatFootplateHeight, boatSeatPosition
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        boatType = try container.decode(BoatType.self, forKey: .boatType)
        oarType = try container.decode(OarType.self, forKey: .oarType)
        oarTotalLength = try container.decode(Double.self, forKey: .oarTotalLength)
        oarInboard = try container.decode(Double.self, forKey: .oarInboard)
        oarBladeType = try container.decode(String.self, forKey: .oarBladeType)
        oarSleevePitch = try container.decodeIfPresent(Double.self, forKey: .oarSleevePitch) ?? 0.0
        oarGripDiameter = try container.decodeIfPresent(Double.self, forKey: .oarGripDiameter) ?? 34.0
        boatSpan = try container.decode(Double.self, forKey: .boatSpan)
        boatWorkHeight = try container.decode(Double.self, forKey: .boatWorkHeight)
        boatPitch = try container.decode(Double.self, forKey: .boatPitch)
        boatFootstretch = try container.decode(Double.self, forKey: .boatFootstretch)
        boatFootplateAngle = try container.decodeIfPresent(Double.self, forKey: .boatFootplateAngle) ?? 42.0
        boatFootplateHeight = try container.decodeIfPresent(Double.self, forKey: .boatFootplateHeight) ?? 15.0
        boatSeatPosition = try container.decodeIfPresent(Double.self, forKey: .boatSeatPosition) ?? 28.0
        
        if let stringVal = try? container.decode(String.self, forKey: .boatLateralPitch) {
            boatLateralPitch = stringVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .boatLateralPitch) {
            if doubleVal == 4.4 { boatLateralPitch = "4/4" }
            else if doubleVal == 5.3 { boatLateralPitch = "5/3" }
            else if doubleVal == 6.2 { boatLateralPitch = "6/2" }
            else if doubleVal == 7.1 { boatLateralPitch = "7/1" }
            else { boatLateralPitch = String(format: "%.1f", doubleVal) }
        } else {
            boatLateralPitch = "4/4"
        }
    }
}
