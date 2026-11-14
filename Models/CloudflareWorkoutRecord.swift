import Foundation

struct CloudflareWorkoutRecord: Identifiable, Codable, Equatable {
    var id: String
    var athlete_id: String
    var recorded_by_id: String
    var team_id: String
    var type: String
    var format: String
    var distance_m: Double?
    var duration_sec: Double?
    var split_500m_sec: Double?
    var stroke_rate: Double?
    var boat_type: String?
    var recorded_on: String
    var created_at: String
    var athlete_name: String? // JOINで取得した表示名
    var crew_info: String? // クルー情報 (JSON)
    var average_watt: Double?
    var notes: String?
    var calories: Double?
    var is_manager_mode: Int?
    var summary_json: String?

    var isManagerModeRecord: Bool {
        (is_manager_mode ?? 0) != 0
    }

    var recordedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: recorded_on) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: recorded_on)
    }
    
    var formattedDuration: String {
        guard let duration = duration_sec else { return "--:--" }
        let totalTenths = max(0, Int((duration * 10).rounded()))
        let hours = totalTenths / 36000
        let minutes = (totalTenths % 36000) / 600
        let seconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        } else {
            return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
        }
    }
    
    var formattedDistance: String {
        let unit = SettingsManager.shared.settings.distanceUnit
        guard let distance = distance_m else { return "-- \(unit.shortLabel)" }
        switch unit {
        case .meters:
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000.0)
            } else if abs(distance.rounded() - distance) > 0.05 {
                return String(format: "%.1f m", distance)
            } else {
                return String(format: "%d m", Int(distance.rounded()))
            }
        case .kilometers, .miles:
            return unit.format(distance)
        }
    }
    
    var formattedSplit: String {
        guard let split = split_500m_sec, split > 0 else { return "--:--.- /500m" }
        let totalTenths = max(0, Int((split * 10).rounded()))
        let minutes = totalTenths / 600
        let seconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10
        return String(format: "%d:%02d.%d /500m", minutes, seconds, tenths)
    }
    
    // MARK: - Format Helpers for List
    
    var workoutSummary: String {
        switch format.lowercased() {
        case "time":
            if let duration = duration_sec {
                let mins = Int((duration / 60.0).rounded())
                return "\(mins)min"
            }
            return "Time"
        case "distance":
            if let distance = distance_m {
                return "\(Int(distance.rounded()))m"
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
        let totalTenths = max(0, Int((duration * 10).rounded()))
        let hours = totalTenths / 36000
        let minutes = (totalTenths % 36000) / 600
        let seconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        } else {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        }
    }
    
    var formattedSplitShort: String {
        guard let split = split_500m_sec, split > 0 else { return "-" }
        let totalTenths = max(0, Int((split * 10).rounded()))
        let minutes = totalTenths / 600
        let seconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
    
    var recordSummaryText: String {
        let dist = distance_m.map { "\(Int($0.rounded()))m" } ?? "--m"
        let dur = formattedDurationShort
        let split = format.lowercased() == "interval" ? "-" : formattedSplitShort
        return "\(dist)/\(dur)/\(split)"
    }
}
