import Foundation
import CoreLocation

/// 潮位観測地点モデル
struct TideStation: Identifiable, Equatable {
    let id: String         // 地点記号 (例: "TK")
    let name: String       // 地点名 (例: "東京")
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: TideStation, rhs: TideStation) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 毎時の潮位データ
struct HourlyTideLevel: Identifiable {
    let id = UUID()
    let hour: Int
    let level: Int // cm
}

/// 1日分の潮汐データ
struct TideData: Identifiable {
    let id = UUID()
    let station: TideStation
    let date: Date
    let hourlyLevels: [HourlyTideLevel]
    let highTides: [(time: String, level: Int)] // 満潮 (時刻文字列, 水位)
    let lowTides: [(time: String, level: Int)]  // 干潮 (時刻文字列, 水位)
    let tideType: String   // 潮名 (例: "大潮")
}
