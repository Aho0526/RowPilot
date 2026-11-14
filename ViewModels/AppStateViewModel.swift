import Foundation
import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var isSplashVisible: Bool = true  // アプリ起動時はスプラッシュを表示
    @Published var activeTab: Int = 0 // 0: Home, 1: Tide, 2: RowMode, 3: Practice, 4: Setting

    @Published var showSettings: Bool = false
    @Published var coverColor: Color = .blue // 初期カバー色
    
    // Landscape Lock: ×ボタン押下後にLandscapeへの遷移を禁止
    @Published var landscapeLocked: Bool = false
    
    // Navigation State
    @Published var practiceNavigationPath = NavigationPath()
    @Published var settingsNavigationPath = NavigationPath()
    @Published var lastPracticeTabLeaveTime: Date?
    
    // SOS Shared State
    @Published var pendingSOSMessage: String?
    @Published var showSOSFromLandscape: Bool = false

    // 共有ViewModels
    let motionManager = MotionManager()
    let locationManager = LocationManager()
    let recordManager = RecordManager()
    let tideManager = TideManager()
    let weatherManager = WeatherManager()
    
    // 共有 BLE マネージャー
    let ergManager = RowErgManager()
    let pm5Manager = PM5ManagerViewModel()
    
    // バックグラウンド管理
    private var lastBackgroundTime: Date?
    private var isAutoStartStandby: Bool = false
    
    // セッション状態
    @Published var isSessionActive: Bool = false
    @Published var isRecording: Bool = false
    @Published var sessionStartTime: Date?
    @Published var sessionStartLocation: LocationData?
    @Published var elapsedTime: TimeInterval = 0
    @Published var showingRowModeSaveAlert: Bool = false
    
    private var accumulatedTime: TimeInterval = 0
    private var currentSegmentStartTime: Date?
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 子ViewModelの変更を親のobjectWillChangeに転送してSwiftUIの再描画を保証
        locationManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        motionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        // 位置情報の更新を監視して TideManager に伝える
        locationManager.$previousLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.tideManager.findNearestStation(location: location)
                self?.weatherManager.fetchWeather(for: location)
            }
            .store(in: &cancellables)
            
        // 既に位置情報が許可されている場合は起動時に取得を開始（スプラッシュ表示中にプリフェッチ）
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestPermission()
        }
            
        // バッテリー監視を有効化
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    /// スプラッシュ画面終了時に呼び出される処理
    func onSplashFinished() {
        // 未許可/初回起動時などにGPS許可リクエスト・位置取得を開始
        locationManager.requestPermission()
    }
    
    // MARK: - Landscape Lock
    
    /// ×ボタン押下時に呼び出し、Landscapeへの遷移をロック
    func lockLandscape() {
        landscapeLocked = true
    }
    
    /// 縦画面に戻った時にロック解除
    func unlockLandscape() {
        landscapeLocked = false
    }
    
    // MARK: - Session Management

    func startAutoStartStandbyIfNeeded() {
        let settings = SettingsManager.shared.settings
        guard settings.autoStartOnMotion, !isSessionActive, !isAutoStartStandby else { return }
        isAutoStartStandby = true
        motionManager.reset()
        motionManager.onStrokeDetected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isAutoStartStandby, !self.isSessionActive else { return }
                let minSPM = SettingsManager.shared.settings.minSPMThreshold
                if self.motionManager.strokeCount >= 2 && (self.motionManager.spm >= minSPM || self.motionManager.spm > 0) {
                    self.stopAutoStartStandby()
                    self.startSession()
                }
            }
        }
        motionManager.startMonitoring()
    }

    func stopAutoStartStandby() {
        guard isAutoStartStandby else { return }
        isAutoStartStandby = false
        motionManager.onStrokeDetected = nil
        if !isSessionActive {
            motionManager.stopMonitoring()
            motionManager.reset()
        }
    }
    
    func startSession() {
        guard !isSessionActive else { return }
        if isAutoStartStandby {
            isAutoStartStandby = false
            motionManager.onStrokeDetected = nil
            motionManager.stopMonitoring()
            motionManager.reset()
        }
        
        let now = Date()
        isSessionActive = true
        isRecording = true
        sessionStartTime = now
        sessionStartLocation = getCurrentLocation()
        accumulatedTime = 0
        currentSegmentStartTime = now
        elapsedTime = 0
        showingRowModeSaveAlert = false
        
        motionManager.startMonitoring()
        locationManager.startTracking()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let segStart = self.currentSegmentStartTime else { return }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(segStart)
            }
        }
    }
    
    func stopSession() {
        guard isSessionActive else { return }
        if let segStart = currentSegmentStartTime {
            accumulatedTime += Date().timeIntervalSince(segStart)
            elapsedTime = accumulatedTime
            currentSegmentStartTime = nil
        }
        isRecording = false
        motionManager.stopMonitoring()
        locationManager.stopTracking()
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    func endSession() {
        stopSession()
        isSessionActive = false
        isRecording = false
    }
    
    func resetSession() {
        stopSession()
        isSessionActive = false
        isRecording = false
        elapsedTime = 0
        accumulatedTime = 0
        currentSegmentStartTime = nil
        sessionStartTime = nil
        sessionStartLocation = nil
        showingRowModeSaveAlert = false
        motionManager.reset()
        locationManager.reset()
    }
    
    func resumeSession() {
        guard isSessionActive, sessionTimer == nil else { return }
        isRecording = true
        currentSegmentStartTime = Date()
        motionManager.startMonitoring()
        locationManager.resumeTracking()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let segStart = self.currentSegmentStartTime else { return }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(segStart)
            }
        }
    }
    
    private func getCurrentLocation() -> LocationData? {
        guard let location = locationManager.previousLocation else { return nil }
        return LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    // MARK: - Lifecycle & Timeout Management
    
    /// アプリの状態変化を処理
    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lastBackgroundTime = Date()
            print("AppViewModel: Entered background at \(lastBackgroundTime!)")
        case .active:
            // Check subscription expiration and sync shared plan
            SubscriptionManager.shared.checkSubscriptionStatus()
            
            if let lastTime = lastBackgroundTime {
                let diff = Date().timeIntervalSince(lastTime)
                print("AppViewModel: Returned to active. Stayed in background for \(Int(diff))s")
                // 15分（900秒）以上経過しており、計測セッション中・PM5接続中のいずれでもない場合のみリセット (H-11)
                let isErgoBusy = ergManager.connectionState != .disconnected
                    || !pm5Manager.connectedDevices.isEmpty
                    || !pm5Manager.connectingDeviceIDs.isEmpty
                if diff > 900 && !isSessionActive && !isErgoBusy {
                    print("AppViewModel: Timeout reached (15min+). Triggering full reset.")
                    fullReset()
                }
            }
            lastBackgroundTime = nil
        default:
            break
        }
    }
    
    /// 全ての接続を解除し、初期状態（スプラッシュ画面）に戻す
    func fullReset() {
        // BLE接続解除
        ergManager.disconnect()
        pm5Manager.disconnectAll()
        
        // セッション・計測リセット
        resetSession()
        
        // UI状態リセット
        activeTab = 0
        showSettings = false
        isSplashVisible = true
        
        print("AppViewModel: Full reset completed.")
    }
    
    // MARK: - Navigation Helpers
    
    func navigateToSOSSettings() {
        activeTab = 4 // Settings tab
        settingsNavigationPath.append("SOSSettings")
    }
    
    // MARK: - SOS Logic
    
    func triggerSOS() {
        SoundManager.shared.playSOSTone()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        let settings = SettingsManager.shared.settings
        let userName = settings.sosUserName.isEmpty ? "RowPilot User" : settings.sosUserName
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        
        let level = UIDevice.current.batteryLevel
        let batteryStr = level >= 0 ? "\(Int(level * 100))%" : "Unknown"
        
        var locationStr = "Unknown".localized
        if let loc = locationManager.previousLocation {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [
                URLQueryItem(name: "q", value: "SOS Location".localized),
                URLQueryItem(name: "ll", value: "\(lat),\(lon)")
            ]
            let appleMapsURL = components?.url?.absoluteString ?? "https://maps.apple.com/?ll=\(lat),\(lon)"
            let googleMapsURL = "https://www.google.com/maps/search/?api=1&query=\(lat),\(lon)"
            
            switch settings.sosMapSelection {
            case .appleMaps:
                locationStr = appleMapsURL
            case .googleMaps:
                locationStr = googleMapsURL
            case .both:
                locationStr = """
                
                Apple Maps: \(appleMapsURL)
                Google Maps: \(googleMapsURL)
                """
            }
        }
        
        let message = """
        RowPilot SOS
        \("User Name".localized): \(userName)
        \("Location Info".localized): \(locationStr)
        \("Time".localized): \(timeStr)
        \("Battery".localized): \(batteryStr)
        \("No response. Please check.".localized)
        """
        
        if !settings.sosContactPhone.isEmpty {
            self.pendingSOSMessage = message
        }
    }
}
