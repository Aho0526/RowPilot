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
    
    // SOS State
    @State private var isSOSPressing = false
    @State private var sosProgress: CGFloat = 0.0
    @State private var sosTimer: Timer?
    @State private var showSOSOverlay = false
    @State private var sosMessage: String = "" // Keep this for local generation
    @State private var showingMessageCompose = false // Remove local usage but keep for now or clean up later
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel
    
    // セッション状態はAppViewModelから取得
    private var isRunning: Bool { app.isSessionActive }
    private var elapsedTime: TimeInterval { app.elapsedTime }

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedPace: String {
        guard locationManager.currentSpeed > 0 else { return "--:--" }
        let speedMps = locationManager.currentSpeed / LocationConstants.metersPerSecondToKmPerHour
        let seconds = LocationConstants.paceReferenceDistance / speedMps
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
                        
                        // Help & SOS Buttons (Top Right)
                        if SettingsManager.shared.settings.showHelpButtons {
                            HStack(spacing: 12) {
                                Spacer()
                                
                                // SOS Entry Button
                                Button(action: {
                                    withAnimation { showSOSOverlay = true }
                                }) {
                                    Image(systemName: "sos")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                
                                HelpCircleButton {
                                    showingHelp = true
                                }
                            }
                            .padding(16)
                        }
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
                    
                    // 3. Distance & Time (Bottom Split)
                    HStack(spacing: 0) {
                        MetricCell(
                            label: "Distance".localized,
                            value: app.isSessionActive ? String(format: "%.0f", locationManager.totalDistance) : "0",
                            unit: "m",
                            color: .white,
                            width: geometry.size.width / 2,
                            height: geometry.size.height * 0.2
                        )
                        
                        Divider().overlay(Theme.textSecondary.opacity(0.3))

                        MetricCell(
                            label: "Time".localized,
                            value: formattedTime,
                            color: .white,
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
                                startSession()
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
                    ZStack {
                        Color.black.opacity(0.8)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation { showSOSOverlay = false }
                            }
                        
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                    .frame(width: 160, height: 160)
                                
                                Circle()
                                    .trim(from: 0, to: sosProgress)
                                    .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 160, height: 160)
                                    .rotationEffect(.degrees(-90))
                                
                                Button(action: {}) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 140, height: 140)
                                        
                                        Text("SOS")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isSOSPressing { startSOSPress() }
                                        }
                                        .onEnded { _ in cancelSOSPress() }
                                )
                            }
                            
                            Text(isSOSPressing ? "SOS_Press".localized : "SOS_Hold_1_5s".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .zIndex(100)
                }
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
        // Force redraw when theme changes
        .id(themeManager.currentPreset)
        .sheet(isPresented: $showingHelp) {
            HelpView(
                title: "RowMode Help".localized,
                content: """
                // 乗艇画面の使い方（縦画面）
                // ここにヒントを記述してください
                """
            )
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
    
    // MARK: - SOS Logic
    private func startSOSPress() {
        isSOSPressing = true
        sosProgress = 0.0
        SoundManager.shared.startPressingSound()
        sosTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            sosProgress += 0.05 / 1.5 // Match landscape duration
            if sosProgress >= 1.0 {
                timer.invalidate()
                activateSOS()
            }
        }
    }
    
    private func cancelSOSPress() {
        isSOSPressing = false
        sosProgress = 0.0
        sosTimer?.invalidate()
        sosTimer = nil
        SoundManager.shared.stopPressingSound()
    }
    
    private func activateSOS() {
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
        
        var locationStr = "Unknown"
        if let loc = locationManager.previousLocation {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            
            let appleMapsURL = "https://maps.apple.com/?q=SOS+地点&ll=\(lat),\(lon)"
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
        
        sosMessage = """
        RowPilot SOS
        \("User Name".localized): \(userName)
        \("Location Info".localized): \(locationStr)
        \("Time".localized): \(timeStr)
        \("Battery".localized): \(batteryStr)
        \("No response. Please check.".localized)
        """
        
        if !settings.sosContactPhone.isEmpty {
            app.pendingSOSMessage = sosMessage
            withAnimation { showSOSOverlay = false }
        }
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

