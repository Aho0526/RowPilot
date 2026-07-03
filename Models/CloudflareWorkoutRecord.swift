import Foundation

struct CloudflareWorkoutRecord: Identifiable, Codable, Equatable {
    var id: String
    var athlete_id: String
    var recorded_by_id: String
    var team_id: String
    var type: String
    var format: String
    var distance_m: Int?
    var duration_sec: Int?
    var split_500m_sec: Int?
    var stroke_rate: Int?
    var boat_type: String?
    var recorded_on: String
    var created_at: String
    var athlete_name: String? // JOINで取得した表示名
    var crew_info: String? // クルー情報 (JSON)

    var recordedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: recorded_on) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: recorded_on)
    }
    
    var formattedDuration: String {
        guard let duration = duration_sec else { return "--:--" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDistance: String {
        guard let distance = distance_m else { return "-- m" }
        if distance >= 1000 {
            return String(format: "%.1f km", Double(distance) / 1000)
        } else {
            return String(format: "%d m", distance)
        }
    }
    
    var formattedSplit: String {
        guard let split = split_500m_sec else { return "--:-- /500m" }
        let minutes = split / 60
        let seconds = split % 60
        return String(format: "%d:%02d /500m", minutes, seconds)
    }
    
    // MARK: - Format Helpers for List
    
    var workoutSummary: String {
        switch format.lowercased() {
        case "time":
            if let duration = duration_sec {
                let mins = duration / 60
                return "\(mins)min"
            }
            return "Time"
        case "distance":
            if let distance = distance_m {
                return "\(distance)m"
            }
            return "Distance"
        case "interval":
            return "interval"
        default:
            return format
        }
    }
    
    var formattedDurationShort: String {
        guard let duration = duration_sec else { return "--:--" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedSplitShort: String {
        guard let split = split_500m_sec else { return "-" }
        let minutes = split / 60
        let seconds = split % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var recordSummaryText: String {
        let dist = distance_m.map { "\($0)m" } ?? "--m"
        let dur = formattedDurationShort
        let split = format.lowercased() == "interval" ? "-" : formattedSplitShort
        return "\(dist)/\(dur)/\(split)"
    }
}
