import SwiftUI

/// マネージャーモード：ワークアウト実行中ダッシュボード
/// 各PM5のリアルタイムメトリクスをカード形式で表示
struct ManagerWorkoutDashboardView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showWorkoutSetup: Bool = false
    
    private var isPad: Bool {
        sizeClass == .regular
    }
    
    @State private var showSaveAlert = false
    @State private var showRepeatAlert = false
    @State private var showBackAlert = false
    @State private var showModeSettings = false
    @State private var showEditSheet = false
    @State private var showZoomSettings = false
    
    @AppStorage("pm5GridColumns") private var pm5GridColumns: Int = 2
    @State private var isLandscapeMode: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isDistanceWorkout = viewModel.workoutDistance != nil
            
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isLandscape && isDistanceWorkout {
                    // MARK: - Landscape Race View (単一距離のみ)
                    ManagerRaceView(
                        viewModel: viewModel,
                        showRepeatAlert: $showRepeatAlert,
                        showModeSettings: $showModeSettings,
                        showEditSheet: $showEditSheet,
                        showZoomSettings: $showZoomSettings
                    )
                } else {
                    // MARK: - Portrait Card Dashboard
                    VStack(spacing: 0) {
                        // MARK: - Header
                        dashboardHeader
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        if viewModel.isSaved {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Results Saved".localized)
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 4)
                        }
                        
                        // MARK: - PM5 Cards
                        ScrollView {
                            let minCount = isPad ? max(pm5GridColumns, 1) : max(pm5GridColumns, 1)
                            let columns = Array(repeating: GridItem(.flexible()), count: minCount)
                            
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(viewModel.sortedConnectedDevices, id: \.identifier) { device in
                                    let number = viewModel.deviceNumbers[device.identifier] ?? 0
                                    if let metrics = viewModel.deviceMetrics[device.identifier] {
                                        PM5MetricsCardView(
                                            metrics: metrics,
                                            deviceNumber: number,
                                            displayName: viewModel.displayName(for: device),
                                            targetDistance: viewModel.workoutDistance,
                                            targetTime: viewModel.workoutTime,
                                            isDisconnected: viewModel.disconnectedDeviceIDs.contains(device.identifier)
                                        )
                                    } else {
                                        PM5MetricsCardView(
                                            metrics: PM5DeviceMetrics(id: device.identifier, name: device.name ?? "Unknown PM5"),
                                            deviceNumber: number,
                                            displayName: viewModel.displayName(for: device),
                                            targetDistance: viewModel.workoutDistance,
                                            targetTime: viewModel.workoutTime,
                                            isDisconnected: viewModel.disconnectedDeviceIDs.contains(device.identifier)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .onAppear { isLandscapeMode = geo.size.width > geo.size.height }
            .onChange(of: geo.size) { newSize in isLandscapeMode = newSize.width > newSize.height }
        }
        .navigationTitle(isLandscapeMode ? "Race View".localized : "Dashboard".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isLandscapeMode {
                // MARK: - Landscape Toolbar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showZoomSettings = true }) {
                            Label("レースズーム", systemImage: "ruler")
                        }
                        Button(action: { showRepeatAlert = true }) {
                            Label("もう一度", systemImage: "arrow.counterclockwise")
                        }
                        Button(action: { showModeSettings = true }) {
                            Label("モード設定", systemImage: "gearshape.fill")
                        }
                        Button(action: { showEditSheet = true }) {
                            Label("PM5編集", systemImage: "pencil.and.list.clipboard")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.accent)
                    }
                }
            } else {
                // MARK: - Portrait Toolbar
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if viewModel.isSaved {
                            viewModel.resetAllDevices()
                            dismiss()
                        } else {
                            showBackAlert = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back".localized)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSaveAlert = true
                    }) {
                        Text("Save".localized)
                            .fontWeight(.bold)
                    }
                    .disabled(viewModel.isSaved)
                }
            }
        }
        .toolbar(isLandscapeMode ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(isLandscapeMode ? .hidden : .visible, for: .tabBar)
        .navigationDestination(isPresented: $showWorkoutSetup) {
            ManagerWorkoutSetupView(viewModel: viewModel)
        }
        .alert("Save Results".localized, isPresented: $showSaveAlert) {
            Button("Save".localized) {
                viewModel.saveAllRecords(recordManager: appViewModel.recordManager)
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Would you like to save all connected erg records?".localized)
        }
        .alert("Repeat Workout".localized, isPresented: $showRepeatAlert) {
            Button("Save and Repeat".localized) {
                viewModel.saveAllRecords(recordManager: appViewModel.recordManager)
                viewModel.resetAndStartWorkout(
                    distance: viewModel.workoutDistance,
                    time: viewModel.workoutTime,
                    split: viewModel.workoutDistance != nil ? viewModel.workoutSplitDistance : viewModel.workoutSplitTime
                )
            }
            Button("Discard and Repeat".localized, role: .destructive) {
                viewModel.resetAndStartWorkout(
                    distance: viewModel.workoutDistance,
                    time: viewModel.workoutTime,
                    split: viewModel.workoutDistance != nil ? viewModel.workoutSplitDistance : viewModel.workoutSplitTime
                )
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Would you like to save current results before repeating?".localized)
        }
        .alert("Finish Workout".localized, isPresented: $showBackAlert) {
            Button("Finish without saving".localized, role: .destructive) {
                viewModel.resetAllDevices()
                dismiss()
            }
            Button("Save and Finish".localized) {
                viewModel.saveAllRecords(recordManager: appViewModel.recordManager)
                viewModel.resetAllDevices()
                dismiss()
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Are you sure you want to finish without saving?".localized)
        }
        .sheet(isPresented: $showModeSettings) {
            ManagerModeSettingsView(viewModel: viewModel, showWorkoutSetup: $showWorkoutSetup, showModeSettings: $showModeSettings)
        }
        .sheet(isPresented: $showEditSheet) {
            PM5EditView(viewModel: viewModel, isPresented: $showEditSheet)
        }
    }
    
    // MARK: - Dashboard Header
    private var dashboardHeader: some View {
        VStack(spacing: 6) {
            HStack {
                // 目標距離 or 目標時間
                VStack(alignment: .leading, spacing: 2) {
                    if let dist = viewModel.workoutDistance {
                        Text("\(dist)m")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                        Text("Target Distance".localized)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    } else if let time = viewModel.workoutTime {
                        Text(formatTime(seconds: time))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                        Text("Target Time".localized)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // もう一度ボタン
                Button(action: {
                    showRepeatAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.accent)
                        Text("Repeat".localized)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(width: 52)
                }
                
                // モード設定ボタン
                Button(action: {
                    showModeSettings = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("モード設定")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(width: 52)
                }
                
                // PM5編集ボタン
                Button(action: {
                    showEditSheet = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                        Text("編集")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(width: 52)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            
            // 接続台数サマリー
            let activeCount = viewModel.connectedDevices.count - viewModel.disconnectedDeviceIDs.count
            let totalCount = viewModel.connectedDevices.count
            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundColor(activeCount == totalCount ? .green : .orange)
                Text("\(activeCount)/\(totalCount) PM5 \("Active".localized)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    // MARK: - Time Formatting
    private func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - PM5 Metrics Card (Compact)
struct PM5MetricsCardView: View {
    @ObservedObject var metrics: PM5DeviceMetrics
    let deviceNumber: Int
    let displayName: String
    let targetDistance: Int?
    let targetTime: Int?
    let isDisconnected: Bool
    
    @AppStorage("pm5DisplayMode") private var pm5DisplayMode: Int = 1 // 0: Small, 1: Normal, 2: Large
    @AppStorage("pm5ShowPace") private var pm5ShowPace: Bool = true
    @AppStorage("pm5ShowWatts") private var pm5ShowWatts: Bool = true
    
    private var baseFontSize: CGFloat {
        switch pm5DisplayMode {
        case 0: return 11
        case 2: return 17
        default: return 14
        }
    }
    
    private var valueFontSize: CGFloat {
        switch pm5DisplayMode {
        case 0: return 13
        case 2: return 20 // 調整
        default: return 15
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Device header (compact)
            HStack(spacing: 6) {
                // 番号バッジ
                Text("#\(deviceNumber)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 18)
                    .background(isDisconnected ? Color.gray : Theme.accent)
                    .cornerRadius(4)
                
                Circle()
                    .fill(isDisconnected ? Color.gray : Color.green)
                    .frame(width: 7, height: 7)
                
                Text(displayName)
                    .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(isDisconnected ? .gray : Theme.textMain)
                    .lineLimit(1)
                
                Spacer()
                
                if isDisconnected {
                    HStack(spacing: 3) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(.gray)
                        Text("Reconnecting".localized)
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isDisconnected ? Color.gray.opacity(0.12) : Color.green.opacity(0.08))
            
            // Metrics (compact 2x2 grid) or Syncing Status
            ZStack {
                HStack(spacing: 6) {
                    // 左カラム: 残距離/残時間 + ペース
                    VStack(spacing: 4) {
                        if let targetDist = targetDistance {
                            let remaining = max(Double(targetDist) - metrics.distance, 0)
                            CompactMetricView(
                                label: "Remaining".localized,
                                value: String(format: "%.0fm", remaining),
                                icon: "flag.fill",
                                color: remaining > 0 ? Theme.accent : .green,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        } else if let targetSec = targetTime {
                            let remaining = max(Double(targetSec) - metrics.elapsedTime, 0)
                            CompactMetricView(
                                label: "Remaining".localized,
                                value: formatCompactTime(seconds: Int(remaining)),
                                icon: "clock",
                                color: remaining > 0 ? Theme.accent : .green,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        }
                        
                        if pm5ShowPace {
                            CompactMetricView(
                                label: "Pace".localized,
                                value: formatPace(seconds: metrics.pace500m),
                                icon: "speedometer",
                                color: .orange,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        }
                    }
                    
                    // 右カラム: 経過時間 + ワット
                    VStack(spacing: 4) {
                        if targetTime != nil {
                            // 単一時間設定の時は「進んだ距離」を表示
                            CompactMetricView(
                                label: "Distance".localized,
                                value: String(format: "%.0fm", metrics.distance),
                                icon: "figure.outdoor.rowing",
                                color: .white,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        } else {
                            CompactMetricView(
                                label: "Duration".localized,
                                value: formatElapsedWithMs(seconds: metrics.elapsedTime),
                                icon: "timer",
                                color: .white,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        }
                        
                        if pm5ShowWatts {
                            CompactMetricView(
                                label: "Watts",
                                value: "\(metrics.power)W",
                                icon: "bolt.fill",
                                color: .yellow,
                                isDisconnected: isDisconnected,
                                labelFontSize: baseFontSize - 4,
                                valueFontSize: valueFontSize
                            )
                        }
                    }
                }
                .opacity(metrics.configStatus == .ready ? 1.0 : 0.2)
                .blur(radius: metrics.configStatus == .ready ? 0 : 3)
                
                // 送信中オーバーレイ
                if metrics.configStatus != .ready {
                    VStack(spacing: 8) {
                        switch metrics.configStatus {
                        case .resetting:
                            ProgressView()
                                .tint(Theme.accent)
                            Text("Resetting...".localized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        case .configuring:
                            ProgressView()
                                .tint(.orange)
                            Text("Configuring...".localized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        case .error(let msg):
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(msg)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                        default:
                            EmptyView()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isDisconnected ? 0.03 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDisconnected
                        ? Color.gray.opacity(0.25)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
        .cornerRadius(12)
        .opacity(isDisconnected ? 0.7 : 1.0)
    }
    
    /// 経過時間をミリ秒（小数点以下1桁）まで表示
    private func formatElapsedWithMs(seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let fraction = Int((seconds - Double(totalSeconds)) * 10)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d.%d", h, m, s, fraction)
        }
        return String(format: "%d:%02d.%d", m, s, fraction)
    }
    
    private func formatCompactTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    private func formatPace(seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:--" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Compact Metric View
struct CompactMetricView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    let isDisconnected: Bool
    var labelFontSize: CGFloat = 9
    var valueFontSize: CGFloat = 15
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: labelFontSize + 1))
                .foregroundColor(isDisconnected ? .gray : color)
                .frame(width: 14)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundColor(isDisconnected ? .gray.opacity(0.7) : Theme.textSecondary)
                Text(value)
                    .font(.system(size: valueFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(isDisconnected ? .gray : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(isDisconnected ? 0.02 : 0.04))
        .cornerRadius(8)
    }
}

// MARK: - Manager Mode Settings View
struct ManagerModeSettingsView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @Binding var showWorkoutSetup: Bool
    @Binding var showModeSettings: Bool
    
    @AppStorage("pm5DisplayMode") private var pm5DisplayMode: Int = 1
    @AppStorage("pm5GridColumns") private var pm5GridColumns: Int = 2
    @AppStorage("pm5ShowPace") private var pm5ShowPace: Bool = true
    @AppStorage("pm5ShowWatts") private var pm5ShowWatts: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("ワークアウト変更")) {
                    Button(action: {
                        showModeSettings = false
                        viewModel.resetAllDevices() // ワークアウト変更前に全デバイスを強制終了
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showWorkoutSetup = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("ワークアウトの内容を変更")
                        }
                    }
                }
                
                Section(header: Text("カードの表示サイズ")) {
                    Picker("サイズ", selection: $pm5DisplayMode) {
                        Text("小").tag(0)
                        Text("中").tag(1)
                        Text("大").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("表示個数 (列数)")) {
                    Picker("列数", selection: $pm5GridColumns) {
                        Text("1列 (リスト表示)").tag(1)
                        Text("2列 (グリッド)").tag(2)
                        Text("3列 (グリッド)").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("表示内容のカスタマイズ")) {
                    Toggle("ペース(500m)を表示", isOn: $pm5ShowPace)
                    Toggle("ワットを表示", isOn: $pm5ShowWatts)
                }
            }
            .navigationTitle("モード設定")
            .navigationBarItems(trailing: Button("完了") {
                showModeSettings = false
            })
        }
    }
}
