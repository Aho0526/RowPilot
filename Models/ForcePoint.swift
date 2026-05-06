import Foundation

/// 1ストローク中の特定時刻におけるフォース(lbf)を表す構造体
struct ForcePoint: Identifiable {
    let id = UUID()
    let timeRaw: Double // 時間 (秒)
    let forceLbf: Int   // 力 (ポンド力)
}
