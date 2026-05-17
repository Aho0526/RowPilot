import SwiftUI
import Charts

struct ForceCurveView: View {
    @ObservedObject var ergManager: RowErgManager
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingSubscription = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Force Curve (Beta)")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal)
            
            ZStack {
                if currentPlan.hasForceCurve {
                    chartView(points: ergManager.completedForceCurve)
                } else {
                    chartView(points: mockCurvePoints)
                        .blur(radius: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.4))
                        )
                        .overlay(
                            lockOverlay
                        )
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }
    
    @ViewBuilder
    private func chartView(points: [ForcePoint]) -> some View {
        // Calculate dynamic scales with minimum bounds
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
    }
    
    private var lockOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundColor(Theme.accent)
                .padding(12)
                .background(Theme.accent.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            
            VStack(spacing: 4) {
                Text("Force Curve is Locked".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Upgrade to Pro to analyze your rowing form in real-time.".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Button(action: {
                showingSubscription = true
            }) {
                Text("Unlock Force Curve".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.mainBackground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .cornerRadius(20)
            }
            .padding(.top, 4)
        }
    }
    
    private var mockCurvePoints: [ForcePoint] {
        // Generate a beautiful, smooth bell-curve for visual locking presentation
        (0...20).map { i in
            let x = Double(i) * 0.05
            // Sin curve matching a real force curve shape
            let y = sin(Double(i) * Double.pi / 20.0) * 120.0
            return ForcePoint(timeRaw: x, forceLbf: Int(y))
        }
    }
}

