import Foundation
import SwiftUI

/// ユーザー設定を管理する構造体
struct UserSettings: Codable {
    // 音声フィードバック設定
    var soundEnabled: Bool
    var voiceFeedbackEnabled: Bool
    var feedbackInterval: TimeInterval // 秒単位（例: 60秒ごと）
    
    // 表示設定
    var preferredColorScheme: ColorSchemePreference
    var showGPSAccuracy: Bool
    var showBatteryStatus: Bool
    
    // 計測設定
    var autoStartOnMotion: Bool
    var minSPMThreshold: Int // SPM計測の最小閾値
    var accelerationThreshold: Double // モーション感度 (G) default: 0.5
    var gpsAccuracy: GPSAccuracyLevel
    
    // データ同期
    var iCloudSyncEnabled: Bool
    
    // 単位設定
    var distanceUnit: DistanceUnit
    var speedUnit: SpeedUnit
    
    // 言語設定
    var language: AppLanguage
    
    // ヘルプ表示設定
    var showHelpButtons: Bool
    
    init(
        soundEnabled: Bool = true,
        voiceFeedbackEnabled: Bool = false,
        feedbackInterval: TimeInterval = 60,
        preferredColorScheme: ColorSchemePreference = .system,
        showGPSAccuracy: Bool = true,
        showBatteryStatus: Bool = true,
        autoStartOnMotion: Bool = false,
        minSPMThreshold: Int = 10,
        accelerationThreshold: Double = 0.5,
        gpsAccuracy: GPSAccuracyLevel = .best,
        iCloudSyncEnabled: Bool = false,
        distanceUnit: DistanceUnit = .meters,
        speedUnit: SpeedUnit = .kilometersPerHour,
        language: AppLanguage = .japanese,
        showHelpButtons: Bool = true
    ) {
        self.soundEnabled = soundEnabled
        self.voiceFeedbackEnabled = voiceFeedbackEnabled
        self.feedbackInterval = feedbackInterval
        self.preferredColorScheme = preferredColorScheme
        self.showGPSAccuracy = showGPSAccuracy
        self.showBatteryStatus = showBatteryStatus
        self.autoStartOnMotion = autoStartOnMotion
        self.minSPMThreshold = minSPMThreshold
        self.accelerationThreshold = accelerationThreshold
        self.gpsAccuracy = gpsAccuracy
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.distanceUnit = distanceUnit
        self.speedUnit = speedUnit
        self.language = language
        self.showHelpButtons = showHelpButtons
    }
}

// MARK: - Enums
enum ColorSchemePreference: String, Codable, CaseIterable {
    case light = "ライト"
    case dark = "ダーク"
    case system = "システム設定"
}

enum GPSAccuracyLevel: String, Codable, CaseIterable {
    case best = "最高精度"
    case tenMeters = "10m"
    case hundredMeters = "100m"
    case kilometer = "1km"
    
    var clLocationAccuracy: Double {
        switch self {
        case .best: return -1 // kCLLocationAccuracyBest
        case .tenMeters: return 10
        case .hundredMeters: return 100
        case .kilometer: return 1000
        }
    }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case meters = "メートル"
    case kilometers = "キロメートル"
    case miles = "マイル"
}

enum SpeedUnit: String, Codable, CaseIterable {
    case kilometersPerHour = "km/h"
    case milesPerHour = "mph"
    case metersPerSecond = "m/s"
}

// MARK: - UserDefaults Integration
extension UserSettings {
    private static let userDefaultsKey = "RowPilotUserSettings"
    
    /// UserDefaultsから設定を読み込む
    static func load() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings() // デフォルト設定を返す
        }
        return settings
    }
    
    /// UserDefaultsに設定を保存する
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: UserSettings.userDefaultsKey)
        }
    }
    
    /// 設定をリセット（デフォルトに戻す）
    static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: UserSettings {
        didSet {
            saveSettings()
        }
    }
    
    init() {
        self.settings = UserSettings.load()
        // 起動時に保存された言語でLocalizationManagerを初期化
        LocalizationManager.shared.setLanguage(self.settings.language)
    }
    
    private func saveSettings() {
        settings.save()
    }
    
    func resetToDefaults() {
        UserSettings.reset()
        settings = UserSettings()
        LocalizationManager.shared.setLanguage(settings.language)
    }
}
