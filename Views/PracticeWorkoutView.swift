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
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
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
        }
        .onChange(of: ergManager.distance) { oldValue, newValue in
            if newValue == 0 {
                splits = [WorkoutSplit(number: 1, time: 0, distance: 0, averagePace: 0, spm: 0, heartRate: "-")]
            } else {
                updateSplits()
            }
        }
        .onChange(of: ergManager.elapsedTime) { _, _ in
            updateSplits()
        }
        .onChange(of: ergManager.isWorkoutFinished) { _, finished in
            if finished {
                showSaveAlert = true
            }
        }
        .confirmationDialog("Workout Menu".localized, isPresented: $showingActionMenu, titleVisibility: .visible) {
            Button("Finish Workout".localized, role: .destructive) {
                showSaveAlert = true
            }
            Button("Repeat Workout".localized) {
                showRepeatAlert = true
            }
            Button("Cancel".localized, role: .cancel) {}
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
                let split = dist != nil ? ergManager.targetSplitDistance : ergManager.targetSplitTime
                saveCurrentRecord()
                ergManager.resetAndStartWorkout(distance: dist, time: time, split: split)
            }
            Button("Discard and Repeat".localized, role: .destructive) {
                let dist = ergManager.targetDistance
                let time = ergManager.targetTime
                let split = dist != nil ? ergManager.targetSplitDistance : ergManager.targetSplitTime
                ergManager.resetAndStartWorkout(distance: dist, time: time, split: split)
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Would you like to save this workout record?".localized)
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
                onMenuTap: { showingActionMenu = true },
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
                HStack {
                    RPMenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
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
                onMenuTap: { showingActionMenu = true },
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
                HStack {
                    RPMenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
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
                HStack {
                    RPMenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
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
        let workoutType = ergManager.targetDistance != nil ? "distance" : (ergManager.targetTime != nil ? "time" : "justRow")
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
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
                print("Failed to change orientation: \(error)")
            }
        }
        UIViewController.attemptRotationToDeviceOrientation()
        #endif
    }
}

// MARK: - RP Workout Sidebar (新デザイン)
struct RPWorkoutSidebar: View {
    @ObservedObject var ergManager: RowErgManager
    let averagePace: Double
    var onMenuTap: () -> Void
    var sidebarWidth: CGFloat = 130

    // 進捗計算
    private var progress: Double {
        if let targetDist = ergManager.targetDistance, targetDist > 0 {
            return min(ergManager.distance / targetDist, 1.0)
        } else if let targetTime = ergManager.targetTime, targetTime > 0 {
            return min(ergManager.elapsedTime / targetTime, 1.0)
        }
        return 0
    }

    private var hasTarget: Bool {
        ergManager.targetDistance != nil || ergManager.targetTime != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header: Menu + Progress
            HStack(spacing: 8) {
                RPMenuButton(action: onMenuTap)
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
            SidebarMetricBoxRP(value: formatDistance(ergManager.distance), unit: ergManager.targetDistance != nil ? "残り m" : "m", accentColor: Theme.secondaryAccent)
            SidebarMetricBoxRP(value: formatPace(ergManager.pace500m), unit: "/500 m", accentColor: Theme.accent)
            SidebarMetricBoxRP(value: formatPace(averagePace), unit: "平均/500m", accentColor: Theme.accent.opacity(0.6))
            SidebarMetricBoxRP(value: "\(ergManager.strokeRate)", unit: "s/m", accentColor: .orange)

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
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .shadow(color: accentColor.opacity(0.5), radius: 16, x: 0, y: 0)
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.5), accentColor.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: accentColor.opacity(0.2), radius: 14, x: 0, y: 4)
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 0)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
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
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.4), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accentColor.opacity(0.1), radius: 6, x: 0, y: 2)
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .shadow(color: accentColor.opacity(0.25), radius: 6, x: 0, y: 0)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
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
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.35), accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accentColor.opacity(0.08), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Sidebar Metric Box (新デザイン)
struct SidebarMetricBoxRP: View {
    let value: String
    let unit: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 0)

            Text(unit)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
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
        RPWorkoutSidebar(ergManager: ergManager, averagePace: averagePace, onMenuTap: onMenuTap, sidebarWidth: 130)
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
