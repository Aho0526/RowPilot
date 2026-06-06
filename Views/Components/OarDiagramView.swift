import SwiftUI

enum OarField {
    case totalLength
    case inboard
    case outboard
    case bladeType
    case sleevePitch
    case gripDiameter
}

struct OarDiagramView: View {
    let totalLength: Double
    let inboard: Double
    let bladeType: String
    let sleevePitch: Double
    let selectedField: OarField?
    
    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let centerY = h / 2
                
                // Boundaries of the oar drawing
                let oarStart: CGFloat = 35
                let oarEnd: CGFloat = w - 45
                let oarDrawLength = oarEnd - oarStart
                
                // Collar/button position relative to inboard / totalLength ratio
                let ratio = totalLength > 0 ? CGFloat(inboard / totalLength) : 0.3
                // Bound the ratio to prevent rendering out of bounds
                let boundedRatio = min(max(ratio, 0.15), 0.5)
                let collarX = oarStart + oarDrawLength * boundedRatio
                
                ZStack {
                    // MARK: - Dimension Lines (Background/Inactive or Active)
                    
                    // 1. Inboard Dimension Line (above the oar)
                    DimensionLine(
                        startX: oarStart,
                        endX: collarX,
                        y: centerY - 25,
                        label: String(format: "Inboard".localized + ": %.1f cm", inboard),
                        isActive: selectedField == .inboard,
                        arrowUp: true
                    )
                    
                    // 2. Outboard Dimension Line (below the oar)
                    DimensionLine(
                        startX: collarX,
                        endX: oarEnd,
                        y: centerY + 25,
                        label: String(format: "Outboard".localized + ": %.1f cm", max(0, totalLength - inboard)),
                        isActive: selectedField == .outboard,
                        arrowUp: false
                    )
                    
                    // 3. Total Length Dimension Line (further below or above, let's place it at centerY - 50)
                    DimensionLine(
                        startX: oarStart,
                        endX: oarEnd,
                        y: centerY - 50,
                        label: String(format: "Total Length".localized + ": %.1f cm", totalLength),
                        isActive: selectedField == .totalLength,
                        arrowUp: true
                    )
                    
                    // 4. Sleeve Pitch Angle Arc (above the collar)
                    if selectedField == .sleevePitch {
                        Path { path in
                            path.addArc(
                                center: CGPoint(x: collarX, y: centerY - 12),
                                radius: 10,
                                startAngle: .degrees(-180),
                                endAngle: .degrees(-180 + 20),
                                clockwise: false
                            )
                        }
                        .stroke(Theme.accent, lineWidth: 1.5)
                        
                        Text(String(format: "%.1f°", sleevePitch))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6).cornerRadius(3))
                            .position(x: collarX, y: centerY - 28)
                    }
                    
                    // MARK: - The Oar Drawing
                    
                    // A. Carbon Shaft (underneath collar and blade)
                    Path { path in
                        path.move(to: CGPoint(x: oarStart + 15, y: centerY))
                        path.addLine(to: CGPoint(x: oarEnd - 20, y: centerY))
                    }
                    .stroke(
                        selectedField == .totalLength ? Theme.accent : Color(hex: "333333"),
                        lineWidth: selectedField == .totalLength ? 4 : 2.5
                    )
                    .shadow(color: selectedField == .totalLength ? Theme.accent.opacity(0.5) : Color.clear, radius: 4)
                    
                    // B. Shaft highlight during total length or specific segment highlight
                    if selectedField == .inboard {
                        Path { path in
                            path.move(to: CGPoint(x: oarStart, y: centerY))
                            path.addLine(to: CGPoint(x: collarX, y: centerY))
                        }
                        .stroke(Theme.accent, lineWidth: 4)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 4)
                    }
                    
                    if selectedField == .outboard {
                        Path { path in
                            path.move(to: CGPoint(x: collarX, y: centerY))
                            path.addLine(to: CGPoint(x: oarEnd, y: centerY))
                        }
                        .stroke(Theme.accent, lineWidth: 4)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 4)
                    }
                    
                    // C. Handle/Grip (wood/rubber style at left)
                    Path { path in
                        let r = CGRect(x: oarStart, y: centerY - 4, width: 25, height: 8)
                        path.addRoundedRect(in: r, cornerSize: CGSize(width: 2, height: 2))
                    }
                    .fill(Color(hex: "D2B48C")) // Tan/Wood color
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(selectedField == .inboard || selectedField == .totalLength || selectedField == .gripDiameter ? Theme.accent : Color.brown, lineWidth: selectedField == .gripDiameter ? 2.5 : 1.5)
                    )
                    .shadow(color: selectedField == .gripDiameter ? Theme.accent.opacity(0.8) : Color.clear, radius: 4)
                    
                    // D. Sleeve & Collar (plastic sleeve around collarX)
                    // Sleeve (black cylinder)
                    Path { path in
                        let r = CGRect(x: collarX - 10, y: centerY - 3.5, width: 16, height: 7)
                        path.addRect(r)
                    }
                    .fill(selectedField == .sleevePitch ? Theme.accent : Color.black)
                    
                    // Collar/Button (orange or red collar)
                    Path { path in
                        let r = CGRect(x: collarX - 2, y: centerY - 6, width: 5, height: 12)
                        path.addRoundedRect(in: r, cornerSize: CGSize(width: 1, height: 1))
                    }
                    .fill(Color.orange)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(selectedField == .inboard || selectedField == .outboard || selectedField == .sleevePitch ? Theme.accent : Color.orange.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: selectedField == .sleevePitch ? Theme.accent.opacity(0.6) : Color.clear, radius: 4)
                    
                    // E. Blade (drawn based on chosen shape)
                    let path = bladePath(oarEnd: oarEnd, centerY: centerY, typeName: bladeType)
                    
                    path
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(hex: "EBF0F5")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            path
                                .stroke(selectedField == .bladeType || selectedField == .outboard || selectedField == .totalLength ? Theme.accent : Color.gray, lineWidth: selectedField == .bladeType ? 2.5 : 1.5)
                        )
                        .shadow(color: selectedField == .bladeType ? Theme.accent.opacity(0.6) : Color.clear, radius: 4)
                        
                    // F. Blade Ridge (Spine) for realistic depth
                    let ridge = bladeRidgePath(oarEnd: oarEnd, centerY: centerY, typeName: bladeType)
                    
                    ridge
                        .stroke(
                            Color.black.opacity(0.15),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                    
                    ridge
                        .stroke(
                            Color.white.opacity(0.7),
                            style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                        )
                }
            }
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.15))
            )
            
            // Description of active field
            if let desc = getHighlightDescription() {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Blade Path Helpers
        private func bladePath(oarEnd: CGFloat, centerY: CGFloat, typeName: String) -> Path {
        var path = Path()
        let type = typeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if type.contains("macon") {
            // Macon: symmetrical rounded tulip shape, but adapted slightly for stroke-side (slightly fuller bottom)
            let bladeLeft = oarEnd - 26
            path.move(to: CGPoint(x: bladeLeft, y: centerY - 0.5))
            
            // Upper curve (slightly narrower top edge for stroke-side look)
            path.addCurve(
                to: CGPoint(x: oarEnd + 4, y: centerY - 1.5),
                control1: CGPoint(x: bladeLeft + 4, y: centerY - 10.0),
                control2: CGPoint(x: oarEnd - 6, y: centerY - 10.0)
            )
            
            // Tip rounding
            path.addQuadCurve(
                to: CGPoint(x: oarEnd + 4, y: centerY + 2.0),
                control: CGPoint(x: oarEnd + 6.5, y: centerY + 0.5)
            )
            
            // Lower curve (slightly fuller bottom edge)
            path.addCurve(
                to: CGPoint(x: bladeLeft, y: centerY + 0.5),
                control1: CGPoint(x: oarEnd - 6, y: centerY + 14.0),
                control2: CGPoint(x: bladeLeft + 4, y: centerY + 12.0)
            )
            path.closeSubpath()
        } else if type.contains("comp") {
            // C2 Comp: short, extremely wide, asymmetrical curved square blade (stroke-side: narrow top, deep bottom)
            let bladeLeft = oarEnd - 20
            path.move(to: CGPoint(x: bladeLeft, y: centerY - 0.5))
            
            // Upper neck curve to shoulder (narrower top)
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 6, y: centerY - 9.0),
                control: CGPoint(x: bladeLeft + 6, y: centerY - 5.0)
            )
            
            // Top flat edge
            path.addLine(to: CGPoint(x: oarEnd + 4, y: centerY - 9.0))
            
            // Curved tip profile (very wide overall, extending deep below shaft)
            path.addQuadCurve(
                to: CGPoint(x: oarEnd + 5, y: centerY + 19.0),
                control: CGPoint(x: oarEnd + 6.0, y: centerY + 5.0)
            )
            
            // Bottom edge corner
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 3, y: centerY + 21.0),
                control: CGPoint(x: oarEnd + 2.0, y: centerY + 20.5)
            )
            
            // Bottom neck curve (deep asymmetrical swoop to collar)
            path.addCurve(
                to: CGPoint(x: bladeLeft, y: centerY + 0.5),
                control1: CGPoint(x: oarEnd - 10.0, y: centerY + 21.0),
                control2: CGPoint(x: bladeLeft + 5.0, y: centerY + 8.0)
            )
            path.closeSubpath()
        } else if type.contains("smoothie") {
            // Smoothie2: clean, asymmetrical cleaver blade (stroke-side: narrow top, deep flowing bottom)
            let bladeLeft = oarEnd - 28
            path.move(to: CGPoint(x: bladeLeft, y: centerY - 0.5))
            
            // Upper neck curve to shoulder (narrow top edge)
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 8, y: centerY - 8.0),
                control: CGPoint(x: bladeLeft + 10, y: centerY - 4.0)
            )
            
            // Top flat edge
            path.addLine(to: CGPoint(x: oarEnd + 6, y: centerY - 8.0))
            
            // Rounded tip
            path.addQuadCurve(
                to: CGPoint(x: oarEnd + 7, y: centerY + 16.0),
                control: CGPoint(x: oarEnd + 8.0, y: centerY + 4.0)
            )
            
            // Bottom edge corner (deep bottom curve)
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 2, y: centerY + 18.0),
                control: CGPoint(x: oarEnd + 4.0, y: centerY + 17.5)
            )
            
            // Bottom neck curve (flowing concave line back to collar)
            path.addCurve(
                to: CGPoint(x: bladeLeft, y: centerY + 0.5),
                control1: CGPoint(x: oarEnd - 12.0, y: centerY + 18.0),
                control2: CGPoint(x: bladeLeft + 8.0, y: centerY + 8.0)
            )
            path.closeSubpath()
        } else {
            // Other / Custom: beautiful generic hybrid aerodynamic blade (stroke-side orientation)
            let bladeLeft = oarEnd - 26
            path.move(to: CGPoint(x: bladeLeft, y: centerY - 0.5))
            
            // Upper neck curve to shoulder
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 8, y: centerY - 8.0),
                control: CGPoint(x: bladeLeft + 8, y: centerY - 4.5)
            )
            
            // Top edge
            path.addLine(to: CGPoint(x: oarEnd + 5, y: centerY - 8.0))
            
            // Soft rounded tip
            path.addQuadCurve(
                to: CGPoint(x: oarEnd + 6, y: centerY + 14.0),
                control: CGPoint(x: oarEnd + 7.0, y: centerY + 3.0)
            )
            
            // Bottom edge corner
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 3, y: centerY + 16.0),
                control: CGPoint(x: oarEnd + 2.0, y: centerY + 15.0)
            )
            
            // Bottom neck curve
            path.addCurve(
                to: CGPoint(x: bladeLeft, y: centerY + 0.5),
                control1: CGPoint(x: oarEnd - 11.0, y: centerY + 16.0),
                control2: CGPoint(x: bladeLeft + 7.0, y: centerY + 7.0)
            )
            path.closeSubpath()
        }
        return path
    }
    
    private func bladeRidgePath(oarEnd: CGFloat, centerY: CGFloat, typeName: String) -> Path {
        var path = Path()
        let type = typeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if type.contains("macon") {
            let bladeLeft = oarEnd - 26
            path.move(to: CGPoint(x: bladeLeft + 2.0, y: centerY + 0.5)) // Offset slightly down to match the fullness
            path.addQuadCurve(
                to: CGPoint(x: oarEnd + 2, y: centerY + 0.5),
                control: CGPoint(x: bladeLeft + 12.0, y: centerY + 1.2)
            )
        } else if type.contains("comp") {
            let bladeLeft = oarEnd - 20
            path.move(to: CGPoint(x: bladeLeft + 1.5, y: centerY))
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 3, y: centerY + 2.0), // Oriented slightly downwards matching bottom-heavy shape
                control: CGPoint(x: bladeLeft + 9.0, y: centerY + 0.8)
            )
        } else if type.contains("smoothie") {
            let bladeLeft = oarEnd - 28
            path.move(to: CGPoint(x: bladeLeft + 2.0, y: centerY))
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 1, y: centerY + 2.5), // Oriented downwards
                control: CGPoint(x: bladeLeft + 12.0, y: centerY + 1.0)
            )
        } else {
            let bladeLeft = oarEnd - 26
            path.move(to: CGPoint(x: bladeLeft + 2.0, y: centerY))
            path.addQuadCurve(
                to: CGPoint(x: oarEnd - 2, y: centerY + 2.0),
                control: CGPoint(x: bladeLeft + 10.0, y: centerY + 1.0)
            )
        }
        return path
    }
    
    private func getHighlightDescription() -> String? {
        guard let field = selectedField else { return nil }
        switch field {
        case .totalLength:
            return "Total Length Highlight Description".localized
        case .inboard:
            return "Inboard Highlight Description".localized
        case .outboard:
            return "Outboard Highlight Description".localized
        case .bladeType:
            return "Blade Type".localized + ": \(bladeType)"
        case .sleevePitch:
            return "Sleeve Pitch Highlight Description".localized
        case .gripDiameter:
            return "Grip Diameter Highlight Description".localized
        }
    }
}

// MARK: - Dimension Line Subview

struct DimensionLine: View {
    let startX: CGFloat
    let endX: CGFloat
    let y: CGFloat
    let label: String
    let isActive: Bool
    let arrowUp: Bool
    
    var body: some View {
        ZStack {
            // Horizontal line
            Path { path in
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
                
                // Left bracket
                path.move(to: CGPoint(x: startX, y: y - 4))
                path.addLine(to: CGPoint(x: startX, y: y + 4))
                
                // Right bracket
                path.move(to: CGPoint(x: endX, y: y - 4))
                path.addLine(to: CGPoint(x: endX, y: y + 4))
            }
            .stroke(isActive ? Theme.accent : Color.gray.opacity(0.5), lineWidth: isActive ? 2.0 : 1.0)
            
            // Arrows
            Path { path in
                // Left arrow
                path.move(to: CGPoint(x: startX + 5, y: y - 3))
                path.addLine(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: startX + 5, y: y + 3))
                
                // Right arrow
                path.move(to: CGPoint(x: endX - 5, y: y - 3))
                path.addLine(to: CGPoint(x: endX, y: y))
                path.addLine(to: CGPoint(x: endX - 5, y: y + 3))
            }
            .stroke(isActive ? Theme.accent : Color.gray.opacity(0.5), lineWidth: isActive ? 2.0 : 1.0)
            
            // Label Text
            Text(label)
                .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundColor(isActive ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, 6)
                .background(Color.black.opacity(0.5).cornerRadius(4))
                .position(x: (startX + endX) / 2, y: arrowUp ? y - 12 : y + 12)
        }
    }
}
