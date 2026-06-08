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

    // MARK: - 2次Butterworthローパスフィルタ (カットオフ約3Hz@50Hz)
    // デジタルButterworth LPF: カットオフ 3Hz / サンプリング 50Hz
    // Wc = 2*pi*3/50 = 0.3770, 事前計算済み係数
    private var bw_x1: Double = 0.0  // 入力遅延1
    private var bw_x2: Double = 0.0  // 入力遅延2
    private var bw_y1: Double = 0.0  // 出力遅延1
    private var bw_y2: Double = 0.0  // 出力遅延2
    // 2次Butterworth, fc=3Hz, fs=50Hz の係数 (bilinear transform)
    private let bwB0: Double = 0.02008337
    private let bwB1: Double = 0.04016673
    private let bwB2: Double = 0.02008337
    private let bwA1: Double = -1.56101808
    private let bwA2: Double =  0.64135154

    // フィルタ後の現在値・前値（ゼロクロッシング検出用）
    private var filteredCur: Double = 0.0
    private var filteredPrev: Double = 0.0

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

    // MARK: - 設定キャッシュ（50Hz更新でのディスクI/O回避）
    private var cachedThreshold: Double {
        return SettingsManager.shared.settings.accelerationThreshold
    }

    @Published var spm: Int = 0
    @Published var strokeCount: Int = 0

    // MARK: - Monitoring

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("加速度センサーが利用できません")
            return
        }

        // 起動時に極性を初期化
        strokePolarity = 0.0

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.processAccelerometerData(data.acceleration.y)
        }
    }

    // MARK: - センサーデータ処理

    private func processAccelerometerData(_ rawY: Double) {
        // 1. 2次Butterworthローパスフィルタ適用（ノイズ除去、ストローク周波数は通過）
        let filtered = applyButterworthLPF(rawY)

        // 前サンプルを保存して更新
        filteredPrev = filteredCur
        filteredCur = filtered

        // キャッチ感度閾値: ユーザー設定値（デフォルト0.5G）
        let threshold = cachedThreshold

        // 初回の閾値超過時に、キャッチの加速度極性を自動決定
        if strokePolarity == 0.0 {
            if abs(filteredCur) > threshold {
                strokePolarity = filteredCur >= 0 ? 1.0 : -1.0
            } else {
                // 極性が未定かつ閾値以下の場合は処理をスキップ
                return
            }
        }

        // スマホの向きに関わらず「ドライブ時に正、キャッチ時に負」になるよう極性を適用
        let polarizedCur = filteredCur * strokePolarity
        let polarizedPrev = filteredPrev * strokePolarity

        // ゼロクロッシング解除のヒステリシス（感度の15% = ゼロライン付近のチャタリング防止）
        let zeroCrossHysteresis = threshold * 0.15

        switch strokePhase {

        case .idle:
            // 閾値を下回る負の値を検出 → キャッチ候補の谷に入る
            if polarizedCur < -threshold {
                strokePhase = .inTrough
                troughMinValue = polarizedCur
                troughTimestamp = Date()
            }
            // 閾値を上回る正の値を検出 → ドライブ中
            else if polarizedCur > threshold {
                strokePhase = .inDrive
            }

        case .inTrough:
            // 谷の最小値を追跡
            if polarizedCur < troughMinValue {
                troughMinValue = polarizedCur
                troughTimestamp = Date()
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

    // MARK: - 2次Butterworthローパスフィルタ（差分方程式実装）
    // カットオフ周波数 3Hz, サンプリング 50Hz
    // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
    private func applyButterworthLPF(_ x: Double) -> Double {
        let y = bwB0 * x + bwB1 * bw_x1 + bwB2 * bw_x2
                         - bwA1 * bw_y1 - bwA2 * bw_y2
        bw_x2 = bw_x1
        bw_x1 = x
        bw_y2 = bw_y1
        bw_y1 = y
        return y
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

        // SPM計算: Rowing in Motion / 研究論文方式
        // 直近4ストロークのキャッチ間隔の中央値を使用
        updateSPM()

        // 30秒以上前の古いタイムスタンプを削除
        let cutoff = catchTime.addingTimeInterval(-30)
        strokeTimestamps = strokeTimestamps.filter { $0 >= cutoff }
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
    }

    // MARK: - Public API

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }

    func reset() {
        strokeTimestamps.removeAll()
        spm = 0
        strokeCount = 0
        // フィルタ状態リセット
        bw_x1 = 0.0; bw_x2 = 0.0
        bw_y1 = 0.0; bw_y2 = 0.0
        filteredCur = 0.0
        filteredPrev = 0.0
        // 位相リセット
        strokePhase = .idle
        troughMinValue = 0.0
        strokePolarity = 0.0
    }
}
