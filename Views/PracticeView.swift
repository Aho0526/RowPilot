import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var ergManager: RowErgManager
    @EnvironmentObject var app: AppViewModel
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingHelp = false    
    @State private var showingSubscription = false    
    var body: some View {
        NavigationStack(path: $app.practiceNavigationPath) {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - Connection Status
                        PracticeSection(title: "Connection Status".localized, icon: "antenna.radiowaves.left.and.right") {
                            HStack {
                                Text(ergManager.isBluetoothPoweredOn ? "Bluetooth ON".localized : "Bluetooth OFF".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(ergManager.isBluetoothPoweredOn ? .green : .red)
                                Spacer()
                                if ergManager.isScanning {
                                    ProgressView()
                                        .tint(Theme.accent)
                                }
                            }
                            
                            if ergManager.connectionState == .connected {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Connected: RowErg".localized)
                                        .foregroundColor(.green)
                                        .bold()
                                    
                                    HStack {
                                        Text("Machine State".localized)
                                            .foregroundColor(Theme.textSecondary)
                                        Spacer()
                                        Text(ergManager.currentMachineState.description)
                                            .foregroundColor(Theme.accent)
                                            .bold()
                                    }
                                    
                                    Button(action: {
                                        ergManager.disconnect()
                                    }) {
                                        Text("Disconnect".localized)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.red.opacity(0.8))
                                            .cornerRadius(8)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.top, 8)
                                
                            } else if ergManager.connectionState == .connecting {
                                Text("Connecting...".localized)
                                    .foregroundColor(Theme.accent)
                            } else {
                                HStack(spacing: 16) {
                                    Button(action: {
                                        if ergManager.isScanning {
                                            ergManager.stopScanning()
                                        } else {
                                            ergManager.startScanning()
                                        }
                                    }) {
                                        Text(ergManager.isScanning ? "Stop Scan".localized : "Scanning PM5".localized)
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(ergManager.isBluetoothPoweredOn ? Theme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                    .disabled(!ergManager.isBluetoothPoweredOn)
                                    
                                    Button(action: {
                                        ergManager.startNFCScan()
                                    }) {
                                        Label("NFC Connect".localized, systemImage: "wave.3.right")
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Theme.cardBackground)
                                            .foregroundColor(Theme.textMain)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1))
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        // MARK: - Discovered Devices
                        if ergManager.connectionState == .disconnected && !ergManager.discoveredDevices.isEmpty {
                            PracticeSection(title: "Discovered Devices".localized, icon: "rower") {
                                ForEach(ergManager.discoveredDevices, id: \.identifier) { device in
                                    NavigationLink(destination: WorkoutSetupView(ergManager: ergManager)) {
                                        HStack {
                                            Text(device.name ?? "Unknown Device")
                                                .foregroundColor(Theme.textMain)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(Theme.accent)
                                                .fontWeight(.bold)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        ergManager.connect(device)
                                    })
                                }
                            }
                        }
                        
                        
                        // MARK: - Workout Setup
                        if ergManager.connectionState == .connected {
                            PracticeSection(title: "Workout Setup".localized, icon: "gauge.with.needle") {
                                VStack(spacing: 16) {
                                    NavigationLink(destination: SingleDistanceSetupView(ergManager: ergManager)) {
                                        LargeWorkoutButton(title: "Single Distance".localized, icon: "arrow.right.to.line.alt")
                                    }
                                    
                                    NavigationLink(destination: SingleTimeSetupView(ergManager: ergManager)) {
                                        LargeWorkoutButton(title: "Single Time".localized, icon: "clock.fill")
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // MARK: - Manager Mode
                        PracticeSection(title: "Manager Mode".localized, icon: "person.2.fill") {
                            if currentPlan.hasManagerMode {
                                NavigationLink {
                                    PM5ManagerView()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Manager Mode Desc".localized)
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            } else {
                                Button(action: {
                                    showingSubscription = true
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Manager Mode Desc".localized)
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption2)
                                                Text("Requires Manager Plan".localized)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                            }
                                            .foregroundColor(Theme.accent)
                                        }
                                        Spacer()
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // MARK: - Research
                        PracticeSection(title: "Research".localized, icon: "flask.fill") {
                            NavigationLink {
                                ResearchSandboxView(ergManager: ergManager)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("BLE Research Sandbox")
                                            .foregroundColor(Theme.textMain)
                                            .fontWeight(.medium)
                                        Text("Send experimental frames to 0021")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        
                    }
                    .padding()
                }
            }
            .fullScreenCover(isPresented: $ergManager.showingWorkoutExecution) {
                PracticeWorkoutView(ergManager: ergManager)
            }
            .navigationTitle("Practice(Dev)".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PracticeHelpToolbarItem(showingHelp: $showingHelp)
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpView(
                    title: "Practice Help".localized,
                    content: """
    練習タブの使い方
        1:1通信時
            PM5をスキャンを押す
            PM5でconnectボタンを押し、接続したいPM5の画面上に出てきた番号(例:PM5 ID 430665873)と合致するものをアプリ上で選択。
            画面が遷移し、単一距離か単一時間ワークアウトを指定後、それぞれの目標を対応レンジ内で設定し送信。
            送信するとともにアプリ内の数値がPM5の画面と合致するので、任意のタイミングでワークアウト開始。
            終了時に保存/破棄を選択し、ワークアウトを終了する。


        1:複数通信(マネージャーモード)時
        ※これを利用するにはRowPilot Managerのサブスクリプション登録が必要です。
            マネージャーモードを選択後、PM5をスキャン。
            使用する全てのPM5を接続可能状態にし、使用するPM5の全てを追加する。
            "次へ→"を選択し、単一距離か単一時間ワークアウトを設定する。
            対応レンジ内で距離・時間を設定し送信(送信台数に応じて少し時間がかかります。)
            送信後、ダッシュボード画面に自動で遷移し全ての接続状況やワークアウト状況が見られます。

        "もう一度ボタン"
            文字通り最初に設定したワークアウトを繰り返すことができます。
            押すとワークアウトを保存・破棄を選択し、自動的にPM5のリセット->ワークアウトの設定が完了します。

        "モード設定ボタン"
            ワークアウトの再設定ができます。
            強制的にPM5のワークアウト設定がリセットされるのでワークアウト中に操作しないようにしてください。

        "PM5設定ボタン"
            PM5のカスタムネームや表示上の並び替えができます。
            ダッシュボードやレースビュー時に便利な機能です。

        ダッシュボード画面にてスマホを横倒しにするとレースをしているような見た目に変更することができます。(RowPilot MAXのみ)
        2000mTTや練習でレース練習をする際におすすめです。
    """
                )
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }
    
    // Helpers
    func formatPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:-- /500m" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d /500m", m, s)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let ms = Int((seconds - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%d", m, s, ms)
    }
}

// Subcomponents
struct PracticeSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }
}

struct MetricLine: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(Theme.textSecondary)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Theme.textMain)
        }
        .padding(.vertical, 2)
    }
}

struct ThemeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.primaryGradient)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    let app = AppViewModel()
    return PracticeView()
        .environmentObject(app)
        .environmentObject(app.ergManager)
        .environmentObject(app.pm5Manager)
}

// MARK: - Active Workout Components

struct ActiveWorkoutView: View {
    @ObservedObject var ergManager: RowErgManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Countdown / Progress
            HStack(spacing: 12) {
                if let targetDist = ergManager.targetDistance {
                    let remaining = max(targetDist - ergManager.distance, 0)
                    BigMetricView(label: "Remaining", value: String(format: "%.0f", remaining), unit: "m", color: Theme.accent)
                } else if let targetTime = ergManager.targetTime {
                    let remaining = max(targetTime - ergManager.elapsedTime, 0)
                    BigMetricView(label: "Remaining", value: formatDurationShort(remaining), unit: "", color: Theme.accent)
                } else {
                    BigMetricView(label: "Distance", value: String(format: "%.0f", ergManager.distance), unit: "m", color: Theme.accent)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(20)
            
            // Grid of Metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActiveMetricBox(label: "500m Pace", value: formatPace(ergManager.pace500m), color: Theme.secondaryAccent)
                ActiveMetricBox(label: "Time", value: formatDuration(ergManager.elapsedTime), color: .white)
                ActiveMetricBox(label: "SPM", value: "\(ergManager.strokeRate)", color: Theme.accent)
                ActiveMetricBox(label: "Power", value: "\(ergManager.power) W", color: .orange)
            }
        }
        .padding(.horizontal)
    }
    
    // Helpers
    private func formatPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:--" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func formatDurationShort(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BigMetricView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActiveMetricBox: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
}

struct PracticeHelpToolbarItem: View {
    @Binding var showingHelp: Bool
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        if settingsManager.settings.showHelpButtons {
            HelpCircleButton {
                showingHelp = true
            }
        } else {
            EmptyView()
        }
    }
}
