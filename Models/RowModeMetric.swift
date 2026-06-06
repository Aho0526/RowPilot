import Foundation

enum RowModeMetric: String, Codable, CaseIterable, Identifiable {
    case chrono
    case distance
    case averagePace
    case strokeCount
    case distPerStroke
    
    var id: String { self.rawValue }
    
    var label: String {
        switch self {
        case .chrono:
            return "Time".localized
        case .distance:
            return "Distance_M".localized
        case .averagePace:
            return "Avg Pace".localized
        case .strokeCount:
            return "Stroke Count".localized
        case .distPerStroke:
            return "Dist/Stroke".localized
        }
    }
}
