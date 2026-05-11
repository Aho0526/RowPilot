import SwiftUI
import MapKit
import MessageUI

struct LandscapeView: View {
    @EnvironmentObject var app: AppViewModel
    
    // Observe Theme
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 共有ViewModelsを使用
    private var motionManager: MotionManager { app.motionManager }
    private var locationManager: LocationManager { app.locationManager }
    private var recordManager: RecordManager { app.recordManager }
    
    @State private var currentTime: String = ""
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    @State private var gpsStrength: Int = 100
    @State private var statusTimer: Timer?
    @State private var showingSaveAlert = false
    @State private var showingHelp = false
    
    @State private var showSOSOverlay = false
    
    // セッション状態はAppViewModelから取得
    private var isRunning: Bool { app.isRecording }
    private var elapsedTime: TimeInterval { app.elapsedTime }
    
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let hours = minutes / 60
        return String(format: "%02d:%02d:%02d", hours, minutes % 60, seconds)
    }

    private var formattedPace: String {
        guard locationManager.currentSpeed > 0 else { return "--:-- /500m" }
        let speedMps = locationManager.currentSpeed / LocationConstants.metersPerSecondToKmPerHour
        let seconds = LocationConstants.paceReferenceDistance / speedMps
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d /500m", minutes, remainingSeconds)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ノッチエリア（画面上部）
                    ZStack {
                        // 左右の要素 (Time, GPS, Battery)
                        HStack(spacing: 0) {
                            // 現在時刻（左詰め）
                            Text(currentTime)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.textMain)
                                .padding(.leading, 16)
                            
                            Spacer()
                            
                            // 右側: GPS精度とバッテリー
                            HStack(spacing: 12) {
                                // GPS情報
                                if SettingsManager.shared.settings.showGPSAccuracy {
                                    HStack(spacing: 4) {
                                        if let accuracy = locationManager.previousLocation?.horizontalAccuracy, accuracy >= 0 {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(gpsStrengthColor(accuracy: accuracy))
                                            
                                            Text(gpsStrengthLabel(accuracy: accuracy))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(gpsStrengthColor(accuracy: accuracy))
                                        } else {
                                            Image(systemName: "location.slash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                // バッテリー残量
                                HStack(spacing: 4) {
                                    Image(systemName: batteryIcon(level: batteryLevel))
                                        .foregroundColor(batteryColor(level: batteryLevel))
                                    
                                    Text("\(Int(batteryLevel * 100))%")
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(Theme.textMain)
                                }
                                
                                // Help Button
                                if SettingsManager.shared.settings.showHelpButtons {
                                    HelpCircleButton {
                                        showingHelp = true
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                        }
                        
                        // 中央: コントロールボタン (完全に中央配置)
                        HStack(spacing: 30) { 
                            // SOS Button
                            Button(action: {
                                withAnimation { showSOSOverlay = true }
                            }) {
                                Image(systemName: "sos")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            
                            // 一時停止/再開ボタン
                            Button(action: togglePause) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(isRunning ? Color.orange : Theme.accent)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            
                            // 退出ボタン
                            Button(action: exitSession) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.secondaryAccent.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .background(Theme.cardBackground)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
 
                    // メイン表示エリア
                    HStack(spacing: 1) {
                        // Left Column
                        VStack(spacing: 1) {
                            metricBox(label: "SPM".localized, value: app.isSessionActive ? "\(motionManager.spm)" : "0", color: Theme.accent)
                            metricBox(label: "Pace".localized, value: app.isSessionActive ? formattedPace : "--:--", color: Theme.secondaryAccent)
                        }
                        // Right Column
                        VStack(spacing: 1) {
                            metricBox(label: "Distance_M".localized, value: String(format: "%.1f m", app.isSessionActive ? locationManager.totalDistance : 0.0), color: .white)
                            metricBox(label: "Time".localized, value: formattedTime, color: .white)
                        }
                    }
                    .padding(.top, 1)
                } // VStack end
                
                // SOS Overlay
                if showSOSOverlay {
                    SOSOverlayView(isPresented: $showSOSOverlay) {
                        app.triggerSOS()
                    }
                    .zIndex(100)
                } // SOS Overlay end
            } // ZStack end
            // Removed local sheet as it's now in ContainerView
            .onAppear {
                UIDevice.current.isBatteryMonitoringEnabled = true
                updateStatusInfo()
                statusTimer = Timer.scheduledTimer(withTimeInterval: UIConstants.statusUpdateInterval, repeats: true) { _ in
                    updateStatusInfo()
                }
            }
            .onDisappear {
                statusTimer?.invalidate()
                statusTimer = nil
                SoundManager.shared.stopSOS() // Safety
            }
            .id(themeManager.currentPreset)
            .sheet(isPresented: $showingHelp) {
                HelpView(
                    title: "RowMode Help".localized,
                    content: """
                    // 乗艇画面の使い方（横画面）
                    // ここにヒントを記述してください
                    """
                )
            }
        } // GeometryReader end
        .alert("Save Record".localized, isPresented: $showingSaveAlert) {
            Button("Save".localized, role: .none) {
                saveRecord()
            }
            Button("Discard".localized, role: .destructive) {
                discardSession()
            }
            Button("Cancel".localized, role: .cancel) {
                app.resumeSession()
            }
        } message: {
            Text("Save Message".localized)
        }
    }

    private func updateStatusInfo() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
        batteryLevel = UIDevice.current.batteryLevel
    }

    private func metricBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Spacer()
            Text(value)
                .font(.system(size: 60, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            
            Text(label)
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground)
        .overlay(
             Rectangle()
                 .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Actions
    
    private func togglePause() {
        if app.isRecording {
            app.stopSession()
        } else {
            if app.isSessionActive {
                app.resumeSession()
            } else {
                app.startSession()
            }
        }
    }

    private func exitSession() {
        app.stopSession()
        app.lockLandscape() // Lock it specifically
        // No alert here if we want immediate transition? 
        // But user said "X button pressed -> forced transition to Portrait". 
        // We'll keep the alert for safety but ensure the transition happens.
        showingSaveAlert = true
    }

    private func resetSession() {
        app.resetSession()
    }
    
    private func saveRecord() {
        guard let startTime = app.sessionStartTime else { return }
        let record = RowingRecord(
            date: startTime,
            duration: elapsedTime,
            distance: locationManager.totalDistance,
            averageSPM: motionManager.spm,
            averageSpeed: locationManager.currentSpeed,
            averagePace: calculateAveragePace(),
            startLocation: app.sessionStartLocation,
            endLocation: getCurrentLocation()
        )
        recordManager.addRecord(record)
        discardSession()
    }
    
    private func discardSession() {
        app.resetSession()
    }
    
    private func getCurrentLocation() -> LocationData? {
        guard let location = locationManager.previousLocation else { return nil }
        return LocationData(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    private func calculateAveragePace() -> TimeInterval {
        guard locationManager.currentSpeed > 0 else { return 0 }
        let speedMps = locationManager.currentSpeed / LocationConstants.metersPerSecondToKmPerHour
        return LocationConstants.paceReferenceDistance / speedMps
    }
    
    // MARK: - Helper Functions
    private func gpsStrengthLabel(accuracy: Double) -> String {
        if accuracy <= 10 { return "強" }
        if accuracy <= 20 { return "中" }
        return "弱"
    }
    
    private func gpsStrengthColor(accuracy: Double) -> Color {
        if accuracy <= 10 { return .green }
        if accuracy <= 20 { return .yellow }
        return .orange
    }
    
    private func batteryIcon(level: Float) -> String {
        if level <= 0.2 { return "battery.25" }
        if level <= 0.5 { return "battery.50" }
        if level <= 0.75 { return "battery.75" }
        return "battery.100"
    }
    
    private func batteryColor(level: Float) -> Color {
        if level <= 0.2 { return .red }
        if level <= 0.5 { return .yellow }
        return .green
    }
    
    
}
