import SwiftUI
import CoreLocation
import Charts
import Combine

struct WorkoutSplit: Identifiable {
    let id = UUID()
    let number: Int
    var time: Double
    var distance: Double
    var averagePace: Double
    var spm: Int
    var heartRate: String
}

struct PracticeWorkoutView: View {
    @ObservedObject var ergManager: RowErgManager
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free

    @State private var showSaveAlert = false
    @State private var showRepeatAlert = false
    @State private var showingActionMenu = false

    @State private var activeTab: Int = 1
    @State private var splits: [WorkoutSplit] = []
    
    // ゴーストレース用
    @State private var selectedGhostRecord: RowingRecord? = nil
    @State private var ghostTracker: GhostRaceTracker? = nil
    @State private var expandedSessionIds: Set<UUID> = []
    @State private var showingSubscriptionFromRace = false
    
    // ゴーストレース拡大・時間差用
    @State private var raceElapsedTime: TimeInterval = 0
    @State private var myFinishTime: TimeInterval? = nil
    @State private var ghostFinishTime: TimeInterval? = nil
    @State private var raceTimer: Timer? = nil

    // MARK: - Ghost Race Features
    @AppStorage("raceZoomEnabled") private var zoomEnabled: Bool = false
    @AppStorage("raceZoomDistanceBehind") private var zoomDistanceBehind: Double = 100
    @AppStorage("raceZoomMaxBoats") private var zoomMaxBoats: Int = 10
    @AppStorage("raceLaneLockEnabled") private var laneLockEnabled: Bool = false
    @AppStorage("racePacemakerEnabled") private var pacemakerEnabled: Bool = false
    @AppStorage("racePacemakerPaceString") private var paceString: String = "2:00.0"
    
    @State private var showPaceSettings = false
    @State private var showZoomSettings = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.background.ignoresSafeArea()

                // Ambient glow layer
                RadialGradient(
                    colors: [Theme.accent.opacity(0.04), .clear],
                    center: .center,
                    startRadius: 60,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.7
                )
                .ignoresSafeArea()

                TabView(selection: $activeTab) {
                    // Tab 0: Splits Table
                    splitsTableView(width: geometry.size.width, height: geometry.size.height)
                        .tag(0)

                    // Tab 1: 5-Metrics Grid (デフォルト)
                    fiveMetricsView(width: geometry.size.width, height: geometry.size.height)
                        .tag(1)

                    // Tab 2: Force Curve
                    graphView(width: geometry.size.width, height: geometry.size.height)
                        .tag(2)

                    // Tab 3: 3-Metrics Grid
                    threeMetricsView(width: geometry.size.width, height: geometry.size.height)
                        .tag(3)

                    // Tab 4: Many-Metrics Grid
                    manyMetricsView(width: geometry.size.width, height: geometry.size.height)
                        .tag(4)

                    // Tab 5: Ghost Race
                    ghostRaceView(width: geometry.size.width, height: geometry.size.height)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // === Fixed Menu Button (Top-Left) ===
                if !showingActionMenu {
                    VStack {
                        HStack {
                            RPMenuButton(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    showingActionMenu = true
                                }
                            })
                            .padding(.leading, 20)
                            .padding(.top, 20)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                // === Slide-in Left Drawer (Side Menu) ===
                if showingActionMenu {
                    // Dark background overlay
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showingActionMenu = false
                            }
                        }
                        .transition(.opacity)

                    // Drawer Panel
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            HStack {
                                Text("Workout Menu".localized)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showingActionMenu = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                        .padding(6)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.bottom, 8)

                            Divider()
                                .background(Color.white.opacity(0.1))

                            VStack(spacing: 12) {
                                // 繰り返すボタン
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showingActionMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                                        showRepeatAlert = true
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Repeat Workout".localized)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(Theme.textMain)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                }

                                // 終了ボタン
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showingActionMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                                        showSaveAlert = true
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Finish Workout".localized)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.red.opacity(0.12))
                                    .cornerRadius(10)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .frame(width: 260)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.leading, 12)
                        .padding(.vertical, 12)
                        .transition(.move(edge: .leading))

                        Spacer()
                    }
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear {
            setOrientation(.landscape)
            splits = [WorkoutSplit(number: 1, time: 0, distance: 0, averagePace: 0, spm: 0, heartRate: "-")]
        }
        .onDisappear {
            setOrientation(.portrait)
            stopRaceTimer()
        }
        .onChange(of: ergManager.distance) { oldValue, newValue in
            let targetDist = ergManager.targetDistance ?? (ghostTracker?.record.distance ?? 0)
            if newValue == 0 {
                splits = [WorkoutSplit(number: 1, time: 0, distance: 0, averagePace: 0, spm: 0, heartRate: "-")]
                raceElapsedTime = 0
                myFinishTime = nil
                ghostFinishTime = nil
                stopRaceTimer()
            } else {
                updateSplits()
                if targetDist > 0, newValue >= targetDist {
                    if myFinishTime == nil {
                        myFinishTime = raceElapsedTime
                        if let tracker = ghostTracker {
                            let ghostStatus = tracker.getStatus(at: raceElapsedTime)
                            if ghostStatus.distance < targetDist {
                                startRaceTimer()
                            } else {
                                ghostFinishTime = tracker.record.duration
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: ergManager.elapsedTime) { _, newValue in
            let targetDist = ergManager.targetDistance ?? (ghostTracker?.record.distance ?? 0)
            if targetDist > 0 {
                if ergManager.distance < targetDist {
                    raceElapsedTime = newValue
                }
            } else {
                raceElapsedTime = newValue
            }
            updateSplits()
        }
        .onChange(of: ergManager.isWorkoutFinished) { _, finished in
            // ワークアウト終了直後の自動保存アラートは廃止（退出時に選択させる）
        }
        .alert("Save Workout".localized, isPresented: $showSaveAlert) {
            Button("Save".localized) {
                saveCurrentRecord()
                ergManager.resetWorkout()
                ergManager.showingWorkoutExecution = false
                dismiss()
            }
            Button("Don't Save".localized, role: .destructive) {
                ergManager.resetWorkout()
                ergManager.showingWorkoutExecution = false
                dismiss()
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Would you like to save this workout as an indoor workout?".localized)
        }
        .alert("Repeat Workout".localized, isPresented: $showRepeatAlert) {
            Button("Save and Repeat".localized) {
                let dist = ergManager.targetDistance
                let time = ergManager.targetTime
                let calories = ergManager.targetCalories
                let split = dist != nil ? ergManager.targetSplitDistance : (time != nil ? ergManager.targetSplitTime : ergManager.targetSplitCalories)
                saveCurrentRecord()
                ergManager.resetAndStartWorkout(distance: dist, time: time, calories: calories, split: split)
            }
            Button("Discard and Repeat".localized, role: .destructive) {
                let dist = ergManager.targetDistance
                let time = ergManager.targetTime
                let calories = ergManager.targetCalories
                let split = dist != nil ? ergManager.targetSplitDistance : (time != nil ? ergManager.targetSplitTime : ergManager.targetSplitCalories)
                ergManager.resetAndStartWorkout(distance: dist, time: time, calories: calories, split: split)
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Would you like to save this workout record?".localized)
        }
        .sheet(isPresented: $showingSubscriptionFromRace) {
            NavigationStack {
                SubscriptionView()
            }
        }
    }

    // MARK: - Tab 0: Splits Table
    private func splitsTableView(width: CGFloat, height: CGFloat) -> some View {
        let totalWidth = width - 16
        let sidebarWidth = totalWidth * 0.3
        let tableWidth = totalWidth * 0.7

        let col1 = tableWidth * 0.11
        let col2 = tableWidth * 0.20
        let col3 = tableWidth * 0.20
        let col4 = tableWidth * 0.25
        let col5 = tableWidth * 0.15
        let col6 = tableWidth * 0.09

        return HStack(spacing: 0) {
            // Sidebar
            RPWorkoutSidebar(
                ergManager: ergManager,
                averagePace: averagePace500m,
                sidebarWidth: sidebarWidth
            )

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 12)

            // Table
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    RPTableHeaderCell(text: "番号".localized, width: col1)
                    RPTableHeaderCell(text: "時間".localized, width: col2)
                    RPTableHeaderCell(text: "メートル".localized, width: col3)
                    RPTableHeaderCell(text: "Ave./500m".localized, width: col4)
                    RPTableHeaderCell(text: "s/m".localized, width: col5)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                        )
                        .font(.system(size: 11))
                        .frame(width: col6)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Theme.accent.opacity(0.3))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Rows
                ScrollView {
                    VStack(spacing: 2) {
                        // Empty placeholder row
                        HStack(spacing: 0) {
                            RPTableCell(text: "-", width: col1)
                            RPTableCell(text: "-", width: col2)
                            RPTableCell(text: "-", width: col3)
                            RPTableCell(text: "-", width: col4)
                            RPTableCell(text: "-", width: col5)
                            RPTableCell(text: "-", width: col6)
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white.opacity(0.2))

                        ForEach(splits) { split in
                            let isCurrent = split.number == splits.count
                            HStack(spacing: 0) {
                                RPTableCell(text: "\(split.number)", width: col1)
                                RPTableCell(text: formatDurationSplits(split.time), width: col2)
                                RPTableCell(text: String(format: "%.0f", split.distance), width: col3)
                                RPTableCell(text: formatPaceSplits(split.averagePace), width: col4)
                                RPTableCell(text: "\(split.spm)", width: col5)
                                RPTableCell(text: split.heartRate, width: col6)
                            }
                            .padding(.vertical, 10)
                            .background(
                                isCurrent
                                    ? LinearGradient(
                                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.12)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.02), Color.white.opacity(0.02)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                            )
                            .overlay(
                                Rectangle()
                                    .fill(isCurrent ? Theme.accent : Color.white.opacity(0.05))
                                    .frame(width: 3),
                                alignment: .leading
                            )
                            .foregroundColor(isCurrent ? Theme.accent : .white)
                            .fontWeight(isCurrent ? .bold : .regular)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.trailing, 8)
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .padding(.top, 16)
    }

    // MARK: - Tab 1: 5-Metrics Grid
    private func fiveMetricsView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 10) {
            // Left column
            VStack(spacing: 10) {
                Spacer().frame(height: 36)
                RPMetricCard(
                    label: ergManager.targetDistance != nil ? "残り m" : "m",
                    value: formatDistance(ergManager.distance),
                    accentColor: Theme.secondaryAccent
                )
                RPMetricCard(
                    label: "s/m",
                    value: "\(ergManager.strokeRate)",
                    accentColor: .orange
                )
            }
            .frame(maxWidth: .infinity)

            // Center: Big Pace
            VStack(spacing: 10) {
                RPBigPaceCard(
                    pace: formatPace(ergManager.pace500m),
                    label: "/500 m",
                    accentColor: Theme.accent
                )

                HStack(spacing: 10) {
                    RPMetricCard(
                        label: "平均 / 500 m",
                        value: formatPace(averagePace500m),
                        accentColor: Theme.accent.opacity(0.7),
                        fontSize: 42
                    )
                    RPMetricCard(
                        label: "距離 m",
                        value: String(format: "%.0f", ergManager.distance),
                        accentColor: Theme.secondaryAccent.opacity(0.7),
                        fontSize: 42
                    )
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            // Right column
            VStack(spacing: 10) {
                Spacer().frame(height: 36)
                RPMetricCard(
                    label: "watts",
                    value: "\(ergManager.power)",
                    accentColor: Color(hex: "FFB300")
                )
                RPMetricCard(
                    label: "経過時間",
                    value: formatDurationNoMs(ergManager.elapsedTime),
                    accentColor: .purple
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 24)
    }

    // MARK: - Tab 2: Force Curve Graph
    private func graphView(width: CGFloat, height: CGFloat) -> some View {
        let totalWidth = width - 16
        let sidebarWidth = totalWidth * 0.3
        let graphAreaWidth = totalWidth * 0.7

        return HStack(spacing: 0) {
            // Sidebar
            RPWorkoutSidebar(
                ergManager: ergManager,
                averagePace: averagePace500m,
                sidebarWidth: sidebarWidth
            )

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 12)

            // Graph Area
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: 3, height: 14)
                    Text("Force Curve".localized)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                ZStack {
                    if currentPlan.hasForceCurve {
                        if !ergManager.completedForceCurve.isEmpty {
                            CompactForceCurveView(points: ergManager.completedForceCurve)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.accent.opacity(0.4))
                                Text("Start rowing to see force curve".localized)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    } else {
                        CompactLockedForceCurveView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.4), Theme.accent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Theme.accent.opacity(0.12), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: graphAreaWidth)
            .padding(.top, 8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .padding(.top, 16)
    }

    // MARK: - Tab 3: 3-Metrics Grid
    private func threeMetricsView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 10) {
                Spacer().frame(height: 36)
                RPMetricCard(
                    label: ergManager.targetDistance != nil ? "残り m" : "m",
                    value: formatDistance(ergManager.distance),
                    accentColor: Theme.secondaryAccent
                )
                RPMetricCard(
                    label: "s/m",
                    value: "\(ergManager.strokeRate)",
                    accentColor: .orange
                )
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                RPBigPaceCard(
                    pace: formatPace(ergManager.pace500m),
                    label: "/500 m",
                    accentColor: Theme.accent
                )

                HStack(spacing: 10) {
                    RPMetricCard(
                        label: "平均 / 500 m",
                        value: formatPace(averagePace500m),
                        accentColor: Theme.accent.opacity(0.7),
                        fontSize: 42
                    )
                    RPMetricCard(
                        label: "距離 m",
                        value: String(format: "%.0f", ergManager.distance),
                        accentColor: Theme.secondaryAccent.opacity(0.7),
                        fontSize: 42
                    )
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 260, maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 24)
    }

    // MARK: - Tab 4: Many-Metrics Grid
    private func manyMetricsView(width: CGFloat, height: CGFloat) -> some View {
        let calPerHour = Double(ergManager.power) * 4.0
        let totalCal: Double = ergManager.totalCalories > 0 ? ergManager.totalCalories : ((calPerHour / 3600.0) * ergManager.elapsedTime)
        let averageWattsValue: Int = ergManager.averagePower > 0 ? Int(ergManager.averagePower) : (ergManager.power > 0 ? Int(Double(ergManager.power) * 0.95) : 0)
        let speed = ergManager.pace500m > 0 ? (500.0 / ergManager.pace500m) : 0.0
        let projectedDist: Double = {
            if let targetDist = ergManager.targetDistance {
                return targetDist
            } else if let targetTime = ergManager.targetTime {
                return speed > 0 ? (ergManager.distance + speed * max(targetTime - ergManager.elapsedTime, 0)) : ergManager.distance
            }
            return speed > 0 ? (ergManager.distance + speed * max(1800.0 - ergManager.elapsedTime, 0)) : ergManager.distance
        }()
        let projectedElapsedTime: Double = {
            if let targetDist = ergManager.targetDistance, targetDist > 0 {
                if ergManager.projectedWorkTime > 0 {
                    return ergManager.projectedWorkTime
                } else {
                    return speed > 0 ? (ergManager.elapsedTime + (max(targetDist - ergManager.distance, 0) / speed)) : ergManager.elapsedTime
                }
            }
            return 0.0
        }()

        return HStack(spacing: 8) {
            VStack(spacing: 6) {
                Spacer().frame(height: 36)
                RPMetricCardCompact(label: ergManager.targetDistance != nil ? "残り m" : "m", value: formatDistance(ergManager.distance), accentColor: Theme.secondaryAccent)
                RPMetricCardCompact(label: "s/m", value: "\(ergManager.strokeRate)", accentColor: .orange)
                RPMetricCardCompact(label: "watts", value: "\(ergManager.power)", accentColor: Color(hex: "FFB300"))
                RPMetricCardCompact(label: "平均 watts", value: "\(averageWattsValue)", accentColor: Color(hex: "FFB300").opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                RPBigPaceCard(
                    pace: formatPace(ergManager.pace500m),
                    label: "/500 m",
                    accentColor: Theme.accent,
                    fontSize: 76
                )

                HStack(spacing: 8) {
                    RPMetricCardCompact(label: "平均 / 500 m", value: formatPace(averagePace500m), accentColor: Theme.accent.opacity(0.7))
                    RPMetricCardCompact(label: "距離 m", value: String(format: "%.0f", ergManager.distance), accentColor: Theme.secondaryAccent.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            VStack(spacing: 6) {
                Spacer().frame(height: 36)
                RPMetricCardCompact(label: "cal", value: String(format: "%.0f", totalCal), accentColor: .green)
                RPMetricCardCompact(label: "cal/hr", value: String(format: "%.0f", calPerHour), accentColor: .green.opacity(0.7))
                if ergManager.targetDistance != nil {
                    RPMetricCardCompact(label: "予想終了タイム", value: formatDurationNoMs(projectedElapsedTime), accentColor: .cyan)
                } else {
                    RPMetricCardCompact(label: "推定終了 m", value: String(format: "%.0f", projectedDist), accentColor: .cyan)
                }
                RPMetricCardCompact(label: "❤️", value: ergManager.heartRate > 0 ? "\(ergManager.heartRate)" : "---", accentColor: .red)
                RPMetricCardCompact(label: "ドラッグ", value: "\(ergManager.dragFactor)", accentColor: .purple)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Helper Methods
    private func formatDistance(_ dist: Double) -> String {
        if let targetDist = ergManager.targetDistance {
            return String(format: "%.0f", max(targetDist - dist, 0))
        }
        return String(format: "%.0f", dist)
    }

    private var averagePace500m: Double {
        guard ergManager.distance > 0 && ergManager.elapsedTime > 0 else { return 0 }
        return 500.0 / (ergManager.distance / ergManager.elapsedTime)
    }

    private func updateSplits() {
        let dist = ergManager.distance
        let time = ergManager.elapsedTime

        let isDistance = ergManager.targetDistance != nil
        let splitSize = isDistance
            ? Double(ergManager.targetSplitDistance ?? 500)
            : Double(ergManager.targetSplitTime ?? 120)

        guard splitSize > 0 else { return }

        let currentInterval = isDistance
            ? Int(dist / splitSize)
            : Int(time / splitSize)

        if splits.isEmpty {
            splits = [WorkoutSplit(number: 1, time: 0, distance: 0, averagePace: 0, spm: 0, heartRate: ergManager.heartRate > 0 ? "\(ergManager.heartRate)" : "-")]
        }

        while splits.count <= currentInterval {
            let prevIdx = splits.count - 1
            if prevIdx >= 0 {
                let prevTotalTime = splits.prefix(prevIdx).reduce(0.0) { $0 + $1.time }
                let prevTotalDist = splits.prefix(prevIdx).reduce(0.0) { $0 + $1.distance }

                if isDistance {
                    splits[prevIdx].distance = splitSize
                    splits[prevIdx].time = max(time - prevTotalTime, 0)
                } else {
                    splits[prevIdx].time = splitSize
                    splits[prevIdx].distance = max(dist - prevTotalDist, 0)
                }
                splits[prevIdx].averagePace = splits[prevIdx].distance > 0 ? (500.0 / (splits[prevIdx].distance / splits[prevIdx].time)) : 0
                splits[prevIdx].spm = ergManager.strokeRate
                splits[prevIdx].heartRate = ergManager.heartRate > 0 ? "\(ergManager.heartRate)" : "-"
            }

            splits.append(WorkoutSplit(
                number: splits.count + 1,
                time: 0,
                distance: 0,
                averagePace: 0,
                spm: 0,
                heartRate: ergManager.heartRate > 0 ? "\(ergManager.heartRate)" : "-"
            ))
        }

        let curIdx = splits.count - 1
        if curIdx >= 0 {
            let prevTotalTime = splits.prefix(curIdx).reduce(0.0) { $0 + $1.time }
            let prevTotalDist = splits.prefix(curIdx).reduce(0.0) { $0 + $1.distance }

            let curTime = max(time - prevTotalTime, 0)
            let curDist = max(dist - prevTotalDist, 0)

            splits[curIdx].time = curTime
            splits[curIdx].distance = curDist
            splits[curIdx].averagePace = curDist > 0 ? (500.0 / (curDist / curTime)) : 0
            splits[curIdx].spm = ergManager.strokeRate
            splits[curIdx].heartRate = ergManager.heartRate > 0 ? "\(ergManager.heartRate)" : "-"
        }
    }

    private func saveCurrentRecord() {
        let workoutType = ergManager.targetDistance != nil ? "distance" : (ergManager.targetTime != nil ? "time" : (ergManager.targetCalories != nil ? "calories" : "justRow"))
        let powerStr = ergManager.power > 0 ? "\(ergManager.power)W" : "N/A"
        let record = RowingRecord(
            date: Date(),
            duration: ergManager.elapsedTime,
            distance: ergManager.distance,
            averageSPM: ergManager.strokeRate,
            averageSpeed: (ergManager.distance / max(ergManager.elapsedTime, 1)) * 3.6,
            averagePace: ergManager.pace500m,
            notes: "Indoor Workout (Practice Mode) | Type: \(workoutType) | Power: \(powerStr)",
            tags: ["PracticeMode", "Indoor"],
            averageWatt: ergManager.power,
            dataPoints: ergManager.workoutDataPoints
        )
        appViewModel.recordManager.addRecord(record)
    }

    private func formatPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return ":00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", minutes, remainingSeconds)
    }

    private func formatDurationNoMs(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatDurationSplits(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }

    private func formatPaceSplits(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:--" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let ms = Int((seconds - Double(totalSeconds)) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }

    private func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientation
        #if os(iOS)
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
                    print("Failed to change orientation: \(error)")
                }
                for window in windowScene.windows {
                    window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        } else {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        #endif
    }
}

// MARK: - RP Workout Sidebar (新デザイン)
struct RPWorkoutSidebar: View {
    @ObservedObject var ergManager: RowErgManager
    let averagePace: Double
    var onMenuTap: (() -> Void)? = nil
    var sidebarWidth: CGFloat = 130
    var hideAveragePace: Bool = false

    // 進捗計算
    private var progress: Double {
        if let targetDist = ergManager.targetDistance, targetDist > 0 {
            return min(ergManager.distance / targetDist, 1.0)
        } else if let targetTime = ergManager.targetTime, targetTime > 0 {
            return min(ergManager.elapsedTime / targetTime, 1.0)
        } else if let targetCals = ergManager.targetCalories, targetCals > 0 {
            return min(ergManager.totalCalories / targetCals, 1.0)
        }
        return 0
    }

    private var hasTarget: Bool {
        ergManager.targetDistance != nil || ergManager.targetTime != nil || ergManager.targetCalories != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header: Progress only (Menu button is globally placed now)
            HStack(spacing: 8) {
                Spacer()
                if hasTarget {
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(Theme.accent.opacity(0.15), lineWidth: 3)
                            .frame(width: 26, height: 26)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 26, height: 26)
                            .rotationEffect(.degrees(-90))
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.system(size: 5, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .padding(.bottom, 2)

            // Metric boxes
            if !hideAveragePace {
                SidebarMetricBoxRP(value: formatDistance(ergManager.distance), unit: ergManager.targetDistance != nil ? "残り m" : "m", accentColor: Theme.secondaryAccent)
                SidebarMetricBoxRP(value: formatPace(ergManager.pace500m), unit: "/500 m", accentColor: Theme.accent)
                SidebarMetricBoxRP(value: formatPace(averagePace), unit: "平均/500m", accentColor: Theme.accent.opacity(0.6))
                SidebarMetricBoxRP(value: "\(ergManager.strokeRate)", unit: "s/m", accentColor: .orange)
            } else {
                SidebarMetricBoxRP(value: formatDistance(ergManager.distance), unit: ergManager.targetDistance != nil ? "残り m" : "m", accentColor: Theme.secondaryAccent, isLarge: true)
                SidebarMetricBoxRP(value: formatPace(ergManager.pace500m), unit: "/500 m", accentColor: Theme.accent, isLarge: true)
                SidebarMetricBoxRP(value: "\(ergManager.strokeRate)", unit: "s/m", accentColor: .orange, isLarge: true)
            }

            Spacer()
        }
        .frame(width: sidebarWidth)
        .padding(.leading, 6)
        .padding(.vertical, 6)
    }

    private func formatDistance(_ dist: Double) -> String {
        if let targetDist = ergManager.targetDistance {
            return String(format: "%.0f", max(targetDist - dist, 0))
        }
        return String(format: "%.0f", dist)
    }

    private func formatPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return ":00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - RP Big Pace Card
struct RPBigPaceCard: View {
    let pace: String
    let label: String
    let accentColor: Color
    var fontSize: CGFloat = 92

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text(pace)
                .font(.system(size: fontSize, weight: .black, design: .monospaced))
                .foregroundColor(Theme.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - RP Metric Card (通常サイズ)
struct RPMetricCard: View {
    let label: String
    let value: String
    let accentColor: Color
    var fontSize: CGFloat = 54

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: fontSize, weight: .black, design: .monospaced))
                .foregroundColor(Theme.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - RP Metric Card Compact
struct RPMetricCardCompact: View {
    let label: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(Theme.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)

            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}

// MARK: - Sidebar Metric Box (新デザイン)
struct SidebarMetricBoxRP: View {
    let value: String
    let unit: String
    let accentColor: Color
    var isLarge: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: isLarge ? 32 : 22, weight: .black, design: .monospaced))
                .foregroundColor(Theme.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)

            Text(unit)
                .font(.system(size: isLarge ? 12 : 9, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, isLarge ? 18 : 7)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - RP Menu Button
struct RPMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent, Theme.secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(7)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - RP Table Header Cell
struct RPTableHeaderCell: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(Theme.accent)
            .frame(width: width, alignment: .center)
    }
}

// MARK: - RP Table Cell
struct RPTableCell: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .frame(width: width, alignment: .center)
    }
}

// MARK: - 旧コンポーネント (互換性維持)
struct TableHeaderCell: View {
    let text: String
    let width: CGFloat
    var body: some View {
        RPTableHeaderCell(text: text, width: width)
    }
}

struct TableCell: View {
    let text: String
    let width: CGFloat
    var body: some View {
        RPTableCell(text: text, width: width)
    }
}

struct MenuButton: View {
    let action: () -> Void
    var body: some View {
        RPMenuButton(action: action)
    }
}

struct GridMetricBox: View {
    let label: String
    let value: String
    var body: some View {
        RPMetricCard(label: label, value: value, accentColor: Theme.accent)
    }
}

struct GridMetricBoxCompact: View {
    let label: String
    let value: String
    var body: some View {
        RPMetricCardCompact(label: label, value: value, accentColor: Theme.accent)
    }
}

struct SidebarMetricBox: View {
    let value: String
    let unit: String
    var body: some View {
        SidebarMetricBoxRP(value: value, unit: unit, accentColor: Theme.accent)
    }
}

struct SidebarView: View {
    @ObservedObject var ergManager: RowErgManager
    let averagePace: Double
    var onMenuTap: () -> Void
    var body: some View {
        RPWorkoutSidebar(ergManager: ergManager, averagePace: averagePace, sidebarWidth: 130)
    }
}

// MARK: - Force Curve Views
struct CompactForceCurveView: View {
    let points: [ForcePoint]

    var body: some View {
        let maxForce = points.map { $0.forceLbf }.max() ?? 0
        let maxTime = points.map { $0.timeRaw }.max() ?? 0

        let yLimit = max(50.0, Double(maxForce) * 1.2)
        let xLimit = max(0.1, maxTime * 1.1)

        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.timeRaw),
                y: .value("Force (lbf)", point.forceLbf)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.accent.opacity(0.85), Theme.accent.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Time", point.timeRaw),
                y: .value("Force (lbf)", point.forceLbf)
            )
            .foregroundStyle(Theme.accent)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...yLimit)
        .chartXScale(domain: 0...xLimit)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct CompactLockedForceCurveView: View {
    @State private var showingSubscription = false

    var body: some View {
        ZStack {
            Chart(mockCurvePoints) { point in
                AreaMark(
                    x: .value("Time", point.timeRaw),
                    y: .value("Force (lbf)", point.forceLbf)
                )
                .foregroundStyle(Theme.accent.opacity(0.3))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .blur(radius: 4)
            .padding(8)

            Color.black.opacity(0.2)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                }

                Text("Unlock Force Curve".localized)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            showingSubscription = true
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
    }

    private var mockCurvePoints: [ForcePoint] {
        (0...15).map { i in
            let x = Double(i) * 0.06
            let y = sin(Double(i) * Double.pi / 15.0) * 80.0
            return ForcePoint(timeRaw: x, forceLbf: Int(y))
        }
    }
}

extension PracticeWorkoutView {
    // MARK: - Tab 5: Ghost Race View
    @ViewBuilder
    private func ghostRaceView(width: CGFloat, height: CGFloat) -> some View {
        if currentPlan == .free {
            ghostLockedView(width: width, height: height)
        } else {
            ghostActiveView(width: width, height: height)
        }
    }

    private func ghostLockedView(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.3), radius: 10)
            
            Text("Ghost Race is Locked".localized)
                .font(.title2.bold())
                .foregroundColor(Theme.textMain)
            
            Text("Upgrade to Pro or above to race against your past indoor records in real-time.".localized)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingSubscriptionFromRace = true
            } label: {
                Text("Unlock Ghost Race".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Theme.primaryGradient)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 24)
    }

    private func ghostActiveView(width: CGFloat, height: CGFloat) -> some View {
        let totalWidth = width - 16
        let sidebarWidth = totalWidth * 0.3
        let contentAreaWidth = totalWidth * 0.7

        return HStack(spacing: 0) {
            // Sidebar
            RPWorkoutSidebar(
                ergManager: ergManager,
                averagePace: averagePace500m,
                sidebarWidth: sidebarWidth,
                hideAveragePace: true
            )

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .padding(.vertical, 12)

            // Content Area (Race Track or Ghost Selector)
            VStack(alignment: .leading, spacing: 8) {
                if let ghost = ghostTracker {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent)
                            .frame(width: 3, height: 14)
                        Text("Race View".localized)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                    ZStack {
                        ghostRaceTrackView(tracker: ghost, width: contentAreaWidth - 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.4), Theme.accent.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Theme.accent.opacity(0.12), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                } else {
                    ghostSelectorView(width: contentAreaWidth)
                }
            }
            .frame(width: contentAreaWidth)
            .padding(.top, 8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .padding(.top, 16)
    }

    private func ghostSelectorView(width: CGFloat) -> some View {
        let items = groupedIndoorRecords
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 3, height: 14)
                Text("Select Past Record for Race".localized)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.rower")
                        .font(.title)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    Text("No past indoor records found.".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            switch item {
                            case .individual(let record):
                                Button {
                                    selectGhostRecord(record)
                                } label: {
                                    HStack {
                                        Image(systemName: "figure.rower")
                                            .foregroundColor(Theme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formatDate(record.date))
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                            Text(String(format: "%.0fm (%.1f km/h) - %@", record.distance, record.averageSpeed, record.formattedDuration))
                                                .font(.subheadline.bold())
                                                .foregroundColor(Theme.textMain)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(Theme.accent)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                            case .session(let sessionId, let date, let sessionRecords):
                                let isExpanded = expandedSessionIds.contains(sessionId)
                                VStack(alignment: .leading, spacing: 4) {
                                    Button {
                                        withAnimation {
                                            if isExpanded {
                                                expandedSessionIds.remove(sessionId)
                                            } else {
                                                expandedSessionIds.insert(sessionId)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.3.fill")
                                                .foregroundColor(.purple)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(formatDate(date))
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                                Text("Manager Session (\(sessionRecords.count) devices)")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(Theme.textMain)
                                            }
                                            Spacer()
                                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.purple)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if isExpanded {
                                        VStack(spacing: 2) {
                                            ForEach(sessionRecords) { record in
                                                Button {
                                                    selectGhostRecord(record)
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "iphone.circle")
                                                            .foregroundColor(Theme.accent)
                                                            .padding(.leading, 12)
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(record.pm5CustomName ?? record.pm5SerialNumber ?? "Unknown Device")
                                                                .font(.subheadline.bold())
                                                                .foregroundColor(Theme.textMain)
                                                            Text(String(format: "%.0fm - %@", record.distance, record.formattedDuration))
                                                                .font(.caption)
                                                                .foregroundColor(Theme.textSecondary)
                                                        }
                                                        Spacer()
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption.weight(.bold))
                                                            .foregroundColor(Theme.accent)
                                                    }
                                                    .padding()
                                                    .background(Color.white.opacity(0.02))
                                                    .cornerRadius(8)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.leading, 8)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func ghostRaceTrackView(tracker: GhostRaceTracker, width: CGFloat) -> some View {
        let ghostStatus = tracker.getStatus(at: raceElapsedTime)
        let targetDist = ergManager.targetDistance ?? tracker.record.distance
        
        let nameColumnWidth: CGFloat = 130
        let rightInfoWidth: CGFloat = 120
        let trackWidth = width - nameColumnWidth - rightInfoWidth - 16
        
        let leaderDistance = max(ergManager.distance, ghostStatus.distance)
        let visibleRangeStart: Double
        let visibleRangeEnd: Double
        
        if zoomEnabled {
            let actualSpan = min(zoomDistanceBehind, targetDist)
            let frontMargin = actualSpan * 0.1
            let rangeEnd = min(leaderDistance + frontMargin, targetDist)
            let rangeStart = max(rangeEnd - actualSpan, 0)
            if rangeStart == 0 {
                visibleRangeStart = 0
                visibleRangeEnd = min(actualSpan, targetDist)
            } else {
                visibleRangeStart = rangeStart
                visibleRangeEnd = rangeEnd
            }
        } else {
            visibleRangeStart = 0
            visibleRangeEnd = targetDist
        }
        
        let displaySpan = visibleRangeEnd - visibleRangeStart
        let getProgress = { (dist: Double) -> Double in
            guard targetDist > 0 else { return 0 }
            if zoomEnabled {
                guard displaySpan > 0 else { return 0 }
                return min(max((dist - visibleRangeStart) / displaySpan, 0), 1.0)
            } else {
                return min(dist / targetDist, 1.0)
            }
        }
        
        let myProgress = getProgress(ergManager.distance)
        let ghostProgress = getProgress(ghostStatus.distance)
        
        let distanceDiff = ergManager.distance - ghostStatus.distance
        
        let laneHeight: CGFloat = 36
        let boatWidth: CGFloat = 28
        let boatHeight: CGFloat = 16
        let nameFont: Font = .system(size: 13, weight: .bold)
        let metricsFont: Font = .system(size: 13, weight: .bold, design: .monospaced)
        
        let isYouLeading = ergManager.distance >= ghostStatus.distance
        let lane1IsYou = laneLockEnabled ? true : isYouLeading
        
        // ペースメーカー
        let pmDist = getSmoothPacemakerDistance(at: raceElapsedTime)
        let pmProgress = getProgress(pmDist)
        
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Race with Past Self".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textMain)
                    Text(String(format: "Opponent: %@ (%.0fm)".localized, formatDateShort(tracker.record.date), tracker.record.distance))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Zoom & Pacemaker Controls
                    Button(action: { showPaceSettings = true }) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundColor(pacemakerEnabled ? Color(hex: "4FC3F7") : Theme.textSecondary)
                    }
                    .popover(isPresented: $showPaceSettings) {
                        PacemakerSettingsView()
                    }
                    
                    Button(action: { showZoomSettings = true }) {
                        Image(systemName: "ruler")
                            .font(.system(size: 14))
                            .foregroundColor(zoomEnabled ? Color(hex: "4FC3F7") : Theme.textSecondary)
                    }
                    .popover(isPresented: $showZoomSettings) {
                        ZoomSettingsView()
                    }
                    
                    // タイム差
                    if myFinishTime != nil || ghostFinishTime != nil || (ergManager.distance >= targetDist || ghostStatus.distance >= targetDist) {
                        HStack(spacing: 4) {
                            Text("Diff:".localized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            let diffStr = calculateTimeDifference()
                            Text(diffStr)
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(diffStr.hasPrefix("-") ? .green : .red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                    
                    // 変更ボタン
                    Button {
                        withAnimation {
                            selectedGhostRecord = nil
                            self.ghostTracker = nil
                            stopRaceTimer()
                            myFinishTime = nil
                            ghostFinishTime = nil
                            raceElapsedTime = 0
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Change".localized)
                        }
                        .font(.caption.bold())
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            
            Spacer(minLength: 8)
            
            // Lanes Area (Aligned to Absolute Center)
            VStack(spacing: 0) {
                // Scale header (Progress bar)
                raceScaleHeaderGhost(
                    trackWidth: trackWidth,
                    nameWidth: nameColumnWidth,
                    rightWidth: rightInfoWidth,
                    targetDistance: targetDist,
                    visibleRangeStart: visibleRangeStart,
                    visibleRangeEnd: visibleRangeEnd,
                    zoomEnabled: zoomEnabled
                )
                
                // Lane 1
                ghostLaneView(
                    isYou: lane1IsYou,
                    rank: lane1IsYou ? (isYouLeading ? 1 : 2) : (!isYouLeading ? 1 : 2),
                    progress: lane1IsYou ? myProgress : ghostProgress,
                    distanceDiff: lane1IsYou ? distanceDiff : -distanceDiff,
                    spm: lane1IsYou ? ergManager.strokeRate : ghostStatus.spm,
                    pace: lane1IsYou ? ergManager.pace500m : ghostStatus.pace,
                    trackWidth: trackWidth,
                    nameColumnWidth: nameColumnWidth,
                    rightInfoWidth: rightInfoWidth,
                    laneHeight: laneHeight,
                    boatWidth: boatWidth,
                    boatHeight: boatHeight,
                    nameFont: nameFont,
                    metricsFont: metricsFont,
                    pmProgress: pacemakerEnabled ? pmProgress : nil
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                // Lane 2
                ghostLaneView(
                    isYou: !lane1IsYou,
                    rank: !lane1IsYou ? (isYouLeading ? 1 : 2) : (!isYouLeading ? 1 : 2),
                    progress: !lane1IsYou ? myProgress : ghostProgress,
                    distanceDiff: !lane1IsYou ? distanceDiff : -distanceDiff,
                    spm: !lane1IsYou ? ergManager.strokeRate : ghostStatus.spm,
                    pace: !lane1IsYou ? ergManager.pace500m : ghostStatus.pace,
                    trackWidth: trackWidth,
                    nameColumnWidth: nameColumnWidth,
                    rightInfoWidth: rightInfoWidth,
                    laneHeight: laneHeight,
                    boatWidth: boatWidth,
                    boatHeight: boatHeight,
                    nameFont: nameFont,
                    metricsFont: metricsFont,
                    pmProgress: pacemakerEnabled ? pmProgress : nil
                )
                
                // 差分の表示
                let absDist = abs(distanceDiff)
                let ghostSpeed = ghostStatus.pace > 0 ? (500.0 / ghostStatus.pace) : 4.0
                let timeDiff = absDist / ghostSpeed
                
                HStack(spacing: 6) {
                    Text("Ghostとの差:".localized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(String(format: "%@%.1fs (%.1fm)", isYouLeading ? "+" : "-", timeDiff, absDist))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(isYouLeading ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
            }
            .padding(.bottom, 12)
            
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
    }

    private func ghostLaneView(
        isYou: Bool,
        rank: Int,
        progress: Double,
        distanceDiff: Double,
        spm: Int,
        pace: Double,
        trackWidth: CGFloat,
        nameColumnWidth: CGFloat,
        rightInfoWidth: CGFloat,
        laneHeight: CGFloat,
        boatWidth: CGFloat,
        boatHeight: CGFloat,
        nameFont: Font,
        metricsFont: Font,
        pmProgress: Double?
    ) -> some View {
        let isGold = rank == 1 && !laneLockEnabled
        let badgeColor = laneLockEnabled ? Color.white.opacity(0.3) : (rank == 1 ? Color(hex: "FFD700") : Color.white.opacity(0.3))
        let badgeTextColor = (rank == 1 && !laneLockEnabled) ? Color.black : Color.white
        let boatColor = laneLockEnabled ? (isYou ? Color(hex: "FFD700") : Color(hex: "4FC3F7")) : (rank == 1 ? Color(hex: "FFD700") : Color(hex: "4FC3F7"))
        
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(badgeTextColor)
                    .frame(width: 18, height: 18)
                    .background(badgeColor)
                    .cornerRadius(3)
                Text(isYou ? "You".localized : "Ghost".localized)
                    .font(nameFont)
                    .foregroundColor(isYou ? .white : .white.opacity(0.7))
            }
            .frame(width: nameColumnWidth, alignment: .leading)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: laneHeight)
                
                if let pmProgress = pmProgress {
                    let clamped = min(max(pmProgress, 0), 1.0)
                    let paceX = trackWidth * CGFloat(clamped)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: laneHeight)
                        .offset(x: paceX)
                        .zIndex(0)
                }
                
                let boatX = max((trackWidth - boatWidth) * CGFloat(progress), 0)
                BoatShape()
                    .fill(boatColor)
                    .frame(width: boatWidth, height: boatHeight)
                    .offset(x: boatX)
                    .animation(.linear(duration: 0.5), value: progress)
            }
            .frame(width: trackWidth, height: laneHeight)
            
            HStack(spacing: 8) {
                Text("\(spm)")
                    .font(metricsFont)
                    .foregroundColor(isYou ? .white : .white.opacity(0.7))
                    .frame(width: 24, alignment: .trailing)
                Text(formatPace(pace))
                    .font(metricsFont)
                    .foregroundColor(isYou ? .white : .white.opacity(0.7))
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: rightInfoWidth, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .background(isGold ? Color(hex: "FFD700").opacity(0.04) : Color.clear)
    }

    private func raceScaleHeaderGhost(
        trackWidth: CGFloat, nameWidth: CGFloat, rightWidth: CGFloat,
        targetDistance: Double, visibleRangeStart: Double, visibleRangeEnd: Double, zoomEnabled: Bool
    ) -> some View {
        let rangeSpan = visibleRangeEnd - visibleRangeStart
        let markerStep: Double
        if zoomEnabled {
            if rangeSpan <= 30 { markerStep = 5 }
            else if rangeSpan <= 60 { markerStep = 10 }
            else if rangeSpan <= 150 { markerStep = 25 }
            else if rangeSpan <= 300 { markerStep = 50 }
            else { markerStep = 100 }
        } else {
            markerStep = targetDistance / 5.0
        }
        
        let firstMarker = ceil(visibleRangeStart / markerStep) * markerStep
        var markers: [Double] = []
        var m = firstMarker
        while m <= visibleRangeEnd && m <= targetDistance {
            markers.append(m)
            m += markerStep
        }
        
        return HStack(spacing: 0) {
            Color.clear.frame(width: nameWidth)
            
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                ForEach(Array(markers.enumerated()), id: \.offset) { _, dist in
                    let normalizedProgress: CGFloat = zoomEnabled
                        ? (rangeSpan > 0 ? CGFloat((dist - visibleRangeStart) / rangeSpan) : 0)
                        : CGFloat(dist / targetDistance)
                    let xPos = trackWidth * normalizedProgress
                    
                    VStack(spacing: 0) {
                        Text("\(Int(targetDistance - dist))m")
                            .font(.system(size: zoomEnabled ? 10 : 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                            .padding(.bottom, 2)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 1, height: 4)
                    }
                    .frame(width: 40)
                    .offset(x: xPos - 20)
                }
            }
            .frame(width: trackWidth, height: 24)
            
            Color.clear.frame(width: rightWidth)
        }
        .frame(height: 24)
    }

    private func getSmoothPacemakerDistance(at elapsedTime: TimeInterval) -> Double {
        guard elapsedTime > 0 else { return 0 }
        let pace = pacemakerPaceSeconds
        guard pace > 0 else { return 0 }
        let distancePerSecond = 500.0 / pace
        return elapsedTime * distancePerSecond
    }
    
    private var pacemakerPaceSeconds: Double {
        let cleanStr = paceString.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleanStr.split(separator: ":")
        if parts.count == 2,
           let min = Double(parts[0]),
           let sec = Double(parts[1]) {
            return min * 60.0 + sec
        } else if parts.count == 1, let sec = Double(parts[0]) {
            return sec
        } else {
            return 120.0
        }
    }

    private func selectGhostRecord(_ record: RowingRecord) {
        withAnimation {
            self.selectedGhostRecord = record
            self.ghostTracker = GhostRaceTracker(record: record)
            self.raceElapsedTime = 0
            self.myFinishTime = nil
            self.ghostFinishTime = nil
            stopRaceTimer()
        }
    }
    
    private func startRaceTimer() {
        stopRaceTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                let targetDist = self.ergManager.targetDistance ?? (self.ghostTracker?.record.distance ?? 0)
                self.raceElapsedTime += 0.1
                
                if let tracker = self.ghostTracker {
                    let ghostStatus = tracker.getStatus(at: self.raceElapsedTime)
                    if ghostStatus.distance >= targetDist {
                        self.ghostFinishTime = self.raceElapsedTime
                        self.stopRaceTimer()
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.raceTimer = timer
    }
    
    private func stopRaceTimer() {
        raceTimer?.invalidate()
        raceTimer = nil
    }
    
    private func calculateTimeDifference() -> String {
        let myTime = myFinishTime ?? raceElapsedTime
        let ghostTime = ghostFinishTime ?? (ghostTracker?.record.duration ?? 0)
        let diff = myTime - ghostTime
        if diff < 0 {
            return String(format: "-%.1fs", -diff)
        } else {
            return String(format: "+%.1fs", diff)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    // Grouping structure for list
    private var groupedIndoorRecords: [GroupedRecordItem] {
        let records = appViewModel.recordManager.allRecords(filter: .indoor)
        var result: [GroupedRecordItem] = []
        
        var sessions: [UUID: [RowingRecord]] = [:]
        var individualRecords: [RowingRecord] = []
        
        for r in records {
            if let sessionId = r.managerSessionId {
                sessions[sessionId, default: []].append(r)
            } else {
                individualRecords.append(r)
            }
        }
        
        for (sessionId, sessionRecords) in sessions {
            if let first = sessionRecords.first {
                result.append(.session(id: sessionId, date: first.date, records: sessionRecords))
            }
        }
        
        for r in individualRecords {
            result.append(.individual(record: r))
        }
        
        return result.sorted { $0.date > $1.date }
    }

    enum GroupedRecordItem: Identifiable {
        case individual(record: RowingRecord)
        case session(id: UUID, date: Date, records: [RowingRecord])
        
        var id: String {
            switch self {
            case .individual(let r): return "ind-\(r.id.uuidString)"
            case .session(let id, _, _): return "sess-\(id.uuidString)"
            }
        }
        
        var date: Date {
            switch self {
            case .individual(let r): return r.date
            case .session(_, let d, _): return d
            }
        }
    }
}
