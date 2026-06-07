import Foundation
import CoreMotion

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let updateInterval = MotionConstants.sensorUpdateInterval
    private var strokeTimestamps: [Date] = []

    // ローパスフィルタおよびピーク検出用の変数
    private var filteredAccelerationY: Double = 0.0
    private var previousFilteredY: Double = 0.0
    private let filterFactor: Double = 0.25 // EMAフィルタ係数
    private var isPeakDetectedInCurrentWindow: Bool = false
    private var strokePolarity: Double = 0.0 // ストローク（キャッチ）時の加速度極性（+1.0 または -1.0）

    @Published var spm: Int = 0 // strokes per minute
    @Published var strokeCount: Int = 0

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
            
            // ローパスフィルタ（EMA）を適用してノイズを除去
            let rawY = data.acceleration.y
            self.previousFilteredY = self.filteredAccelerationY
            self.filteredAccelerationY = self.filterFactor * rawY + (1.0 - self.filterFactor) * self.filteredAccelerationY
            
            let currentVal = self.filteredAccelerationY
            let currentAbs = abs(currentVal)
            
            if currentAbs > threshold {
                // 初回の閾値超過時に、キャッチの加速度極性を自動決定
                if self.strokePolarity == 0.0 {
                    self.strokePolarity = currentVal >= 0 ? 1.0 : -1.0
                }
                
                // 決定された極性方向の加速度値のみを対象にする
                let polarizedVal = currentVal * self.strokePolarity
                let previousPolarizedVal = self.previousFilteredY * self.strokePolarity
                
                // 極性方向の加速度が閾値を超えており、かつ減少に転じた（ピークを迎えた）瞬間を判定
                if polarizedVal > threshold {
                    if previousPolarizedVal > threshold && polarizedVal < previousPolarizedVal {
                        if !self.isPeakDetectedInCurrentWindow {
                            // 直前のサンプリングタイミング（約updateInterval秒前）をピーク発生時刻とする
                            let peakTime = Date().addingTimeInterval(-self.updateInterval)
                            self.registerStroke(at: peakTime)
                            self.isPeakDetectedInCurrentWindow = true
                        }
                    }
                }
            } else {
                // 閾値を下回ったら、次のピークを検出できるようにリセット
                self.isPeakDetectedInCurrentWindow = false
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        // データはreset()でのみクリアする（記録保存のため）
    }

    private func registerStroke(at peakTime: Date) {
        // 動的なデバウンス時間を現在のSPMに基づいて決定（低レート時のキャッチ/フィニッシュ2重カウント防止）
        let debounceInterval: TimeInterval
        if self.spm > 0 {
            let strokePeriod = 60.0 / Double(self.spm)
            // 周期の55%をデバウンス窓とする（例: 20spmなら1.65秒、40spmなら0.825秒）
            // 上限は2.0秒、下限は高レート対策として0.5秒にする
            debounceInterval = max(0.5, min(strokePeriod * 0.55, 2.0))
        } else {
            // 初回やリセット直後は Constants で定義されたデフォルト値を使用
            debounceInterval = MotionConstants.strokeDebounceInterval
        }

        // ダブルカウント防止
        if let last = strokeTimestamps.last, peakTime.timeIntervalSince(last) < debounceInterval {
            return
        }

        strokeTimestamps.append(peakTime)
        strokeCount += 1

        // 直近5ストローク（間隔4つ）の平均間隔からSPMを計算
        if strokeTimestamps.count >= 2 {
            let maxSamples = 5
            let recentStrokes = Array(strokeTimestamps.suffix(min(maxSamples, strokeTimestamps.count)))
            
            // 各ストローク間の間隔を計算
            var intervals: [TimeInterval] = []
            for i in 1..<recentStrokes.count {
                let interval = recentStrokes[i].timeIntervalSince(recentStrokes[i-1])
                // 誤差や極端なズレを排除するため、ボートのストロークとして現実的な範囲（0.6秒〜6.0秒）に制限
                if interval >= 0.6 && interval <= 6.0 {
                    intervals.append(interval)
                }
            }
            
            // 平均間隔を計算してSPMを算出
            if !intervals.isEmpty {
                let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
                let rawSpm = 60.0 / averageInterval
                
                // 表示上の急激なブレを抑えるため、指数平滑化（EMA）と四捨五入（round）を適用
                if self.spm == 0 {
                    self.spm = Int(round(rawSpm))
                } else {
                    let smoothSpm = 0.4 * rawSpm + 0.6 * Double(self.spm)
                    self.spm = Int(round(smoothSpm))
                }
            }
        }

        // 古いデータを削除（30秒以上前）
        let cutoff = peakTime.addingTimeInterval(-30)
        strokeTimestamps = strokeTimestamps.filter { $0 >= cutoff }
    }

    func reset() {
        strokeTimestamps.removeAll()
        spm = 0
        strokeCount = 0
        filteredAccelerationY = 0.0
        previousFilteredY = 0.0
        isPeakDetectedInCurrentWindow = false
        strokePolarity = 0.0
    }
}
