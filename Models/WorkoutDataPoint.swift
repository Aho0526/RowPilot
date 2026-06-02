import Foundation

/// ワークアウト中の時系列データポイント
struct WorkoutDataPoint: Identifiable, Codable {
    let id: UUID
    let timeOffset: TimeInterval // ワークアウト開始からの経過秒数
    let pace: TimeInterval // 500mあたりのペース (秒)
    let spm: Int // ストロークレート (Strokes per minute)
    let power: Int // ワット数
    let distance: Double? // 到達距離 (累積メートル数)
    
    init(id: UUID = UUID(), timeOffset: TimeInterval, pace: TimeInterval, spm: Int, power: Int, distance: Double? = nil) {
        self.id = id
        self.timeOffset = timeOffset
        self.pace = pace
        self.spm = spm
        self.power = power
        self.distance = distance
    }
}
