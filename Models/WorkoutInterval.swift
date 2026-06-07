import Foundation

// MARK: - Variable Interval Entry Model
/// Variable Intervalの1インターバル設定
struct VariableIntervalEntry: Identifiable, Equatable {
    let id = UUID()
    var distanceMeters: Int?    // 距離インターバル (m)
    var timeSeconds: Int?       // 時間インターバル (秒)
    var calories: Int?          // カロリーインターバル (cal)
    var restSeconds: Int        // 休憩時間 (秒, Max 9:55 = 595)
    var targetPace500mSeconds: Int? // ターゲットペース (秒/500m), nilで無設定
    
    static func distanceEntry(meters: Int, rest: Int, pace: Int? = nil) -> VariableIntervalEntry {
        VariableIntervalEntry(distanceMeters: meters, timeSeconds: nil, calories: nil, restSeconds: min(rest, 595), targetPace500mSeconds: pace)
    }
    
    static func timeEntry(seconds: Int, rest: Int, pace: Int? = nil) -> VariableIntervalEntry {
        VariableIntervalEntry(distanceMeters: nil, timeSeconds: seconds, calories: nil, restSeconds: min(rest, 595), targetPace500mSeconds: pace)
    }
    
    static func caloriesEntry(calories: Int, rest: Int, pace: Int? = nil) -> VariableIntervalEntry {
        VariableIntervalEntry(distanceMeters: nil, timeSeconds: nil, calories: calories, restSeconds: min(rest, 595), targetPace500mSeconds: pace)
    }
}
