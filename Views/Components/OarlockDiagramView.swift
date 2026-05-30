import SwiftUI

struct OarlockDiagramView: View {
    let pitch: Double
    let lateralPitch: String
    let selectedField: BoatRiggingField?
    
    private var isPitchActive: Bool {
        selectedField == .pitch
    }
    
    private var isLateralPitchActive: Bool {
        selectedField == .lateralPitch
    }
    
    // Calculates lateral pitch angle based on bushing settings
    private var lateralPitchAngle: Double {
        if lateralPitch == "4/4" { return 0.0 }
        if lateralPitch == "5/3" { return 1.0 }
        if lateralPitch == "6/2" { return 2.0 }
        if lateralPitch == "7/1" { return 3.0 }
        if let val = Double(lateralPitch) { return val }
        return 0.0
    }
    
    // Bushing numbers to render
    private var bushingNumbers: (top: String, bottom: String) {
        switch lateralPitch {
        case "4/4": return ("4", "4")
        case "5/3": return ("5", "3")
        case "6/2": return ("6", "2")
        case "7/1": return ("7", "1")
        default: return ("4", "4")
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel: Pitch (Side View)
            pitchPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isPitchActive ? Theme.accent.opacity(0.04) : Color.clear)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Right Panel: Lateral Pitch (Rear View)
            lateralPitchPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isLateralPitchActive ? Theme.accent.opacity(0.04) : Color.clear)
        }
        .cornerRadius(12)
    }
    
    // MARK: - Pitch Panel (Sternward tilt)
    private var pitchPanel: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w * 0.5
            let cy = h * 0.68
            let pinLength: CGFloat = 76.0
            
            // In rowing, sternward pitch tilts the pin/oarlock towards the stern.
            // On screen, let's tilt left (representing sternward).
            let pitchRad = CGFloat(pitch) * .pi / 180.0
            
            let verticalTop = CGPoint(x: cx, y: cy - pinLength)
            
            let pinTopX = cx - pinLength * sin(pitchRad)
            let pinTopY = cy - pinLength * cos(pitchRad)
            let pinTop = CGPoint(x: pinTopX, y: pinTopY)
            
            ZStack {
                // Background reference grid
                Path { path in
                    path.move(to: CGPoint(x: 20, y: cy))
                    path.addLine(to: CGPoint(x: w - 20, y: cy))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                
                // True Vertical line (Reference)
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy + 15))
                    path.addLine(to: CGPoint(x: cx, y: cy - pinLength - 10))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                
                // Angle Dimension Arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: 65,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 - Double(pitch * 2.5)), // Scaled for clarity
                        clockwise: true
                    )
                }
                .stroke(isPitchActive ? Theme.accent : Color.gray.opacity(0.4), lineWidth: 1.5)
                
                // Tilted Pin (Oarlock Pin)
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy + 12))
                    path.addLine(to: pinTop)
                }
                .stroke(
                    LinearGradient(
                        colors: isPitchActive ? [Theme.accent, Theme.accent.opacity(0.6)] : [.gray, .gray.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                
                // Tilted Oarlock Body Profile (Side view C-shape)
                // The oarlock gate sits near the top of the pin. We place the centre
                // of the C-shape at 75% of the pin length from the base.
                let oarlockFrac: CGFloat = 0.75
                let oarlockCenterY = cy - pinLength * oarlockFrac * cos(pitchRad)
                let oarlockCenterX = cx - pinLength * oarlockFrac * sin(pitchRad)
                
                ZStack {
                    // Stylized C-shape oarlock gate
                    Path { path in
                        // C shape curving to the right
                        path.move(to: CGPoint(x: -8, y: -22))
                        path.addQuadCurve(to: CGPoint(x: 12, y: -16), control: CGPoint(x: 6, y: -24))
                        path.addLine(to: CGPoint(x: 14, y: 16))
                        path.addQuadCurve(to: CGPoint(x: -8, y: 22), control: CGPoint(x: 8, y: 24))
                        
                        // Inner contour
                        path.move(to: CGPoint(x: -4, y: -15))
                        path.addQuadCurve(to: CGPoint(x: 8, y: -10), control: CGPoint(x: 4, y: -16))
                        path.addLine(to: CGPoint(x: 8, y: 10))
                        path.addQuadCurve(to: CGPoint(x: -4, y: 15), control: CGPoint(x: 4, y: 16))
                    }
                    .stroke(isPitchActive ? Theme.accent : Color.gray, lineWidth: 2.0)
                    .background(
                        Path { path in
                            path.move(to: CGPoint(x: -8, y: -22))
                            path.addQuadCurve(to: CGPoint(x: 12, y: -16), control: CGPoint(x: 6, y: -24))
                            path.addLine(to: CGPoint(x: 14, y: 16))
                            path.addQuadCurve(to: CGPoint(x: -8, y: 22), control: CGPoint(x: 8, y: 24))
                            path.addLine(to: CGPoint(x: -4, y: 15))
                            path.addQuadCurve(to: CGPoint(x: 8, y: 10), control: CGPoint(x: 4, y: 16))
                            path.addLine(to: CGPoint(x: 8, y: -10))
                            path.addQuadCurve(to: CGPoint(x: -4, y: -15), control: CGPoint(x: 4, y: -16))
                            path.closeSubpath()
                        }
                        .fill(Color.black.opacity(0.45))
                    )
                    
                    // Locking Keeper Bar (Vertical bar on the back/gate)
                    Path { path in
                        path.move(to: CGPoint(x: -8, y: -18))
                        path.addLine(to: CGPoint(x: -8, y: 18))
                    }
                    .stroke(Color.gray.opacity(0.8), lineWidth: 1.5)
                    
                    // Bushing core
                    Circle()
                        .fill(Color(hex: "1A1A1A"))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 0.8))
                        .position(x: 0, y: 0)
                }
                .rotationEffect(.radians(Double(pitchRad)))
                .position(x: oarlockCenterX, y: oarlockCenterY)
                
                // Tilt angle text
                Text(String(format: "Pitch".localized + ": %.1f°", pitch))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(isPitchActive ? Theme.accent : Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.45).cornerRadius(4))
                    .position(x: pinTopX - 25, y: pinTopY - 12)
                
                // Panel Label
                Text("Pitch (Side View)".localized)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .position(x: w * 0.5, y: 15)
            }
        }
    }
    
    // MARK: - Lateral Pitch Panel (Rear view / Bushing Detail)
    private var lateralPitchPanel: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w * 0.5
            let cy = h * 0.68
            let pinLength: CGFloat = 76.0
            
            // Lateral pitch tilts pin inward/outward (left/right on screen)
            let latPitchRad = CGFloat(lateralPitchAngle) * .pi / 180.0
            
            let pinTopX = cx + pinLength * sin(latPitchRad)
            let pinTopY = cy - pinLength * cos(latPitchRad)
            let pinTop = CGPoint(x: pinTopX, y: pinTopY)
            
            ZStack {
                // Background reference grid
                Path { path in
                    path.move(to: CGPoint(x: 20, y: cy))
                    path.addLine(to: CGPoint(x: w - 20, y: cy))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                
                // True Vertical line (Reference)
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy + 15))
                    path.addLine(to: CGPoint(x: cx, y: cy - pinLength - 10))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                
                // Angle Dimension Arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: 65,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + Double(lateralPitchAngle * 3.5)), // Scaled for clarity
                        clockwise: false
                    )
                }
                .stroke(isLateralPitchActive ? Theme.accent : Color.gray.opacity(0.4), lineWidth: 1.5)
                
                // Tilted Pin (Oarlock Pin)
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy + 12))
                    path.addLine(to: pinTop)
                }
                .stroke(
                    LinearGradient(
                        colors: isLateralPitchActive ? [Theme.accent, Theme.accent.opacity(0.6)] : [.gray, .gray.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                
                // Bushing / Oarlock Zoomed-in structure (Rear View)
                // Place oarlock at 75% of pin length (near the top, where the gate is)
                let oarlockFrac: CGFloat = 0.75
                let oarlockCenterY = cy - pinLength * oarlockFrac * cos(latPitchRad)
                let oarlockCenterX = cx + pinLength * oarlockFrac * sin(latPitchRad)
                
                ZStack {
                    // Stylized rear-view oarlock outline
                    RoundedRectangle(cornerRadius: 3.5)
                        .stroke(isLateralPitchActive ? Theme.accent : Color.gray, lineWidth: 1.8)
                        .frame(width: 18, height: 32)
                        .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.black.opacity(0.45)))
                    
                    // Concept2 Bushing Insert (plastic sleeve inside the oarlock)
                    VStack(spacing: 0) {
                        // Top Bushing part
                        ZStack {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isLateralPitchActive ? Theme.accent.opacity(0.25) : Color(hex: "333333"))
                                .frame(width: 12, height: 11)
                                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color.gray.opacity(0.6), lineWidth: 0.8))
                            
                            Text(bushingNumbers.top)
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(isLateralPitchActive ? Theme.accent : .white)
                        }
                        
                        // Gap for pin washer
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 14, height: 4)
                        
                        // Bottom Bushing part
                        ZStack {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isLateralPitchActive ? Theme.accent.opacity(0.25) : Color(hex: "333333"))
                                .frame(width: 12, height: 11)
                                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color.gray.opacity(0.6), lineWidth: 0.8))
                            
                            Text(bushingNumbers.bottom)
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(isLateralPitchActive ? Theme.accent : .white)
                        }
                    }
                }
                .rotationEffect(.radians(Double(latPitchRad)))
                .position(x: oarlockCenterX, y: oarlockCenterY)
                
                // Tilt angle and bushing label text
                Text(String(format: "Lateral Pitch".localized + ": \(lateralPitch) (%.1f°)", lateralPitchAngle))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(isLateralPitchActive ? Theme.accent : Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.45).cornerRadius(4))
                    .position(x: pinTopX + 35, y: pinTopY - 12)
                
                // Panel Label
                Text("Lateral Pitch (Rear View)".localized)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .position(x: w * 0.5, y: 15)
            }
        }
    }
}
