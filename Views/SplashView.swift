import SwiftUI

struct SplashView: View {
    @EnvironmentObject var app: AppViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8
    @State private var textOpacity = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var splashOpacity = 1.0
    @State private var splashScale = 1.0
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Background with Theme Gradient
            Theme.background
                .ignoresSafeArea()
            
            // Subtle ambient glow in the center
            RadialGradient(
                gradient: Gradient(colors: [Theme.accent.opacity(0.15), .clear]),
                center: .center,
                startRadius: 5,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Large Logo without Circle
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .shadow(color: Theme.accent.opacity(0.3), radius: 20, x: 0, y: 10)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale * (isPulsing ? 1.05 : 1.0))

                VStack(spacing: 12) {
                    Text("RowPilot")
                        .font(.system(size: 48, weight: .bold)) // Sharper font, no .rounded
                        .tracking(6)
                        .foregroundColor(.white)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("Navigate Your Performance".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(3)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .opacity(splashOpacity)
        .scaleEffect(splashScale)
        .onAppear {
            // Staggered Entrance Animation
            withAnimation(.easeOut(duration: 1.0)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                textOpacity = 1.0
                textOffset = 0
            }
            
            // Continuous Pulse Animation for the logo
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            
            // Transition to main app with smooth fade-out
            DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.splashDuration) {
                // Smooth fade out effect
                withAnimation(.easeIn(duration: 0.6)) {
                    splashOpacity = 0
                    splashScale = 1.1 // Slight expansion as it fades
                }
                
                // Final removal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    app.isSplashVisible = false
                }
            }
        }
    }
}
