import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let updateInterval = MotionConstants.sensorUpdateInterval
    private var strokeTimestamps: [Date] = []

    @Published var spm: Int = 0 // strokes per minute

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("加速度センサーが利用できません")
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            // ユーザー設定から感度を取得
            let savedSettings = UserSettings.load()
            let threshold = savedSettings.accelerationThreshold
            
            if abs(data.acceleration.y) > threshold {
                self.registerStroke()
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        // データはreset()でのみクリアする（記録保存のため）
    }

    private func registerStroke() {
        let now = Date()

        // ダブルカウント防止（0.8秒未満の再検出は無視）
        if let last = strokeTimestamps.last, now.timeIntervalSince(last) < 0.8 {
            return
        }

        strokeTimestamps.append(now)

        // 直近2〜3ストロークの平均間隔からSPMを計算
        if strokeTimestamps.count >= 2 {
            let recentStrokes = Array(strokeTimestamps.suffix(min(3, strokeTimestamps.count)))
            
            // 各ストローク間の間隔を計算
            var intervals: [TimeInterval] = []
            for i in 1..<recentStrokes.count {
                let interval = recentStrokes[i].timeIntervalSince(recentStrokes[i-1])
                intervals.append(interval)
            }
            
            // 平均間隔を計算
            if !intervals.isEmpty {
                let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
                // 1分間あたりのストローク数に変換
                spm = Int(60.0 / averageInterval)
            }
        }

        // 古いデータを削除（30秒以上前）
        let cutoff = now.addingTimeInterval(-30)
        strokeTimestamps = strokeTimestamps.filter { $0 >= cutoff }
    }
    func reset() {
        strokeTimestamps.removeAll()
        spm = 0
    }
}
