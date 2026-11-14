import Foundation
import CoreMotion

/// # ストロークレート検出アルゴリズム
///
/// ## 参考・ソース
/// - CrewNerd (performancephones.com): 船体の水平加速度の特性パターンを監視してキャッチを検出
/// - NK SpeedCoach: キャッチ（リカバリー→ドライブの遷移）の「負のピーク（最小値）」を識別
/// - 学術研究 (Rowing In Motion / RUG): ローパスフィルタ後のゼロクロッシングを使ってキャッチ/フィニッシュを分類
/// - Open Rowing Monitor (github.com/laberning/openrowingmonitor): 有限状態機械でドライブ/リカバリーフェーズを管理
///
/// ## 検出方式
/// ボートの進行方向加速度は「ドライブ時に正（加速）、リカバリー時に負（減速）」のパターンを示す。
/// キャッチ（ストロークの開始点）は加速度が「谷（負のピーク）を過ぎてゼロクロッシング（負→正）する瞬間」に相当。
/// これを「負のピーク検出 → ゼロクロッシングでストロークとして確定」の2段階で捉える。
/// (参考: NK SpeedCoach, CrewNerd, and rowing biomechanics research - RUG.nl)
///
/// ## SPM計算
/// 直近3ストロークの間隔の中央値を使用 (Rowing in Motion 方式)
/// 個々のストローク間隔から即時換算 + 移動平均で安定化
///
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let updateInterval = MotionConstants.sensorUpdateInterval  // 0.02秒 = 50Hz

    // MARK: - ストロークタイムスタンプ履歴
    private var strokeTimestamps: [Date] = []
    private var spmSamples: [Int] = []

    // MARK: - 2次Butterworthローパスフィルタ (カットオフ約3Hz@50Hz)
    private struct AxisFilterState {
        var x1: Double = 0.0
        var x2: Double = 0.0
        var y1: Double = 0.0
        var y2: Double = 0.0
        var cur: Double = 0.0
        var prev: Double = 0.0
        
        mutating func apply(raw: Double, b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) -> (prev: Double, cur: Double) {
            let y = b0 * raw + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = raw
            y2 = y1
            y1 = y
            prev = cur
            cur = y
            return (prev, cur)
        }
    }
    
    // X, Y, Z 各軸に独立したフィルタ状態を保持 (M-7)
    private var axisFilters: [AxisFilterState] = [AxisFilterState(), AxisFilterState(), AxisFilterState()]
    private var activeAxisIndex: Int = 1
    private var varianceX: Double = 0.0
    private var varianceY: Double = 0.0
    private var varianceZ: Double = 0.0
    
    // 2次Butterworth, fc=3Hz, fs=50Hz の係数 (bilinear transform)
    private let bwB0: Double = 0.02008337
    private let bwB1: Double = 0.04016673
    private let bwB2: Double = 0.02008337
    private let bwA1: Double = -1.56101808
    private let bwA2: Double =  0.64135154

    // MARK: - 負ピーク検出用（キャッチ候補の谷を探す）
    // NK SpeedCoach / CrewNerd 方式:
    //   ① 加速度がキャッチ閾値を下回る（谷に入る）
    //   ② 谷の最小値を追跡
    //   ③ 谷から浮上し、ゼロラインを上回った瞬間をキャッチとして確定
    private enum StrokePhase {
        case idle       // 閾値内 (静止 or リカバリー初期)
        case inTrough   // 負の谷の中（キャッチ候補を探している）
        case inDrive    // ドライブ中（正の加速度域）、ゼロクロッシング解除待ち
    }
    private var strokePhase: StrokePhase = .idle
    private var troughMinValue: Double = 0.0  // 谷の最小値（最も負の値）
    private var troughTimestamp: Date = Date() // 谷の最小値が現れた時刻
    private var strokePolarity: Double = 0.0  // ストローク（キャッチ）時の加速度極性（+1.0 または -1.0）
    private var polarityCandidateSign: Double = 0.0
    private var polarityCandidateStreak: Int = 0
    private var polaritySetAt: Date? = nil
    private var isPolarityConfirmed: Bool = false

    // MARK: - 固定のキャッチ感度閾値
    private let fixedThreshold: Double = 0.06
    private let spmInactivityTimeout: TimeInterval = 6.5

    @Published var spm: Int = 0
    @Published var strokeCount: Int = 0
    var onStrokeDetected: (() -> Void)?

    /// セッション中の有効なSPMサンプルの平均値
    var averageSPM: Int {
        guard !spmSamples.isEmpty else { return spm }
        let total = spmSamples.reduce(0, +)
        return Int(round(Double(total) / Double(spmSamples.count)))
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("加速度センサーが利用できません")
            return
        }

        // 起動時に極性・分散・フィルタ状態を初期化
        strokePolarity = 0.0
        polarityCandidateSign = 0.0
        polarityCandidateStreak = 0
        polaritySetAt = nil
        isPolarityConfirmed = false
        varianceX = 0.0
        varianceY = 0.0
        varianceZ = 0.0

        let alpha = 0.01 // 50Hzで約2秒の時定数

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            let ax = motion.userAcceleration.x
            let ay = motion.userAcceleration.y
            let az = motion.userAcceleration.z
            
            // 全軸を独立したButterworthフィルタで常時平滑化 (M-7)
            let fx = self.axisFilters[0].apply(raw: ax, b0: self.bwB0, b1: self.bwB1, b2: self.bwB2, a1: self.bwA1, a2: self.bwA2)
            let fy = self.axisFilters[1].apply(raw: ay, b0: self.bwB0, b1: self.bwB1, b2: self.bwB2, a1: self.bwA1, a2: self.bwA2)
            let fz = self.axisFilters[2].apply(raw: az, b0: self.bwB0, b1: self.bwB1, b2: self.bwB2, a1: self.bwA1, a2: self.bwA2)
            let filteredAxes = [fx, fy, fz]
            
            // 各軸の振幅の指数移動平均を更新
            self.varianceX = self.varianceX * (1 - alpha) + abs(ax) * alpha
            self.varianceY = self.varianceY * (1 - alpha) + abs(ay) * alpha
            self.varianceZ = self.varianceZ * (1 - alpha) + abs(az) * alpha
            let variances = [self.varianceX, self.varianceY, self.varianceZ]
            
            // ヒステリシス付き動的軸選択
            if let bestIdx = variances.enumerated().max(by: { $0.element < $1.element })?.offset {
                let currentVar = variances[self.activeAxisIndex]
                if bestIdx != self.activeAxisIndex && variances[bestIdx] > currentVar * 1.15 {
                    self.activeAxisIndex = bestIdx
                }
            }
            
            let active = filteredAxes[self.activeAxisIndex]
            self.processFilteredAcceleration(prev: active.prev, cur: active.cur)
        }
    }

    // MARK: - センサーデータ処理

    private func processFilteredAcceleration(prev: Double, cur: Double) {
        let now = Date()
        
        // 停止時はタイムアウトでSPMを0に戻す (M-7)
        if spm > 0, let lastCatch = strokeTimestamps.last, now.timeIntervalSince(lastCatch) > spmInactivityTimeout {
            spm = 0
            strokePhase = .idle
        }
        
        let threshold = fixedThreshold

        // 極性決定: 1サンプルのノイズで誤固定しないよう、3サンプル連続の閾値超過で仮決定し、
        // ストロークが確定するまでは3秒経過でリセット可能とする (M-7)
        if strokePolarity == 0.0 {
            if abs(cur) > threshold {
                let sign = cur >= 0 ? 1.0 : -1.0
                if sign == polarityCandidateSign {
                    polarityCandidateStreak += 1
                } else {
                    polarityCandidateSign = sign
                    polarityCandidateStreak = 1
                }
                if polarityCandidateStreak >= 3 {
                    strokePolarity = sign
                    polaritySetAt = now
                }
            } else {
                polarityCandidateStreak = 0
                polarityCandidateSign = 0.0
            }
            if strokePolarity == 0.0 { return }
        } else if !isPolarityConfirmed, let setAt = polaritySetAt, now.timeIntervalSince(setAt) > 3.0 {
            // 仮決定後3秒以内に有効なストロークが確定しなかった場合はノイズ誤判定とみなし再判定
            strokePolarity = 0.0
            polarityCandidateSign = 0.0
            polarityCandidateStreak = 0
            polaritySetAt = nil
            strokePhase = .idle
            return
        }

        // スマホの向きに関わらず「ドライブ時に正、キャッチ時に負」になるよう極性を適用
        let polarizedCur = cur * strokePolarity
        let polarizedPrev = prev * strokePolarity

        // ゼロクロッシング解除のヒステリシス（感度の15% = ゼロライン付近のチャタリング防止）
        let zeroCrossHysteresis = threshold * 0.15

        switch strokePhase {

        case .idle:
            // 閾値を下回る負の値を検出 → キャッチ候補の谷に入る
            if polarizedCur < -threshold {
                strokePhase = .inTrough
                troughMinValue = polarizedCur
                troughTimestamp = now
            }
            // 閾値を上回る正の値を検出 → ドライブ中
            else if polarizedCur > threshold {
                strokePhase = .inDrive
            }

        case .inTrough:
            // 谷の最小値を追跡
            if polarizedCur < troughMinValue {
                troughMinValue = polarizedCur
                troughTimestamp = now
            }

            // ゼロクロッシング (負→正): 谷を過ぎてキャッチが始まった瞬間
            if polarizedPrev < -zeroCrossHysteresis && polarizedCur >= -zeroCrossHysteresis {
                // キャッチ時刻: 谷の最小値の時刻
                registerStroke(at: troughTimestamp)
                strokePhase = .inDrive
            }
            // 閾値内に戻った場合（ゼロクロッシングなし）
            else if polarizedCur > -threshold && polarizedCur < threshold && polarizedPrev < polarizedCur {
                // 谷が小さすぎてゼロクロッシングせずに戻ったケース → リセット
                strokePhase = .idle
            }

        case .inDrive:
            // ドライブ（正の加速度域）から閾値内に戻った → 次のキャッチを待つ
            if polarizedCur < zeroCrossHysteresis {
                strokePhase = .idle
            }
        }
    }

    // MARK: - ストローク登録 & SPM計算

    private func registerStroke(at catchTime: Date) {
        // 動的デバウンス: 現在のSPMから最短ストローク間隔を計算
        // 例: 40spm → 1.5秒周期、デバウンス = 0.6秒 (60% * 1.5/1.5)
        let debounceInterval: TimeInterval
        if spm > 0 {
            let strokePeriod = 60.0 / Double(spm)
            // 周期の45%をデバウンス窓（高レート対応）
            debounceInterval = max(0.4, min(strokePeriod * 0.45, 2.0))
        } else {
            debounceInterval = MotionConstants.strokeDebounceInterval
        }

        // ダブルカウント防止
        if let last = strokeTimestamps.last, catchTime.timeIntervalSince(last) < debounceInterval {
            return
        }

        strokeTimestamps.append(catchTime)
        strokeCount += 1
        if strokeCount >= 2 {
            isPolarityConfirmed = true
        }

        // SPM計算: Rowing in Motion / 研究論文方式
        // 直近4ストロークのキャッチ間隔の中央値を使用
        updateSPM()

        // 30秒以上前の古いタイムスタンプを削除
        let cutoff = catchTime.addingTimeInterval(-30)
        strokeTimestamps = strokeTimestamps.filter { $0 >= cutoff }

        onStrokeDetected?()
    }

    private func updateSPM() {
        guard strokeTimestamps.count >= 2 else { return }

        // 直近4キャッチ（3間隔）を使用（研究論文推奨: 3-5ストロークの平均）
        let maxSamples = 4
        let recent = Array(strokeTimestamps.suffix(min(maxSamples, strokeTimestamps.count)))

        // キャッチ間隔を計算 (0.5〜6.0秒 = 10〜120spm の現実的な範囲に限定)
        var intervals: [TimeInterval] = []
        for i in 1..<recent.count {
            let interval = recent[i].timeIntervalSince(recent[i-1])
            if interval >= 0.5 && interval <= 6.0 {
                intervals.append(interval)
            }
        }
        guard !intervals.isEmpty else { return }

        // 中央値を使用（外れ値に対してロバスト）
        let sorted = intervals.sorted()
        let n = sorted.count
        let medianInterval = (n % 2 == 0)
            ? (sorted[n/2 - 1] + sorted[n/2]) / 2.0
            : sorted[n/2]

        let rawSpm = 60.0 / medianInterval

        // 表示安定化: 前回値とのEMA（最新値重視 0.6 / 前回値 0.4）
        // 実際のレート計はほぼ即時反映するので前回値の影響を抑える
        if spm == 0 {
            spm = Int(round(rawSpm))
        } else {
            let smoothed = 0.6 * rawSpm + 0.4 * Double(spm)
            spm = Int(round(smoothed))
        }

        if spm > 0 {
            spmSamples.append(spm)
        }
    }

    // MARK: - Public API

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }

    func reset() {
        strokeTimestamps.removeAll()
        spmSamples.removeAll()
        spm = 0
        strokeCount = 0
        // 全軸フィルタ状態リセット
        axisFilters = [AxisFilterState(), AxisFilterState(), AxisFilterState()]
        activeAxisIndex = 1
        varianceX = 0.0
        varianceY = 0.0
        varianceZ = 0.0
        // 位相リセット
        strokePhase = .idle
        troughMinValue = 0.0
        strokePolarity = 0.0
        polarityCandidateSign = 0.0
        polarityCandidateStreak = 0
        polaritySetAt = nil
        isPolarityConfirmed = false
    }
}
