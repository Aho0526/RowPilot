import SwiftUI
import MessageUI

struct PortraitView: View {
    @EnvironmentObject var app: AppViewModel
    
    // Oberve Theme Changes
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 共有ViewModelsを使用
    private var motionManager: MotionManager { app.motionManager }
    private var locationManager: LocationManager { app.locationManager }
    private var recordManager: RecordManager { app.recordManager }

    @State private var showingSaveAlert = false
    @State private var showingHelp = false
    @State private var showingSOSWarningAlert = false
    @State private var showingSOSButtonWarningAlert = false
    
    @State private var showSOSOverlay = false
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    
    // Observe Settings
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showingRowModeSettings = false

    // UIスロット設定の保存 (UserDefaults / AppStorage)
    @AppStorage("rowModePortraitLeftMetric") private var leftMetricRaw: String = RowModeMetric.distance.rawValue
    @AppStorage("rowModePortraitRightMetric") private var rightMetricRaw: String = RowModeMetric.chrono.rawValue
    
    private var leftMetric: RowModeMetric {
        RowModeMetric(rawValue: leftMetricRaw) ?? .distance
    }
    
    private var rightMetric: RowModeMetric {
        RowModeMetric(rawValue: rightMetricRaw) ?? .chrono
    }

    // セッション状態はAppViewModelから取得
    private var isRunning: Bool { app.isSessionActive }
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
        return String(format: "%.1f", app.isSessionActive ? locationManager.totalDistance : 0.0)
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
        guard count > 0 else { return "0.00" }
        let val = locationManager.totalDistance / Double(count)
        return String(format: "%.2f", val)
    }

    private func metricLabel(for metric: RowModeMetric) -> String {
        return metric.label
    }

    private func metricValue(for metric: RowModeMetric) -> String {
        guard app.isSessionActive else {
            switch metric {
            case .chrono: return "00:00.0"
            case .distance: return "0"
            case .averagePace: return "--:--"
            case .strokeCount: return "0"
            case .distPerStroke: return "0.00"
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

    private func metricUnit(for metric: RowModeMetric) -> String? {
        switch metric {
        case .distance:
            return "m"
        case .distPerStroke:
            return "m"
        case .averagePace:
            return "/500m"
        default:
            return nil
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
        ZStack {
            Theme.background.ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 1. SPM (Top Large)
                    ZStack(alignment: .topLeading) {
                        MetricCell(
                            label: "SPM".localized,
                            value: app.isSessionActive ? "\(motionManager.spm)" : "0",
                            color: Theme.accent,
                            width: geometry.size.width,
                            height: geometry.size.height * 0.32
                        )
                        
                        // GPS Indicator (Top Left)
                        if SettingsManager.shared.settings.showGPSAccuracy {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(gpsLabel(accuracy: locationManager.previousLocation?.horizontalAccuracy ?? -1))
                                    .font(.caption).bold()
                            }
                            .foregroundColor(gpsColor(accuracy: locationManager.previousLocation?.horizontalAccuracy ?? -1))
                            .padding(12)
                            .background(Theme.cardBackground)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.leading, 16)
                            .padding(.top, 16)
                        }
                        
                        // Help, SOS & Settings Buttons (Top Right)
                        HStack(spacing: 12) {
                            Spacer()
                            
                            // SOS Entry Button
                            Button(action: {
                                checkSOSAndShowOverlay()
                            }) {
                                let isSOSConfigured = !settingsManager.settings.sosContactPhone.isEmpty && !settingsManager.settings.sosUserName.isEmpty
                                Image(systemName: "sos")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(isSOSConfigured ? Color.red : Color.gray)
                                    .clipShape(Circle())
                                    .opacity(isSOSConfigured ? 1.0 : 0.6)
                            }
                            
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
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.textMain)
                                    .frame(width: 38, height: 38)
                                    .background(Theme.cardBackground)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(16)
                    }
                    
                    Divider().overlay(Theme.textSecondary.opacity(0.3))
                    
                    // 2. Pace (Middle Large)
                    MetricCell(
                        label: "Pace".localized,
                        value: app.isSessionActive ? formattedPace : "--:--",
                        color: Theme.secondaryAccent,
                        width: geometry.size.width,
                        height: geometry.size.height * 0.28
                    )
                    
                    Divider().overlay(Theme.textSecondary.opacity(0.3))
                    
                    // 3. Dynamic Bottom Split Metrics
                    HStack(spacing: 0) {
                        MetricCell(
                            label: metricLabel(for: leftMetric),
                            value: metricValue(for: leftMetric),
                            unit: metricUnit(for: leftMetric),
                            color: metricColor(for: leftMetric),
                            width: geometry.size.width / 2,
                            height: geometry.size.height * 0.2
                        )
                        
                        Divider().overlay(Theme.textSecondary.opacity(0.3))

                        MetricCell(
                            label: metricLabel(for: rightMetric),
                            value: metricValue(for: rightMetric),
                            unit: metricUnit(for: rightMetric),
                            color: metricColor(for: rightMetric),
                            width: geometry.size.width / 2,
                            height: geometry.size.height * 0.2
                        )
                    }
                    
                    Divider().overlay(Theme.textSecondary.opacity(0.3))
                    
                    // 4. Controls (Bottom Area)
                    ZStack {
                        LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        
                        Button(action: {
                            if isRunning {
                                stopSession()
                            } else {
                                checkSOSAndStart()
                            }
                        }) {
                            Text(isRunning ? "Stop".localized : "Start Rowing".localized)
                                .font(Theme.headerFont())
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(isRunning ? Color.red : Theme.accent)
                                .foregroundColor(Color.white)
                                .cornerRadius(35)
                                .shadow(color: (isRunning ? Color.red : Theme.accent).opacity(0.5), radius: 10, x: 0, y: 5)
                                .padding(.horizontal, 40)
                                .scaleEffect(isRunning ? 0.98 : 1.0)
                                .animation(.spring(response: 0.3), value: isRunning)
                        }
                    }
                    .frame(height: geometry.size.height * 0.22) // Increased slightly
                    .background(Theme.cardBackground)
                    .ignoresSafeArea(edges: .bottom)
                }
                
                // SOS Overlay
                if showSOSOverlay {
                    SOSOverlayView(isPresented: $showSOSOverlay) {
                        app.triggerSOS()
                    }
                    .zIndex(100)
                }
            }
            
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
                        
                        HStack(spacing: 20) {
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
                    .frame(maxWidth: 320)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(200)
            }
        }
        // Removed local sheet as it's now in ContainerView
        // Removed onChange as it's now in ContainerView
        .onAppear {
            batteryLevel = UIDevice.current.batteryLevel
        }
        .onDisappear {
            // ...
        }
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
        // Force redraw when theme changes
        .id(themeManager.currentPreset)
        .sheet(isPresented: $showingHelp) {
            RowModePortraitHelpView()
        }
    }
    
    // Logic Helpers
    private func gpsLabel(accuracy: Double) -> String {
        if accuracy < 0 { return "No Signal" }
        if accuracy <= 10 { return "High" }
        if accuracy <= 20 { return "Mid" }
        return "Low"
    }
    
    private func gpsColor(accuracy: Double) -> Color {
        if accuracy < 0 { return .red }
        if accuracy <= 10 { return .green }
        if accuracy <= 20 { return .yellow }
        return .orange
    }

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

    private func startSession() {
        app.startSession()
    }

    private func stopSession() {
        app.stopSession()
        showingSaveAlert = true
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
        return LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    private func calculateAveragePace() -> TimeInterval {
        guard locationManager.currentSpeed > 0 else { return 0 }
        let speedMps = locationManager.currentSpeed / LocationConstants.metersPerSecondToKmPerHour
        return LocationConstants.paceReferenceDistance / speedMps
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

// Styled Metric Cell
struct MetricCell: View {
    let label: String
    let value: String
    var unit: String? = nil
    let color: Color
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()
            
            Text(label)
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 4)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 70, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                
                if let unit = unit {
                    Text(unit)
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: width, height: height)
        .background(Theme.cardBackground)
    }
}

