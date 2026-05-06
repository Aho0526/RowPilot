import Foundation

/// ローイング練習の記録を保持する構造体
struct RowingRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    
    // 計測データ
    let duration: TimeInterval // 秒
    let distance: Double // メートル
    let averageSPM: Int // 平均Strokes Per Minute
    let averageSpeed: Double // 平均速度 (km/h)
    let averagePace: TimeInterval // 500mあたりの平均ペース (秒)
    
    // 位置情報
    let startLocation: LocationData?
    let endLocation: LocationData?
    
    // メモ・タグ
    var notes: String?
    var tags: [String]? // 例: ["朝練", "2000m", "レース準備"]
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        distance: Double,
        averageSPM: Int,
        averageSpeed: Double,
        averagePace: TimeInterval,
        startLocation: LocationData? = nil,
        endLocation: LocationData? = nil,
        notes: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.distance = distance
        self.averageSPM = averageSPM
        self.averageSpeed = averageSpeed
        self.averagePace = averagePace
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.notes = notes
        self.tags = tags
    }
}

/// 位置情報データ
struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Computed Properties
extension RowingRecord {
    /// フォーマットされた時間 (HH:MM:SS)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// フォーマットされた距離 (km)
    var formattedDistance: String {
        let km = distance / 1000.0
        return String(format: "%.2f km", km)
    }
    
    /// フォーマットされたペース (MM:SS /500m)
    var formattedPace: String {
        let totalSeconds = Int(averagePace)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /500m", minutes, seconds)
    }
    
    /// フォーマットされた日付
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
