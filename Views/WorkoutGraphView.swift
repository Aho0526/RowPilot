import SwiftUI
import Charts

struct WorkoutGraphView: View {
    let dataPoints: [WorkoutDataPoint]
    
    @State private var selectedMetric: MetricType = .pace
    
    enum MetricType: String, CaseIterable, Identifiable {
        case pace = "Pace"
        case spm = "SPM"
        case power = "Power"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases) { metric in
                        Text(metric.rawValue.localized).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if dataPoints.isEmpty {
                    Spacer()
                    Text("No detailed data available".localized)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average: \(formatValue(currentAverage))")
                            .font(.headline)
                            .foregroundColor(Theme.textMain)
                            .padding(.horizontal)
                        
                        chartView
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                }
                Spacer()
            }
        }
        .navigationTitle("Workout Details".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var baseChart: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timeOffset),
                    y: .value("Value", chartYValue(for: point))
                )
                .foregroundStyle(colorForMetric.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", point.timeOffset),
                    y: .value("Value", chartYValue(for: point))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [colorForMetric.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            
            if currentAverage > 0 {
                RuleMark(
                    y: .value("Average", selectedMetric == .pace ? -currentAverage : currentAverage)
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(colorForMetric)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let timeOffset = value.as(TimeInterval.self) {
                        Text(formatDuration(timeOffset))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        if selectedMetric == .pace {
                            Text(formatPace(-doubleValue))
                        } else {
                            Text("\(Int(doubleValue))")
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        if selectedMetric == .pace {
            baseChart
                .chartYScale(domain: paceYDomain)
                .frame(height: 300)
        } else {
            baseChart
                .chartYScale(domain: nonPaceYDomain)
                .frame(height: 300)
        }
    }
    
    // ペース用Yドメイン: 反転済み（-max-10 ... -min+10）
    private var paceYDomain: ClosedRange<Double> {
        let valid = dataPoints.map { $0.pace }.filter { $0 > 0 }
        guard let minVal = valid.min(), let maxVal = valid.max() else {
            return -200.0 ... -100.0
        }
        return -(maxVal + 10) ... -(minVal - 10)
    }
    
    // SPM/Power用Yドメイン: min-10 ... max+10
    private var nonPaceYDomain: ClosedRange<Double> {
        let valid = dataPoints.map { valueForMetric(point: $0) }.filter { $0 > 0 }
        guard let minVal = valid.min(), let maxVal = valid.max() else {
            return 0.0 ... 100.0
        }
        return (minVal - 10) ... (maxVal + 10)
    }
    
    private var currentAverage: Double {
        let valid = dataPoints.filter { valueForMetric(point: $0) > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.map { valueForMetric(point: $0) }.reduce(0, +) / Double(valid.count)
    }
    
    private func chartYValue(for point: WorkoutDataPoint) -> Double {
        let val = valueForMetric(point: point)
        return selectedMetric == .pace ? -val : val
    }
    
    private func valueForMetric(point: WorkoutDataPoint) -> Double {
        switch selectedMetric {
        case .pace: return point.pace
        case .spm: return Double(point.spm)
        case .power: return Double(point.power)
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .pace: return formatPace(value)
        case .spm: return "\(Int(value)) SPM"
        case .power: return "\(Int(value)) W"
        }
    }
    
    private var colorForMetric: Color {
        switch selectedMetric {
        case .pace: return Theme.secondaryAccent
        case .spm: return Theme.accent
        case .power: return .orange
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func formatPace(_ seconds: Double) -> String {
        if seconds <= 0 || seconds >= 600 { return "-:--" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
