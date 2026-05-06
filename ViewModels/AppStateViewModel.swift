import Foundation
import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var isSplashVisible: Bool = true  // アプリ起動時はスプラッシュを表示
    @Published var activeTab: Int = 0 // 0: Home, 1: Tide, 2: RowMode, 3: Practice, 4: Setting

    @Published var showSettings: Bool = false
    @Published var coverColor: Color = .blue // 初期カバー色
    
    // Landscape Lock: ×ボタン押下後にLandscapeへの遷移を禁止
    @Published var landscapeLocked: Bool = false

    // 共有ViewModels
    let motionManager = MotionManager()
    let locationManager = LocationManager()
    let recordManager = RecordManager()
    let tideManager = TideManager()
    
    // 共有 BLE マネージャー
    let ergManager = RowErgManager()
    let pm5Manager = PM5ManagerViewModel()
    
    // バックグラウンド管理
    private var lastBackgroundTime: Date?
    
    // セッション状態
    @Published var isSessionActive: Bool = false
    @Published var isRecording: Bool = false
    @Published var sessionStartTime: Date?
    @Published var sessionStartLocation: LocationData?
    @Published var elapsedTime: TimeInterval = 0
    
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 位置情報の更新を監視して TideManager に伝える
        locationManager.$previousLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.tideManager.findNearestStation(location: location)
            }
            .store(in: &cancellables)
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
    
    func startSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        isRecording = true
        sessionStartTime = Date()
        sessionStartLocation = getCurrentLocation()
        elapsedTime = 0
        
        motionManager.startMonitoring()
        locationManager.startTracking()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    func stopSession() {
        guard isSessionActive else { return }
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
        sessionStartTime = nil
        sessionStartLocation = nil
        motionManager.reset()
        locationManager.reset()
    }
    
    func resumeSession() {
        guard isSessionActive, sessionTimer == nil else { return }
        isRecording = true
        motionManager.startMonitoring()
        locationManager.startTracking()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
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
            if let lastTime = lastBackgroundTime {
                let diff = Date().timeIntervalSince(lastTime)
                print("AppViewModel: Returned to active. Stayed in background for \(Int(diff))s")
                // 15分（900秒）以上経過していたらリセット
                if diff > 900 {
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
}
