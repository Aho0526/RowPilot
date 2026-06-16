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
    
    // SOS設定
    var sosContactName: String
    var sosContactPhone: String
    var sosUserName: String
    var sosMapSelection: SOSMapSelection
    
    // 画面暗転防止設定
    private var _preventScreenDimming: Bool?
    var preventScreenDimming: Bool {
        get { _preventScreenDimming ?? true }
        set { _preventScreenDimming = newValue }
    }
    
    // マネージャー設定
    var saveZeroRecordPM5s: Bool
    
    // 天気表示設定
    var weatherDisplayMode: WeatherDisplayMode
    
    // 共有設定
    var autoShareAfterManagerSave: Bool
    var importBehavior: ImportBehavior
    
    // 共有時の名前設定
    var sharingName: String
    
    // 目標設定
    var monthlyTargetDistance: Double // メートル単位
    
    init(
        soundEnabled: Bool = false,
        voiceFeedbackEnabled: Bool = false,
        feedbackInterval: TimeInterval = 60,
        preferredColorScheme: ColorSchemePreference = .system,
        showGPSAccuracy: Bool = true,
        showBatteryStatus: Bool = true,
        autoStartOnMotion: Bool = false,
        minSPMThreshold: Int = 10,
        gpsAccuracy: GPSAccuracyLevel = .best,
        iCloudSyncEnabled: Bool = true,
        distanceUnit: DistanceUnit = .meters,
        speedUnit: SpeedUnit = .kilometersPerHour,
        language: AppLanguage = .japanese,
        showHelpButtons: Bool = true,
        sosContactName: String = "",
        sosContactPhone: String = "",
        sosUserName: String = "",
        sosMapSelection: SOSMapSelection = .both,
        preventScreenDimming: Bool = true,
        saveZeroRecordPM5s: Bool = false,
        weatherDisplayMode: WeatherDisplayMode = .iconAndTemp,
        autoShareAfterManagerSave: Bool = false,
        importBehavior: ImportBehavior = .askEachTime,
        monthlyTargetDistance: Double = 50000.0,
        sharingName: String = ""
    ) {
        self.soundEnabled = soundEnabled
        self.voiceFeedbackEnabled = voiceFeedbackEnabled
        self.feedbackInterval = feedbackInterval
        self.preferredColorScheme = preferredColorScheme
        self.showGPSAccuracy = showGPSAccuracy
        self.showBatteryStatus = showBatteryStatus
        self.autoStartOnMotion = autoStartOnMotion
        self.minSPMThreshold = minSPMThreshold
        self.gpsAccuracy = gpsAccuracy
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.distanceUnit = distanceUnit
        self.speedUnit = speedUnit
        self.language = language
        self.showHelpButtons = showHelpButtons
        self.sosContactName = sosContactName
        self.sosContactPhone = sosContactPhone
        self.sosUserName = sosUserName
        self.sosMapSelection = sosMapSelection
        self._preventScreenDimming = preventScreenDimming
        self.saveZeroRecordPM5s = saveZeroRecordPM5s
        self.weatherDisplayMode = weatherDisplayMode
        self.autoShareAfterManagerSave = autoShareAfterManagerSave
        self.importBehavior = importBehavior
        self.monthlyTargetDistance = monthlyTargetDistance
        self.sharingName = sharingName
    }
}

/// ワークアウト受信時のインポート挙動
enum ImportBehavior: String, Codable, CaseIterable, Identifiable {
    case autoImport = "自動インポート"
    case askEachTime = "毎回確認"
    case reject = "受信しない"
    
    var id: String { rawValue }
}

// MARK: - Enums
enum SOSMapSelection: String, Codable, CaseIterable {
    case appleMaps = "Apple Maps"
    case googleMaps = "Google Maps"
    case both = "Apple Maps & Google Maps"
}

/// ホームの天気表示モード
enum WeatherDisplayMode: String, Codable, CaseIterable, Identifiable {
    case hidden = "非表示"
    case iconOnly = "アイコンのみ"
    case iconAndTemp = "アイコン + 気温"
    case iconTempRain = "アイコン + 気温 + 降水確率"
    case full = "フル表示"
    
    var id: String { rawValue }
    
    var showIcon: Bool { self != .hidden }
    var showTemp: Bool { self == .iconAndTemp || self == .iconTempRain || self == .full }
    var showRain: Bool { self == .iconTempRain || self == .full }
    var showLabel: Bool { self == .full }
}
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
    
    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("user_settings.json")
    }
    
    /// UserDefaultsおよびJSONファイルから設定を読み込む
    static func load() -> UserSettings {
        // 1. まずJSONファイルからの読み込みを試みる
        if let fileURL = fileURL,
           let data = try? Data(contentsOf: fileURL),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            return settings
        }
        
        // 2. なければUserDefaultsからの読み込みを試みる（後方互換性）
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            // 次回の高速アクセスのためにJSONファイルにも保存しておく
            settings.save()
            return settings
        }
        
        return UserSettings() // デフォルト設定を返す
    }
    
    /// UserDefaultsおよびJSONファイルに設定を保存する
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        
        // 1. JSONファイルに保存する
        if let fileURL = UserSettings.fileURL {
            try? data.write(to: fileURL)
        }
        
        // 2. バックアップとしてUserDefaultsにも保存する
        UserDefaults.standard.set(data, forKey: UserSettings.userDefaultsKey)
    }
    
    /// 設定をリセット（デフォルトに戻す）
    static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        if let fileURL = fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
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
        var loadedSettings = UserSettings.load()
        self.settings = loadedSettings
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
