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
    var routePoints: [LocationData]?
    
    // メモ・タグ
    var notes: String?
    var tags: [String]? // 例: ["朝練", "2000m", "レース準備"]
    
    // マネージャーモード
    var isManagerMode: Bool = false
    var managerSessionId: UUID?
    var pm5SerialNumber: String?
    var pm5CustomName: String?
    var averageWatt: Int?
    
    // 詳細データ（グラフ用）
    var dataPoints: [WorkoutDataPoint]?
    
    // クルー情報
    var crewInfo: CrewInfo?
    
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
        tags: [String]? = nil,
        isManagerMode: Bool = false,
        managerSessionId: UUID? = nil,
        pm5SerialNumber: String? = nil,
        pm5CustomName: String? = nil,
        averageWatt: Int? = nil,
        dataPoints: [WorkoutDataPoint]? = nil,
        crewInfo: CrewInfo? = nil,
        routePoints: [LocationData]? = nil
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
        self.isManagerMode = isManagerMode
        self.managerSessionId = managerSessionId
        self.pm5SerialNumber = pm5SerialNumber
        self.pm5CustomName = pm5CustomName
        self.averageWatt = averageWatt
        self.dataPoints = dataPoints
        self.crewInfo = crewInfo
        self.routePoints = routePoints
    }
}

/// 位置情報データ
struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    var isPostGap: Bool? = nil
    
    init(latitude: Double, longitude: Double, isPostGap: Bool? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.isPostGap = isPostGap
    }
}

// MARK: - Computed Properties
extension RowingRecord {
    var isDistanceWorkout: Bool {
        if let tags = tags, tags.contains("distance") {
            return true
        }
        if let notes = notes, notes.localizedCaseInsensitiveContains("Type: distance") {
            return true
        }
        return false
    }

    /// フォーマットされた時間 (HH:MM:SS.S または MM:SS.S)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10) // 小数点第1位まで
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%01d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
        }
    }
    
    /// フォーマットされた距離 (m)
    var formattedDistance: String {
        return String(format: "%.0f m", distance)
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

// MARK: - Hashable & Equatable
extension RowingRecord: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RowingRecord, rhs: RowingRecord) -> Bool {
        lhs.id == rhs.id
    }
}
