import SwiftUI

// MARK: - PracticeView
struct PracticeView: View {
    @EnvironmentObject var ergManager: RowErgManager
    @EnvironmentObject var app: AppViewModel
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingHelp = false
    @State private var showingSubscription = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        NavigationStack(path: $app.practiceNavigationPath) {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // MARK: - Connection Hub
                        ConnectionHubView(ergManager: ergManager)

                        // MARK: - Discovered Devices
                        if ergManager.connectionState == .disconnected && !ergManager.discoveredDevices.isEmpty {
                            DiscoveredDevicesPanel(ergManager: ergManager)
                        }

                        // MARK: - Workout Launch Grid
                        if ergManager.connectionState == .connected {
                            WorkoutLaunchGrid(ergManager: ergManager)
                        }

                        // MARK: - Plan Features Module (Manager Mode & Team Management)
                        ManagerModeModule(
                            currentPlan: currentPlan,
                            showingSubscription: $showingSubscription
                        )

                        if currentPlan.hasTeamFeature {
                            TeamManagementModule()
                        } else {
                            JoinTeamModule()
                        }

                        // MARK: - Research Module
                        ResearchModule(ergManager: ergManager)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .navigationDestination(for: String.self) { value in
                if value == "WorkoutSetupView" {
                    WorkoutSetupView(ergManager: ergManager)
                }
            }
            .onChange(of: ergManager.connectionState) { _, newState in
                if newState == .connected && ergManager.isNFCConnecting {
                    ergManager.isNFCConnecting = false
                    app.practiceNavigationPath.append("WorkoutSetupView")
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
                PracticeHelpView()
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }
}

// MARK: - Connection Hub View
struct ConnectionHubView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.5
    @State private var scanRingScale: CGFloat = 1.0
    @State private var scanRingOpacity: Double = 0.0
    @State private var isAnimating = false

    private var connectionColor: Color {
        switch ergManager.connectionState {
        case .connected: return .green
        case .connecting: return Theme.accent
        case .disconnected: return Theme.textSecondary.opacity(0.6)
        }
    }

    private var statusLabel: String {
        switch ergManager.connectionState {
        case .connected: return "Connected · RowErg".localized
        case .connecting: return "Connecting...".localized
        case .disconnected:
            if ergManager.isScanning { return "Scanning PM5".localized }
            return ergManager.isBluetoothPoweredOn ? "Bluetooth ON".localized : "Bluetooth OFF".localized
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Pulse Ring Indicator
            ZStack {
                // Outer Glow Ring (Animated)
                Circle()
                    .stroke(connectionColor.opacity(ringOpacity), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(ringScale)
                    .animation(
                        ergManager.connectionState == .connecting || ergManager.isScanning
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            : .default,
                        value: ringScale
                    )

                // Secondary Glow Ring
                Circle()
                    .stroke(connectionColor.opacity(scanRingOpacity), lineWidth: 1.5)
                    .frame(width: 140, height: 140)
                    .scaleEffect(scanRingScale)

                // Glass Inner Ring
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [connectionColor.opacity(0.6), connectionColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: connectionColor.opacity(0.4), radius: 16, x: 0, y: 0)

                // Core Icon
                VStack(spacing: 4) {
                    Image(systemName: connectionIcon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [connectionColor, connectionColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    if ergManager.isScanning {
                        ProgressView()
                            .tint(connectionColor)
                            .scaleEffect(0.7)
                    }
                }
            }
            .frame(height: 160)
            .onAppear { startRingAnimation() }
            .onChange(of: ergManager.connectionState) { _, _ in startRingAnimation() }
            .onChange(of: ergManager.isScanning) { _, _ in startRingAnimation() }

            // Status Label
            VStack(spacing: 6) {
                Text(statusLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(connectionColor)
                    .contentTransition(.numericText())

                if ergManager.connectionState == .connected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(ergManager.currentMachineState.description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if !ergManager.isBluetoothPoweredOn {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Bluetooth OFF".localized)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            // Action Buttons
            if ergManager.connectionState == .connected {
                Button(action: { ergManager.disconnect() }) {
                    Label("Disconnect".localized, systemImage: "minus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.75))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                }
            } else if ergManager.connectionState == .disconnected {
                HStack(spacing: 12) {
                    // BLE Scan Button
                    Button(action: {
                        if ergManager.isScanning {
                            ergManager.stopScanning()
                        } else {
                            ergManager.startScanning()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: ergManager.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                                .font(.subheadline)
                            Text(ergManager.isScanning ? "Stop Scan".localized : "Scan PM5".localized)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            ergManager.isBluetoothPoweredOn
                                ? Theme.primaryGradient
                                : LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(
                            color: ergManager.isBluetoothPoweredOn ? Theme.accent.opacity(0.3) : .clear,
                            radius: 8, x: 0, y: 4
                        )
                    }
                    .disabled(!ergManager.isBluetoothPoweredOn)

                    // NFC Button
                    if UIDevice.current.userInterfaceIdiom != .pad {
                        Button(action: { ergManager.startNFCScan() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "wave.3.right")
                                    .font(.subheadline)
                                Text("NFC".localized)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [connectionColor.opacity(0.4), connectionColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: connectionColor.opacity(0.15), radius: 20, x: 0, y: 8)
    }

    private var connectionIcon: String {
        switch ergManager.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .disconnected:
            return ergManager.isBluetoothPoweredOn ? "antenna.radiowaves.left.and.right" : "wifi.slash"
        }
    }

    private func startRingAnimation() {
        let isActive = ergManager.connectionState == .connecting || ergManager.isScanning

        if isActive {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                ringScale = 1.15
                ringOpacity = 0.8
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.4)) {
                scanRingScale = 1.2
                scanRingOpacity = 0.3
            }
        } else {
            withAnimation(.easeInOut(duration: 0.4)) {
                ringScale = 1.0
                ringOpacity = ergManager.connectionState == .connected ? 0.7 : 0.3
                scanRingScale = 1.0
                scanRingOpacity = 0.0
            }
        }
    }
}

// MARK: - Discovered Devices Panel
struct DiscoveredDevicesPanel: View {
    @ObservedObject var ergManager: RowErgManager

    var body: some View {
        RPModuleCard(
            title: "Discovered Devices".localized,
            icon: "antenna.radiowaves.left.and.right",
            accentColor: Theme.secondaryAccent
        ) {
            VStack(spacing: 10) {
                ForEach(ergManager.discoveredDevices, id: \.identifier) { device in
                    NavigationLink(destination: WorkoutSetupView(ergManager: ergManager)) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Theme.secondaryAccent.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "figure.rower")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.secondaryAccent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name ?? "Unknown Device")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.textMain)
                                Text("ID: \(device.identifier.uuidString.prefix(8))...")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Theme.secondaryAccent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.secondaryAccent.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.secondaryAccent.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        ergManager.connect(device)
                    })
                }
            }
        }
    }
}

// MARK: - Workout Launch Grid
struct WorkoutLaunchGrid: View {
    @ObservedObject var ergManager: RowErgManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.primaryGradient)
                Text("Workout Setup".localized)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textMain)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                WorkoutTypeCard(
                    title: "Single Distance".localized,
                    subtitle: "目標距離を設定",
                    icon: "arrow.right.to.line.alt",
                    gradient: [Theme.accent, Theme.secondaryAccent]
                ) {
                    SingleDistanceSetupView(ergManager: ergManager)
                }

                WorkoutTypeCard(
                    title: "Single Time".localized,
                    subtitle: "目標時間を設定",
                    icon: "clock.fill",
                    gradient: [Color(hex: "7B2FBE"), Color(hex: "4FACFE")]
                ) {
                    SingleTimeSetupView(ergManager: ergManager)
                }
            }

            NavigationLink(destination: WorkoutSetupView(ergManager: ergManager)) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Other Workouts (Workout List)".localized)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.4), Theme.secondaryAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Theme.accent.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Workout Type Card
struct WorkoutTypeCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let destination: () -> Destination

    @State private var isPressed = false

    init(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.25) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textMain)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [gradient.first!.opacity(0.5), gradient.last!.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: gradient.first!.opacity(0.2), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation { isPressed = true } }
                .onEnded { _ in withAnimation { isPressed = false } }
        )
    }
}

// MARK: - Manager Mode Module
struct ManagerModeModule: View {
    let currentPlan: SubscriptionPlan
    @Binding var showingSubscription: Bool

    var body: some View {
        RPModuleCard(
            title: "Manager Mode".localized,
            icon: "person.2.fill",
            accentColor: currentPlan.hasManagerMode ? .purple : Theme.textSecondary
        ) {
            if currentPlan.hasManagerMode {
                NavigationLink {
                    PM5ManagerView()
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "7B2FBE"), Color(hex: "C77DFF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Manager Mode Desc".localized)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(14)
                    .background(Color(hex: "7B2FBE").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "7B2FBE").opacity(0.25), lineWidth: 1)
                    )
                }
            } else {
                Button(action: { showingSubscription = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textSecondary.opacity(0.6))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Manager Mode Desc".localized)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)

                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9))
                                Text("Requires Manager Plan".localized)
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.4))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Research Module
struct ResearchModule: View {
    @ObservedObject var ergManager: RowErgManager

    var body: some View {
        RPModuleCard(
            title: "Research".localized,
            icon: "flask.fill",
            accentColor: .orange
        ) {
            NavigationLink {
                ResearchSandboxView(ergManager: ergManager)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: "flask.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("BLE Research Sandbox")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.textMain)
                        Text("Send experimental frames to 0021")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - RP Module Card (Reusable Container)
struct RPModuleCard<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let content: () -> Content

    init(
        title: String,
        icon: String,
        accentColor: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                // Accent line
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 18)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textMain)

                Spacer()
            }

            content()
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.12), accentColor.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accentColor.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Subcomponents (preserved)

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
            .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 16)
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

// MARK: - Join Team Module (Free & Pro Users)
struct JoinTeamModule: View {
    @State private var showingTeamJoinInput = false

    var body: some View {
        RPModuleCard(
            title: "Team Join".localized,
            icon: "person.3.fill",
            accentColor: .green
        ) {
            Button(action: { showingTeamJoinInput = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("チームに参加する".localized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.textMain)
                        Text("顧問から共有された招待コードを入力してチームに参加します。".localized)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingTeamJoinInput) {
                TeamInviteCodeInputView()
            }
        }
    }
}

// MARK: - Team Management Module (Team & MAX Users)
struct TeamManagementModule: View {
    var body: some View {
        RPModuleCard(
            title: "Team Management".localized,
            icon: "person.3.sequence.fill",
            accentColor: .blue
        ) {
            VStack(spacing: 12) {
                // 共有メンバーを管理 (TeamMaxManagerView)
                NavigationLink(destination: TeamMaxManagerView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("共有メンバーを管理".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.textMain)
                            Text("Managerプランをチームメンバーに共有します。".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // メンバーを管理 (TeamDashboardView)
                NavigationLink(destination: TeamDashboardView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("メンバーを管理".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.textMain)
                            Text("チームへの参加申請を管理し、練習記録を確認します。".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
            .glassCardStyle(glowColor: Theme.accent, opacity: 0.12, cornerRadius: 20)

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
        .glassCardStyle(glowColor: color, opacity: 0.08, cornerRadius: 16)
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

// MARK: - Practice Help View (QA Format)
struct PracticeHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Title/Intro
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.accent)
                                .padding(.bottom, 8)

                            Text("練習タブの使い方".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textMain)

                            Text("RowPilotの基本機能やPM5との通信方法についてのガイドです。".localized)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                        Group {
                            HelpSectionView(title: "1:1通信時 (シングルモード)".localized, icon: "iphone.and.arrow.forward") {
                                HelpStepView(step: "1", text: "「PM5をスキャン」を押します。".localized)
                                HelpStepView(step: "2", text: "PM5側でConnectボタンを押し、アプリの画面に表示されたPM5 ID（例: 430665873）と合致するものを選択します。".localized)
                                HelpStepView(step: "3", text: "画面が遷移し、単一距離か単一時間ワークアウトを指定後、それぞれの目標を対応レンジ内で設定し送信します。".localized)
                                HelpStepView(step: "4", text: "送信するとともにアプリ内の数値がPM5の画面と合致するので、任意のタイミングでワークアウト開始します。".localized)
                                HelpStepView(step: "5", text: "終了時に保存/破棄を選択し、ワークアウトを終了します。".localized)
                            }

                            HelpSectionView(title: "1:複数通信 (マネージャーモード)時".localized, icon: "person.3.fill") {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("※これを利用するにはRowPilot Managerのサブスクリプション登録が必要です。".localized)
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }

                                    HelpStepView(step: "1", text: "マネージャーモードを選択後、PM5をスキャンします。".localized)
                                    HelpStepView(step: "2", text: "使用する全てのPM5を接続可能状態にし、使用するPM5の全てを追加します。".localized)
                                    HelpStepView(step: "3", text: "「次へ→」を選択し、単一距離か単一時間ワークアウトを設定します。対応レンジ内で距離・時間を設定し送信します(送信台数に応じて少し時間がかかります)。".localized)
                                    HelpStepView(step: "4", text: "送信後、ダッシュボード画面に自動で遷移し全ての接続状況やワークアウト状況が見られます。".localized)
                                }
                            }
                        }

                        Group {
                            HelpSectionView(title: "各機能の解説".localized, icon: "switch.2") {
                                HelpFeatureItem(title: "「もう一度」ボタン".localized, icon: "arrow.counterclockwise") {
                                    Text("文字通り最初に設定したワークアウトを繰り返すことができます。押すとワークアウトを保存・破棄を選択し、自動的にPM5のリセット->ワークアウトの設定が完了します。".localized)
                                }

                                HelpFeatureItem(title: "「設定」ボタン".localized, icon: "gearshape.fill") {
                                    Text("ワークアウトの再設定や取得スピード（Hz）の設定変更ができます。強制的にPM5のワークアウト設定がリセットされるのでワークアウト中に操作しないようにしてください。".localized)
                                }

                                HelpFeatureItem(title: "「PM5設定」ボタン".localized, icon: "pencil.and.list.clipboard") {
                                    Text("PM5のカスタムネームや表示上の並び替えができます。ダッシュボードやレースビュー時に便利な機能です。".localized)
                                }

                                HelpFeatureItem(title: "レースビュー (MAXのみ)".localized, icon: "flag.checkered") {
                                    Text("ダッシュボード画面にてスマホを横倒しにするとレースをしているような見た目に変更することができます。2000mTTや練習でレース練習をする際におすすめです。".localized)
                                }
                            }
                        }
                        CreditSection(title: "問題が解決しない場合") {
                            NavigationLink(destination: HelpQA()) {
                                HStack {
                                    Text("QAコーナーに移る".localized)
                                        .foregroundColor(Theme.textMain)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Subviews for Practice Help
struct HelpSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Theme.accent)

                Text(title)
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.accent)
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06, cornerRadius: 16)
    }
}

struct HelpStepView: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.mainBackground)
                .frame(width: 24, height: 24)
                .background(Theme.accent)
                .clipShape(Circle())
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textMain)
                .lineSpacing(6)
        }
    }
}

struct HelpFeatureItem<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(Theme.textMain)
                    .frame(width: 20)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textMain)
            }

            VStack(alignment: .leading) {
                content
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(6)
            }
            .padding(.leading, 28)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
