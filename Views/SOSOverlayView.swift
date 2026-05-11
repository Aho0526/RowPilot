import SwiftUI

struct SOSOverlayView: View {
    @Binding var isPresented: Bool
    var onTrigger: () -> Void
    
    @State private var isSOSPressing = false
    @State private var sosProgress: CGFloat = 0.0
    @State private var sosTimer: Timer?
    
    // UI Constants
    private let circleSize: CGFloat = 160
    private let innerCircleSize: CGFloat = 140
    private let holdDuration: Double = 1.5
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        cancelSOSPress()
                        isPresented = false
                    }
                }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: circleSize, height: circleSize)
                    
                    Circle()
                        .trim(from: 0, to: sosProgress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))
                    
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: innerCircleSize, height: innerCircleSize)
                            
                            Text("SOS")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isSOSPressing {
                                    startSOSPress()
                                }
                            }
                            .onEnded { _ in
                                cancelSOSPress()
                            }
                    )
                }
                
                Text(isSOSPressing ? "SOS_Press".localized : "SOS_Hold_1_5s".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .onDisappear {
            cancelSOSPress()
        }
    }
    
    private func startSOSPress() {
        isSOSPressing = true
        sosProgress = 0.0
        SoundManager.shared.startPressingSound()
        
        sosTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            sosProgress += 0.05 / holdDuration
            if sosProgress >= 1.0 {
                timer.invalidate()
                triggerSOS()
            }
        }
    }
    
    private func cancelSOSPress() {
        isSOSPressing = false
        sosProgress = 0.0
        sosTimer?.invalidate()
        sosTimer = nil
        SoundManager.shared.stopPressingSound()
    }
    
    private func triggerSOS() {
        cancelSOSPress()
        onTrigger()
        withAnimation {
            isPresented = false
        }
    }
}

#Preview {
    SOSOverlayView(isPresented: .constant(true), onTrigger: {})
}
