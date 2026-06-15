import SwiftUI
import MapKit
import MessageUI

struct LandscapeView: View {
    @EnvironmentObject var app: AppViewModel
    
    // Observe Theme
    @ObservedObject var themeManager = ThemeManager.shared
    
    // Observe Settings
    @ObservedObject var settingsManager = SettingsManager.shared
    
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
    @State private var showingSOSWarningAlert = false
    @State private var showingSOSButtonWarningAlert = false
    
    @State private var showSOSOverlay = false
    @State private var showingRowModeSettings = false
    
    // UIスロット設定の保存 (UserDefaults / AppStorage)
    @AppStorage("rowModeLeftMetric") private var leftMetricRaw: String = RowModeMetric.chrono.rawValue
    @AppStorage("rowModeRightMetric") private var rightMetricRaw: String = RowModeMetric.distance.rawValue
    
    private var leftMetric: RowModeMetric {
        RowModeMetric(rawValue: leftMetricRaw) ?? .chrono
    }
    
    private var rightMetric: RowModeMetric {
        RowModeMetric(rawValue: rightMetricRaw) ?? .distance
    }
    
    // セッション状態はAppViewModelから取得
    private var isRunning: Bool { app.isRecording }
    private var elapsedTime: TimeInterval { app.elapsedTime }
    
    private var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        let tenths = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 10)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        } else {
            return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
        }
    }

    private var formattedPace: String {
        guard locationManager.currentSpeed > 0 else { return "--:--" }
        let speedMps = locationManager.currentSpeed / LocationConstants.metersPerSecondToKmPerHour
        let seconds = LocationConstants.paceReferenceDistance / speedMps
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private var formattedDistance: String {
        return String(format: "%.1f m", app.isSessionActive ? locationManager.totalDistance : 0.0)
    }

    private var formattedAveragePace: String {
        let dist = locationManager.totalDistance
        guard dist > 0 else { return "--:--" }
        let paceSeconds = (elapsedTime / dist) * 500
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedStrokeCount: String {
        return "\(motionManager.strokeCount)"
    }

    private var formattedDistPerStroke: String {
        let count = motionManager.strokeCount
        guard count > 0 else { return "0.00 m" }
        let val = locationManager.totalDistance / Double(count)
        return String(format: "%.2f m", val)
    }

    private func metricLabel(for metric: RowModeMetric) -> String {
        return metric.label
    }

    private func metricValue(for metric: RowModeMetric) -> String {
        guard app.isSessionActive else {
            switch metric {
            case .chrono: return "00:00.0"
            case .distance: return "0.0 m"
            case .averagePace: return "--:--"
            case .strokeCount: return "0"
            case .distPerStroke: return "0.00 m"
            }
        }
        
        switch metric {
        case .chrono: return formattedTime
        case .distance: return formattedDistance
        case .averagePace: return formattedAveragePace
        case .strokeCount: return formattedStrokeCount
        case .distPerStroke: return formattedDistPerStroke
        }
    }

    private func metricColor(for metric: RowModeMetric) -> Color {
        switch metric {
        case .chrono, .distance, .distPerStroke:
            return .white
        case .averagePace:
            return Theme.secondaryAccent
        case .strokeCount:
            return Theme.accent
        }
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
                                
                                // Settings Gear Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showingRowModeSettings = true
                                    }
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.textMain)
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .padding(.trailing, 16)
                        }
                        
                        // 中央: コントロールボタン (完全に中央配置)
                        HStack(spacing: 30) { 
                            // SOS Button
                            Button(action: {
                                checkSOSAndShowOverlay()
                            }) {
                                let isSOSConfigured = !settingsManager.settings.sosContactPhone.isEmpty && !settingsManager.settings.sosUserName.isEmpty
                                Image(systemName: "sos")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(isSOSConfigured ? Color.red : Color.gray)
                                    .clipShape(Circle())
                                    .shadow(radius: isSOSConfigured ? 5 : 0)
                                    .opacity(isSOSConfigured ? 1.0 : 0.6)
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
                    VStack(spacing: 1) {
                        // Top Row
                        HStack(spacing: 1) {
                            metricBox(label: "SPM", value: app.isSessionActive ? "\(motionManager.spm)" : "0", color: Theme.accent)
                            metricBox(label: "Pace".localized, value: app.isSessionActive ? formattedPace : "--:--", color: Theme.secondaryAccent, isPace: true)
                        }
                        
                        // Bottom Row
                        HStack(spacing: 1) {
                            metricBox(label: metricLabel(for: leftMetric), value: metricValue(for: leftMetric), color: metricColor(for: leftMetric), isPace: leftMetric == .averagePace)
                            metricBox(label: metricLabel(for: rightMetric), value: metricValue(for: rightMetric), color: metricColor(for: rightMetric), isPace: rightMetric == .averagePace)
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
                
                // RowMode Settings Modal
                if showingRowModeSettings {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { showingRowModeSettings = false }
                            }
                        
                        VStack(spacing: 20) {
                            Text("Display Settings".localized)
                                .font(.title3)
                                .bold()
                                .foregroundColor(Theme.textMain)
                            
                            HStack(spacing: 30) {
                                // Left Element
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Left Element".localized)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    Picker("", selection: $leftMetricRaw) {
                                        ForEach(RowModeMetric.allCases) { metric in
                                            Text(metric.label).tag(metric.rawValue)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(8)
                                }
                                
                                // Right Element
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Right Element".localized)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    Picker("", selection: $rightMetricRaw) {
                                        ForEach(RowModeMetric.allCases) { metric in
                                            Text(metric.label).tag(metric.rawValue)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal)
                            
                            // Motion Sensitivity Settings
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Motion Sensitivity".localized)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.2f G", settingsManager.settings.accelerationThreshold))
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Theme.accent)
                                }
                                
                                Slider(value: Binding(
                                    get: { min(settingsManager.settings.accelerationThreshold, 0.5) },
                                    set: { newValue in
                                        settingsManager.settings.accelerationThreshold = newValue
                                    }
                                ), in: 0.01...0.5, step: 0.01)
                                .tint(Theme.accent)
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                withAnimation { showingRowModeSettings = false }
                            }) {
                                Text("Close".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 40)
                                    .background(Theme.accent)
                                    .cornerRadius(20)
                            }
                            .padding(.top, 10)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.cardBackground)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .frame(width: 400)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(200)
                }
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
                RowModeLandscapeHelpView()
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
        .alert("SOS Warning".localized, isPresented: $showingSOSWarningAlert) {
            Button("Set Contact".localized, role: .cancel) {
                app.navigateToSOSSettings()
            }
            Button("Start Anyway".localized, role: .destructive) {
                app.startSession()
            }
        } message: {
            Text("SOS Warning Message".localized)
        }
        .alert(
            LocalizationManager.shared.language == .japanese ? "緊急連絡先の未設定" : "Emergency Contact Not Set",
            isPresented: $showingSOSButtonWarningAlert
        ) {
            Button(LocalizationManager.shared.language == .japanese ? "設定する" : "Set Contact", role: .none) {
                app.navigateToSOSSettings()
            }
            Button(LocalizationManager.shared.language == .japanese ? "キャンセル" : "Cancel", role: .cancel) {}
        } message: {
            Text(LocalizationManager.shared.language == .japanese ? "緊急連絡先または使用者氏名が設定されていません。今すぐ入力しますか？" : "Emergency contact or user name is not configured. Would you like to enter it now?")
        }
    }

    private func updateStatusInfo() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
        batteryLevel = UIDevice.current.batteryLevel
    }

    private func metricBox(label: String, value: String, color: Color, isPace: Bool = false) -> some View {
        ZStack {
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
            
            if isPace {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("/500m")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground)
        .overlay(
             Rectangle()
                 .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Actions
    
    private func checkSOSAndShowOverlay() {
        let settings = SettingsManager.shared.settings
        if settings.sosContactPhone.isEmpty || settings.sosUserName.isEmpty {
            showingSOSButtonWarningAlert = true
        } else {
            withAnimation { showSOSOverlay = true }
        }
    }
    
    private func checkSOSAndStart() {
        let settings = SettingsManager.shared.settings
        if settings.sosContactPhone.isEmpty || settings.sosUserName.isEmpty {
            showingSOSWarningAlert = true
        } else {
            app.startSession()
        }
    }
    
    private func togglePause() {
        if app.isRecording {
            app.stopSession()
        } else {
            if app.isSessionActive {
                app.resumeSession()
            } else {
                checkSOSAndStart()
            }
        }
    }

    private func exitSession() {
        app.stopSession()
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
            endLocation: getCurrentLocation(),
            routePoints: locationManager.routePoints.isEmpty ? nil : locationManager.routePoints
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
