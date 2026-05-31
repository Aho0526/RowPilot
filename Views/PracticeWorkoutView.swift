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
    
    @State private var activeTab: Int = 1 // Default to 5-Metrics Grid (Tab 1)
    @State private var splits: [WorkoutSplit] = []
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let w = isPortrait ? geometry.size.height : geometry.size.width
            let h = isPortrait ? geometry.size.width : geometry.size.height
            
            ZStack {
                Theme.background.ignoresSafeArea()
                
                TabView(selection: $activeTab) {
                    // Tab 0: Splits Table (表画面)
                    splitsTableView(width: w, height: h)
                        .tag(0)
                    
                    // Tab 1: 5-Metrics Grid (5つのデータ)
                    fiveMetricsView(width: w, height: h)
                        .tag(1)
                    
                    // Tab 2: Force Curve Graph (ワークアウトグラフ)
                    graphView(width: w, height: h)
                        .tag(2)
                    
                    // Tab 3: 3-Metrics Grid (3つのデータ)
                    threeMetricsView(width: w, height: h)
                        .tag(3)
                    
                    // Tab 4: Many-Metrics Grid (多数のデータ)
                    manyMetricsView(width: w, height: h)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(width: w, height: h)
                .rotationEffect(isPortrait ? .degrees(90) : .degrees(0))
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear {
            setOrientation(.landscapeRight)
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
    
    // MARK: - Tab 0: Splits Table (表画面)
    private func splitsTableView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            SidebarView(ergManager: ergManager, averagePace: averagePace500m) {
                showingActionMenu = true
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TableHeaderCell(text: "番号".localized, width: 45)
                    TableHeaderCell(text: "時間".localized, width: 80)
                    TableHeaderCell(text: "メートル".localized, width: 80)
                    TableHeaderCell(text: "Ave./500m".localized, width: 105)
                    TableHeaderCell(text: "s/m".localized, width: 60)
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                        .frame(width: 35)
                }
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                
                ScrollView {
                    VStack(spacing: 1) {
                        HStack(spacing: 0) {
                            TableCell(text: "-", width: 45)
                            TableCell(text: "-", width: 80)
                            TableCell(text: "-", width: 80)
                            TableCell(text: "-", width: 105)
                            TableCell(text: "-", width: 60)
                            TableCell(text: "-", width: 35)
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white.opacity(0.3))
                        
                        ForEach(splits) { split in
                            HStack(spacing: 0) {
                                TableCell(text: "\(split.number)", width: 45)
                                TableCell(text: formatDurationSplits(split.time), width: 80)
                                TableCell(text: String(format: "%.0f", split.distance), width: 80)
                                TableCell(text: formatPaceSplits(split.averagePace), width: 105)
                                TableCell(text: "\(split.spm)", width: 60)
                                TableCell(text: split.heartRate, width: 35)
                            }
                            .padding(.vertical, 10)
                            .background(
                                split.number == splits.count 
                                ? Color(hex: "CDDC39").opacity(0.9) // Lime-Yellow
                                : Color.white.opacity(0.02)
                            )
                            .foregroundColor(split.number == splits.count ? .black : .white)
                            .fontWeight(split.number == splits.count ? .bold : .regular)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab 1: 5-Metrics Grid
    private func fiveMetricsView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    MenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
                
                GridMetricBox(label: "m", value: formatDistance(ergManager.distance))
                GridMetricBox(label: "s/m", value: "\(ergManager.strokeRate)")
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    Text(formatPace(ergManager.pace500m))
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    Text("/500 m")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                HStack(spacing: 8) {
                    GridMetricBox(label: "平均 / 500 m", value: formatPace(averagePace500m))
                    GridMetricBox(label: "m", value: String(format: "%.0f", ergManager.distance))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 200, maxWidth: .infinity)
            
            VStack(spacing: 8) {
                Spacer().frame(height: 20)
                GridMetricBox(label: "watts", value: "\(ergManager.power)")
                GridMetricBox(label: "/500 m", value: formatDurationNoMs(ergManager.elapsedTime))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab 2: Force Curve Graph (ワークアウトグラフ)
    private func graphView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            SidebarView(ergManager: ergManager, averagePace: averagePace500m) {
                showingActionMenu = true
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Force Curve".localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    
                ZStack {
                    if currentPlan.hasForceCurve {
                        if !ergManager.completedForceCurve.isEmpty {
                            CompactForceCurveView(points: ergManager.completedForceCurve)
                        } else {
                            Text("Start rowing to see force curve".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    } else {
                        CompactLockedForceCurveView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab 3: 3-Metrics Grid
    private func threeMetricsView(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    MenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
                
                GridMetricBox(label: "m", value: formatDistance(ergManager.distance))
                GridMetricBox(label: "s/m", value: "\(ergManager.strokeRate)")
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    Text(formatPace(ergManager.pace500m))
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    Text("/500 m")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                HStack(spacing: 8) {
                    GridMetricBox(label: "平均 / 500 m", value: formatPace(averagePace500m))
                    GridMetricBox(label: "m", value: String(format: "%.0f", ergManager.distance))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 260, maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab 4: Many-Metrics Grid
    private func manyMetricsView(width: CGFloat, height: CGFloat) -> some View {
        let calPerHour = Double(ergManager.power) * 4.0
        let totalCal = (calPerHour / 3600.0) * ergManager.elapsedTime
        let speed = ergManager.pace500m > 0 ? (500.0 / ergManager.pace500m) : 0.0
        
        let projectedDist: Double = {
            if let targetDist = ergManager.targetDistance {
                return targetDist
            } else if let targetTime = ergManager.targetTime {
                return speed > 0 ? (ergManager.distance + speed * max(targetTime - ergManager.elapsedTime, 0)) : ergManager.distance
            }
            return speed > 0 ? (ergManager.distance + speed * max(1800.0 - ergManager.elapsedTime, 0)) : ergManager.distance
        }()
        
        let dragFactor = ergManager.power > 0 ? 120 : 0
        
        return HStack(spacing: 8) {
            VStack(spacing: 6) {
                HStack {
                    MenuButton(action: { showingActionMenu = true })
                    Spacer()
                }
                
                GridMetricBoxCompact(label: "m", value: formatDistance(ergManager.distance))
                GridMetricBoxCompact(label: "s/m", value: "\(ergManager.strokeRate)")
                GridMetricBoxCompact(label: "watts", value: "\(ergManager.power)")
                GridMetricBoxCompact(label: "平均 watts", value: "\(ergManager.power > 0 ? Int(Double(ergManager.power) * 0.95) : 0)")
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    Text(formatPace(ergManager.pace500m))
                        .font(.system(size: 80, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    Text("/500 m")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                HStack(spacing: 6) {
                    GridMetricBoxCompact(label: "平均 / 500 m", value: formatPace(averagePace500m))
                    GridMetricBoxCompact(label: "m", value: String(format: "%.0f", ergManager.distance))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 200, maxWidth: .infinity)
            
            VStack(spacing: 6) {
                Spacer().frame(height: 16)
                GridMetricBoxCompact(label: "cal", value: String(format: "%.0f", totalCal))
                GridMetricBoxCompact(label: "cal/hr", value: String(format: "%.0f", calPerHour))
                GridMetricBoxCompact(label: "推定終了 m", value: String(format: "%.0f", projectedDist))
                GridMetricBoxCompact(label: "❤️", value: "---")
                GridMetricBoxCompact(label: "ドラッグファクター", value: "\(dragFactor)")
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
            splits = [WorkoutSplit(number: 1, time: 0, distance: 0, averagePace: 0, spm: 0, heartRate: "-")]
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
            }
            
            splits.append(WorkoutSplit(
                number: splits.count + 1,
                time: 0,
                distance: 0,
                averagePace: 0,
                spm: 0,
                heartRate: "-"
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
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
                print("Failed to change orientation: \(error)")
            }
        }
        #endif
    }
}

// MARK: - Supporting Subviews

struct TableHeaderCell: View {
    let text: String
    let width: CGFloat
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.textSecondary)
            .frame(width: width, alignment: .center)
    }
}

struct TableCell: View {
    let text: String
    let width: CGFloat
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .frame(width: width, alignment: .center)
    }
}

struct MenuButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

struct GridMetricBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
            
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct GridMetricBoxCompact: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
            
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Theme.cardBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SidebarView: View {
    @ObservedObject var ergManager: RowErgManager
    let averagePace: Double
    var onMenuTap: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                
                Button(action: {}) {
                    HStack(spacing: 3) {
                        Text("/500 m")
                            .font(.system(size: 9, weight: .bold))
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
            
            SidebarMetricBox(value: formatDistance(ergManager.distance), unit: "m")
            SidebarMetricBox(value: formatPace(ergManager.pace500m), unit: "/500 m")
            SidebarMetricBox(value: formatPace(averagePace), unit: "平均 / 500 m")
            SidebarMetricBox(value: "\(ergManager.strokeRate)", unit: "s/m")
            
            Spacer()
        }
        .frame(width: 125)
        .padding(.leading, 4)
        .padding(.vertical, 4)
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

struct SidebarMetricBox: View {
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
            
            Text(unit)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}

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
                    colors: [Theme.accent.opacity(0.8), Theme.accent.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
            
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.accent)
                    .padding(4)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Circle())
                
                Text("Unlock Force Curve".localized)
                    .font(.system(size: 10, weight: .bold))
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
