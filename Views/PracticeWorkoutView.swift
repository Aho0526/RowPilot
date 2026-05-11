import SwiftUI
import CoreLocation

struct PracticeWorkoutView: View {
    @ObservedObject var ergManager: RowErgManager
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showSaveAlert = false
    @State private var showRepeatAlert = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { showRepeatAlert = true }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .padding(8)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                    }
                    
                    Text("Practice Workout".localized.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(2)
                    
                    Spacer()
                    
                    Button(action: {
                        showSaveAlert = true
                    }) {
                        Text("Finish".localized.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Main Countdown / Progress
                        VStack(spacing: 8) {
                            if let targetDist = ergManager.targetDistance {
                                let remaining = max(targetDist - ergManager.distance, 0)
                                WorkoutBigMetric(label: "Remaining".localized, value: String(format: "%.0f", remaining), unit: "m", color: Theme.accent)
                            } else if let targetTime = ergManager.targetTime {
                                let remaining = max(targetTime - ergManager.elapsedTime, 0)
                                WorkoutBigMetric(label: "Remaining".localized, value: formatRemainingTime(remaining), unit: "", color: Theme.accent)
                            } else {
                                WorkoutBigMetric(label: "Distance".localized, value: String(format: "%.0f", ergManager.distance), unit: "m", color: Theme.accent)
                            }
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                        .background(Theme.cardBackground)
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        // Secondary Metrics Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            WorkoutMetricBox(label: "Pace".localized, value: formatPace(ergManager.pace500m), unit: "", color: Theme.secondaryAccent)
                            
                            // 距離指定の時は経過時間を表示、それ以外の時は漕いだ距離を表示
                            if ergManager.targetDistance != nil {
                                WorkoutMetricBox(label: "Time".localized, value: formatDuration(ergManager.elapsedTime), unit: "", color: .white)
                            } else {
                                WorkoutMetricBox(label: "Distance".localized, value: String(format: "%.0f", ergManager.distance), unit: "m", color: .white)
                            }
                            
                            WorkoutMetricBox(label: "SPM", value: "\(ergManager.strokeRate)", unit: "", color: Theme.accent)
                            WorkoutMetricBox(label: "Power".localized, value: "\(ergManager.power)", unit: "W", color: .orange)
                        }
                        
                        // Force Curve Visualization
                        if !ergManager.completedForceCurve.isEmpty {
                            ForceCurveView(ergManager: ergManager)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationBarHidden(true)
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
        .onChange(of: ergManager.isWorkoutFinished) { finished in
            if finished {
                showSaveAlert = true
            }
        }
    }
    
    // Helpers
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
            tags: ["PracticeMode", "Indoor"]
        )
        appViewModel.recordManager.addRecord(record)
    }
    
    private func formatPace(_ seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:--" }
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
    
    private func formatDurationShort(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }

    private func formatRemainingTime(_ seconds: Double) -> String {
        let totalSeconds = Int(ceil(seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct WorkoutBigMetric: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(1)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}

struct WorkoutMetricBox: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .tracking(1)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
