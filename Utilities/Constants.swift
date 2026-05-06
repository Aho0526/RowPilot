import Foundation
import CoreLocation

// MARK: - Motion Sensing Constants
enum MotionConstants {
    /// 加速度センサーの閾値（ストローク検出用）
    static let accelerationThreshold: Double = 1.2
    
    /// ストロークのダブルカウント防止間隔（秒）
    static let strokeDebounceInterval: TimeInterval = 0.8
    
    /// SPM計算用のタイムウィンドウ（秒）
    static let strokeWindowSeconds: TimeInterval = 10.0
    
    /// センサー更新間隔（秒）
    static let sensorUpdateInterval: TimeInterval = 0.1
}

// MARK: - Location Tracking Constants
enum LocationConstants {
    /// GPS距離フィルター（メートル）
    /// この距離以上移動した場合のみ位置情報を更新
    static let distanceFilterMeters: CLLocationDistance = 5
    
    /// GPS精度設定
    static let defaultAccuracy = kCLLocationAccuracyBest
    
    /// 速度をkm/hに変換する係数
    static let metersPerSecondToKmPerHour: Double = 3.6
    
    /// 500mペース計算用の基準距離（メートル）
    static let paceReferenceDistance: Double = 500.0
    
    /// 潮汐情報検索に使用するGPS精度の閾値（メートル）
    static let tideAccuracyThreshold: CLLocationDistance = 100
}

// MARK: - UI Constants
enum UIConstants {
    /// ステータス更新間隔（秒）
    static let statusUpdateInterval: TimeInterval = 60
    
    /// スプラッシュ画面表示時間（秒）
    static let splashDuration: TimeInterval = 2.0
    
    /// アニメーション時間（秒）
    static let animationDuration: TimeInterval = 0.8
}

// MARK: - Color Constants
enum AppColors {
    // 今後カスタムカラーを定義する場合はここに追加
    // 例:
    // static let primaryBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    // static let accentGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
}

// MARK: - Sound & Feedback Constants
enum FeedbackConstants {
    /// デフォルトの音声フィードバック間隔（秒）
    static let defaultVoiceFeedbackInterval: TimeInterval = 60
    
    /// デフォルトのSPM最小閾値
    static let defaultMinSPMThreshold: Int = 10
    
    /// 音声ファイル名（将来的に使用）
    enum SoundFiles {
        static let strokeSound = "stroke.wav"
        static let startSound = "start.wav"
        static let stopSound = "stop.wav"
        static let warningSound = "warning.wav"
    }
}

// MARK: - Data Persistence Constants
enum PersistenceConstants {
    /// UserDefaults キー
    static let userSettingsKey = "RowPilotUserSettings"
    
    /// 記録データの保存先ファイル名
    static let recordsFileName = "rowing_records.json"
    
    /// iCloud コンテナ識別子（必要に応じて設定）
    static let iCloudContainerIdentifier = "iCloud.com.yourcompany.RowPilot"
}

// MARK: - Validation Constants
enum ValidationConstants {
    /// 有効なSPMの範囲
    static let validSPMRange = 0...60
    
    /// 有効な速度の範囲（km/h）
    static let validSpeedRange = 0.0...50.0
    
    /// 最小記録時間（秒）
    static let minimumRecordDuration: TimeInterval = 10
}
