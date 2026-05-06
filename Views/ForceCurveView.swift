import SwiftUI
import Charts

struct ForceCurveView: View {
    @ObservedObject var ergManager: RowErgManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Force Curve (Beta)")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal)
            
            // Calculate dynamic scales with minimum bounds
            let maxForce = ergManager.completedForceCurve.map { $0.forceLbf }.max() ?? 0
            let maxTime = ergManager.completedForceCurve.map { $0.timeRaw }.max() ?? 0
            
            let yLimit = max(50.0, Double(maxForce) * 1.2)
            let xLimit = max(0.1, maxTime * 1.1)
            
            Chart(ergManager.completedForceCurve) { point in
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
                .interpolationMethod(.catmullRom) // Smooths the curve nicely
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5])).foregroundStyle(.white.opacity(0.2))
                    AxisTick().foregroundStyle(.white.opacity(0.5))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.7))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5])).foregroundStyle(.white.opacity(0.2))
                    AxisTick().foregroundStyle(.white.opacity(0.5))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.7))
                }
            }
            .chartYScale(domain: 0...yLimit)
            .chartXScale(domain: 0...xLimit)
            .frame(height: 250)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }
}
