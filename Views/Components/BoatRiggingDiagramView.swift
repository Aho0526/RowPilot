import SwiftUI

enum BoatRiggingField {
    case span
    case workHeight
    case pitch
    case lateralPitch
    case footstretch
    case footplateAngle
    case footplateHeight
    case seatPosition
    case oarLength
    case oarInboard
    case oarGripDiameter
}

// MARK: - High-Tech Grid Pattern for CAD Feel
struct TechGridView: View {
    var glowColor: Color = Theme.accent
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let step: CGFloat = 16
                // Vertical lines
                for x in stride(from: 0, to: geo.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                // Horizontal lines
                for y in stride(from: 0, to: geo.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(glowColor.opacity(0.04), lineWidth: 0.8)
        }
    }
}

enum RiggingSide {
    case port
    case starboard
}

struct BoatRiggingDiagramView: View {
    let span: Double
    let workHeightPort: Double
    let workHeightStarboard: Double
    let pitchPort: Double
    let pitchStarboard: Double
    let lateralPitchPort: String
    let lateralPitchStarboard: String
    let footstretch: Double
    let footplateAngle: Double
    let footplateHeight: Double
    let oarTotalLengthPort: Double
    let oarTotalLengthStarboard: Double
    let oarInboardPort: Double
    let oarInboardStarboard: Double
    let oarGripDiameterPort: Double
    let oarGripDiameterStarboard: Double
    let oarType: OarType
    let riggerType: String  // "wing" or "straight"
    let selectedField: BoatRiggingField?
    let activeSide: RiggingSide
    @Binding var seatPosition: Double
    @Binding var currentTab: Int
    
    private var activeWorkHeight: Double {
        activeSide == .port ? workHeightPort : workHeightStarboard
    }
    
    private var activePitch: Double {
        activeSide == .port ? pitchPort : pitchStarboard
    }
    
    private var activeLateralPitch: String {
        activeSide == .port ? lateralPitchPort : lateralPitchStarboard
    }
    
    private var activeOarTotalLength: Double {
        activeSide == .port ? oarTotalLengthPort : oarTotalLengthStarboard
    }
    
    private var activeOarInboard: Double {
        activeSide == .port ? oarInboardPort : oarInboardStarboard
    }
    
    private var activeOarGripDiameter: Double {
        activeSide == .port ? oarGripDiameterPort : oarGripDiameterStarboard
    }
    
    @State private var dragRotationX: CGFloat = -15.0
    @State private var dragRotationY: CGFloat = 20.0
    @State private var previousRotationX: CGFloat = -15.0
    @State private var previousRotationY: CGFloat = 20.0
    @State private var userZoomFactor: CGFloat = 1.0
    @State private var pinchScale: CGFloat = 1.0
    
    @AppStorage("showAllRiggingValuesWhenIdle") private var showAllRiggingValuesWhenIdle: Bool = true
    @AppStorage("footstretchMeasurementMethod") private var footstretchMeasurementMethod: String = "fromHeel"
    @AppStorage("riggerDebugOverlay") private var riggerDebugOverlay: Bool = false
    
    // リガー位置調整値 (ユーザーの最終調整値に基づき、デフォルト値を固定化 - AppStorageで永続)
    @AppStorage("riggerPinYOffset_v4") private var riggerPinYOffset: Double = 13.3      // top-view ピンYオフセット(pt)
    @AppStorage("riggerBowOffset_v4") private var riggerBowOffset: Double = 77.7        // ボウ側アンカー（ピンからの相対）
    @AppStorage("riggerStrokeOffset_v4") private var riggerStrokeOffset: Double = -48.3 // ストローク側アンカー（ピンからの相対）
    @AppStorage("riggerPinZOffset") private var riggerPinZOffset: Double = 0.0      // 3DピンZオフセット
    @AppStorage("riggerXScaleFactor_v2") private var riggerXScaleFactor: Double = 0.78  // ピン近づき度 (0.4 - 1.2)
    
    // 調整モード状態
    @State private var isRiggerAdjustMode: Bool = false
    @State private var adjustTarget: AdjustTarget = .pin  // どの点を操作中か
    @State private var dragStartPinYOffset: Double = 13.3
    @State private var dragStartBowOffset: Double = 77.7
    @State private var dragStartStrokeOffset: Double = -48.3
    @State private var dragStartXScale: Double = 0.78
    
    enum AdjustTarget { case pin, bow, stroke }
    
    var body: some View {
        VStack(spacing: 14) {
            // View Selector Tab (Futuristic Glass Capsule Style)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { tabIndex in
                        let isSelected = currentTab == tabIndex
                        let tabTitle: String = {
                            switch tabIndex {
                            case 0: return "Top View".localized
                            case 1: return "Diagonal View".localized
                            default: return "Side View".localized
                            }
                        }()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                currentTab = tabIndex
                            }
                        }) {
                            Text(tabTitle)
                                .font(.caption2)
                                .fontWeight(isSelected ? .bold : .semibold)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Theme.primaryGradient)
                                                .shadow(color: Theme.accent.opacity(0.4), radius: 4, x: 0, y: 0)
                                        }
                                    }
                                )
                                .foregroundColor(isSelected ? .black : Theme.textSecondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                // デバッグトグルボタン
                Button(action: { riggerDebugOverlay.toggle() }) {
                    Image(systemName: "ant.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(riggerDebugOverlay ? .red : Theme.textSecondary.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 4)
            
            // Diagram Area
            ZStack {
                // High-tech telemetry grid background
                TechGridView(glowColor: Theme.accent)
                
                if currentTab == 0 {
                    topViewDiagram
                } else if currentTab == 1 {
                    diagonalViewDiagram
                } else {
                    if selectedField == .pitch || selectedField == .lateralPitch {
                        OarlockDiagramView(pitch: activePitch, lateralPitch: activeLateralPitch, selectedField: selectedField)
                    } else {
                        sideViewDiagram
                    }
                }
            }
            .frame(height: 200)
            .clipped()
            .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 16)
            
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
    
    // MARK: - Top View Diagram (Span, Footstretch, Footplate Angle)
    private var topViewDiagram: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            let centerlineX = w * 0.5
            let pinY = h * 0.42               // 固定基準（シート・シューズの基準点）
            let riggerPinY = pinY + CGFloat(riggerPinYOffset) // リガー描画専用のY座標
            let scale: CGFloat = 1.3
            let scaleX: CGFloat = scale * CGFloat(riggerXScaleFactor) // ピンを艇体に近づけるX軸のスケール（ユーザー調整可能）
            
            let isScull = oarType == .scull
            let halfSpanVal = isScull ? (span / 2.0) : span
            let halfSpanPts = CGFloat(halfSpanVal) * scaleX
            
            let pinRightX = centerlineX + halfSpanPts
            let pinLeftX = centerlineX - halfSpanPts
            
            let feetY = pinY - CGFloat(footstretch) * scale
            let seatY = pinY + CGFloat(seatPosition) * scale
            
            let hullHalfWidthVal: CGFloat = isScull ? 15.0 : 25.0
            let hullHalfWidth = hullHalfWidthVal * scale
            
            ZStack {
                // Centerline
                Path { path in
                    path.move(to: CGPoint(x: centerlineX, y: 10))
                    path.addLine(to: CGPoint(x: centerlineX, y: h - 10))
                }
                .stroke(Theme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
                
                Text("Centerline".localized)
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textSecondary.opacity(0.4))
                    .position(x: centerlineX - 30, y: 15)
                
                // Hull outline (Top View)
                Path { path in
                    // Left Side
                    path.move(to: CGPoint(x: centerlineX - hullHalfWidth, y: 10))
                    path.addQuadCurve(to: CGPoint(x: centerlineX - hullHalfWidth - 3, y: h - 10), control: CGPoint(x: centerlineX - hullHalfWidth - 6, y: h * 0.5))
                    // Right Side
                    path.move(to: CGPoint(x: centerlineX + hullHalfWidth, y: 10))
                    path.addQuadCurve(to: CGPoint(x: centerlineX + hullHalfWidth + 3, y: h - 10), control: CGPoint(x: centerlineX + hullHalfWidth + 6, y: h * 0.5))
                }
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                
                // Seat (Interactive dragging)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(selectedField == .seatPosition ? Theme.accent.opacity(0.35) : Color.white.opacity(0.1))
                        .frame(width: 34, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(selectedField == .seatPosition ? Theme.accent : Color.white.opacity(0.25), lineWidth: 1)
                        )
                    
                    Text("Seat".localized)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
                .position(x: centerlineX, y: seatY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPos = (value.location.y - pinY) / scale
                            seatPosition = max(0.0, min(60.0, Double(newPos)))
                        }
                )
                
                // Footplate Shoes (Foreshortened by Angle & aligned by measurement method)
                let angleRad = CGFloat(footplateAngle) * .pi / 180.0
                let shoeLen = max(6.0, 18.0 * cos(angleRad))
                let shoeDrawY = footstretchMeasurementMethod == "fromHeel" ? feetY - shoeLen / 2 : feetY
                
                HStack(spacing: 6) {
                    // Left Shoe
                    RoundedRectangle(cornerRadius: 2)
                        .fill(selectedField == .footplateAngle ? Theme.accent.opacity(0.25) : Color.white.opacity(0.08))
                        .frame(width: 8, height: shoeLen)
                        .rotationEffect(.degrees(-5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(selectedField == .footplateAngle ? Theme.accent : Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Right Shoe
                    RoundedRectangle(cornerRadius: 2)
                        .fill(selectedField == .footplateAngle ? Theme.accent.opacity(0.25) : Color.white.opacity(0.08))
                        .frame(width: 8, height: shoeLen)
                        .rotationEffect(.degrees(5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(selectedField == .footplateAngle ? Theme.accent : Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .position(x: centerlineX, y: shoeDrawY)
                .shadow(color: selectedField == .footplateAngle ? Theme.accent.opacity(0.3) : Color.clear, radius: 4)
                
                // Riggers (Top View)
                let riggerBowAnchorY = riggerPinY + CGFloat(riggerBowOffset)
                let riggerStrokeAnchorY = riggerPinY + CGFloat(riggerStrokeOffset)
                
                let wingColor = selectedField == .span ? Theme.accent : Color(hex: "D0D0D0")
                let stayColor = selectedField == .span ? Theme.accent : Color.white.opacity(0.4)
                let isWing = riggerType == "wing"
                
                if isScull {
                    if isWing {
                        // ウィングリガー: ピンから船体ボウ側に山型に捧るアーム + ストローク側ブレース
                        // ストローク側ブレース (細い線)
                        Path { path in
                            path.move(to: CGPoint(x: centerlineX - hullHalfWidth, y: riggerStrokeAnchorY))
                            path.addLine(to: CGPoint(x: pinLeftX, y: pinY))
                            path.move(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerStrokeAnchorY))
                            path.addLine(to: CGPoint(x: pinRightX, y: pinY))
                        }
                        .stroke(stayColor, lineWidth: 1.8)
                        
                        // メインアーム (太い線 - ピンからボウ側ガンネルへ)
                        Path { path in
                            path.move(to: CGPoint(x: pinLeftX, y: pinY))
                            path.addQuadCurve(
                                to: CGPoint(x: centerlineX - hullHalfWidth, y: riggerBowAnchorY),
                                control: CGPoint(x: pinLeftX + 25, y: riggerBowAnchorY)
                            )
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerBowAnchorY))
                            path.addQuadCurve(
                                to: CGPoint(x: pinRightX, y: pinY),
                                control: CGPoint(x: pinRightX - 25, y: riggerBowAnchorY)
                            )
                        }
                        .stroke(wingColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    } else {
                        // ストレートリガー: V字型ステー形状（ピンから前後2本のアーム）
                        Path { path in
                            // 左側
                            path.move(to: CGPoint(x: pinLeftX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX - hullHalfWidth, y: riggerStrokeAnchorY))
                            path.move(to: CGPoint(x: pinLeftX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX - hullHalfWidth, y: riggerBowAnchorY))
                            // 右側
                            path.move(to: CGPoint(x: pinRightX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerStrokeAnchorY))
                            path.move(to: CGPoint(x: pinRightX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerBowAnchorY))
                        }
                        .stroke(wingColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    }
                } else {
                    // スウィープ: 右側のみ
                    if isWing {
                        Path { path in
                            path.move(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerStrokeAnchorY))
                            path.addLine(to: CGPoint(x: pinRightX, y: pinY))
                        }
                        .stroke(stayColor, lineWidth: 1.8)
                        
                        Path { path in
                            path.move(to: CGPoint(x: centerlineX - hullHalfWidth, y: riggerBowAnchorY))
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerBowAnchorY))
                            path.addQuadCurve(
                                to: CGPoint(x: pinRightX, y: pinY),
                                control: CGPoint(x: pinRightX - 25, y: riggerBowAnchorY)
                            )
                        }
                        .stroke(wingColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    } else {
                        // スウィープ + ストレート: V字型ステー
                        Path { path in
                            path.move(to: CGPoint(x: pinRightX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerStrokeAnchorY))
                            path.move(to: CGPoint(x: pinRightX, y: pinY))
                            path.addLine(to: CGPoint(x: centerlineX + hullHalfWidth, y: riggerBowAnchorY))
                        }
                        .stroke(wingColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    }
                }
                
                // MARK: - デバッグオーバーレイ (Top View)
                if riggerDebugOverlay {
                    let debugLines: [(CGFloat, String, Color)] = [
                        (riggerPinY,          "pinYOfs=\(String(format:"%.1f",riggerPinYOffset))",  Color.yellow),
                        (riggerBowAnchorY,    "bowOfs=\(String(format:"%.1f",riggerBowOffset))",   Color.cyan),
                        (riggerStrokeAnchorY, "strkOfs=\(String(format:"%.1f",riggerStrokeOffset))", Color.orange),
                        (feetY,               "feetY=\(String(format:"%.0f",feetY))",             Color.green),
                        (seatY,               "seatY=\(String(format:"%.0f",seatY))",             Color.purple),
                    ]
                    ForEach(Array(debugLines.enumerated()), id: \.offset) { idx, item in
                        let (yVal, label, col) = item
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yVal))
                            path.addLine(to: CGPoint(x: w, y: yVal))
                        }
                        .stroke(col.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        Text(label)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(col)
                            .padding(.horizontal, 3)
                            .background(Color.black.opacity(0.7).cornerRadius(3))
                            .position(x: 55, y: yVal - 7)
                    }
                    Text("h=\(String(format:"%.0f",h)) riggerPinY/h=\(String(format:"%.2f",riggerPinY/h)) xScale=\(String(format:"%.2f",riggerXScaleFactor))")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.8).cornerRadius(3))
                        .position(x: w * 0.5, y: h - 8)
                }
                
                // MARK: - リガー調整モード UI
                if isRiggerAdjustMode {
                    // 調整モード指示バナー
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(LocalizationManager.shared.language == .japanese ? "リガー調整モード" : "Rigger Adjust")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.cornerRadius(6))
                    .position(x: w * 0.5, y: 14)
                    
                    // リセットボタン
                    Button(action: {
                        withAnimation(.spring()) {
                            riggerPinYOffset = 13.3
                            riggerBowOffset = 77.7
                            riggerStrokeOffset = -48.3
                            riggerXScaleFactor = 0.78
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red.opacity(0.8).cornerRadius(5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .position(x: w - 22, y: 14)
                    
                    // 完了ボタン
                    Button(action: { withAnimation(.spring()) { isRiggerAdjustMode = false } }) {
                        Text(LocalizationManager.shared.language == .japanese ? "完了" : "Done")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.accent.cornerRadius(6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .position(x: w - 22, y: 34)
                    
                    // ピン操作ハンドル (大きな黄色円)
                    Circle()
                        .fill(Color.yellow.opacity(0.35))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                        .overlay(
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.yellow)
                        )
                        .position(x: pinRightX + 18, y: riggerPinY)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    riggerPinYOffset = dragStartPinYOffset + Double(val.translation.height)
                                }
                                .onEnded { _ in
                                    dragStartPinYOffset = riggerPinYOffset
                                }
                        )
                        .simultaneousGesture(
                            TapGesture().onEnded { dragStartPinYOffset = riggerPinYOffset }
                        )
                    
                    // ボウ側アンカーハンドル
                    Circle()
                        .fill(Color.cyan.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.cyan, lineWidth: 1.5))
                        .overlay(
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.cyan)
                        )
                        .position(x: centerlineX + hullHalfWidth + 18, y: riggerBowAnchorY)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    riggerBowOffset = dragStartBowOffset + Double(val.translation.height)
                                }
                                .onEnded { _ in
                                    dragStartBowOffset = riggerBowOffset
                                }
                        )
                    
                    // ストローク側アンカーハンドル
                    Circle()
                        .fill(Color.orange.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
                        .overlay(
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.orange)
                        )
                        .position(x: centerlineX + hullHalfWidth + 18, y: riggerStrokeAnchorY)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    riggerStrokeOffset = dragStartStrokeOffset + Double(val.translation.height)
                                }
                                .onEnded { _ in
                                    dragStartStrokeOffset = riggerStrokeOffset
                                }
                        )
                    
                    // スパン幅（左右近づき度）調整ハンドル (紫色)
                    Circle()
                        .fill(Color.purple.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.purple, lineWidth: 1.5))
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.purple)
                        )
                        .position(x: pinRightX, y: riggerPinY - 18)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let deltaX = Double(val.translation.width)
                                    let divisor = Double(halfSpanVal) > 0 ? (Double(halfSpanVal) * 1.3) : 100.0
                                    let newScale = dragStartXScale + deltaX / divisor
                                    riggerXScaleFactor = max(0.4, min(1.3, newScale))
                                }
                                .onEnded { _ in
                                    dragStartXScale = riggerXScaleFactor
                                }
                        )
                        .simultaneousGesture(
                            TapGesture().onEnded { dragStartXScale = riggerXScaleFactor }
                        )
                    
                    // 操作説明ラベル
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Circle().fill(Color.yellow).frame(width: 6, height: 6)
                            Text(LocalizationManager.shared.language == .japanese ? "ピン：上下ドラッグ" : "Pin: drag up/down")
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Color.cyan).frame(width: 6, height: 6)
                            Text(LocalizationManager.shared.language == .japanese ? "ボウアーム" : "Bow arm")
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text(LocalizationManager.shared.language == .japanese ? "ストロークアーム" : "Stroke arm")
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Color.purple).frame(width: 6, height: 6)
                            Text(LocalizationManager.shared.language == .japanese ? "左右幅：左右ドラッグ" : "Width: drag left/right")
                        }
                    }
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.75).cornerRadius(6))
                    .position(x: 48, y: h - 31)
                }
                
                // Pins (リガー位置に従って絵画)
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(selectedField == .span || selectedField == .footstretch ? Theme.accent : Color.gray, lineWidth: 1.5))
                    .position(x: pinRightX, y: riggerPinY)
                
                if isScull {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().stroke(selectedField == .span || selectedField == .footstretch ? Theme.accent : Color.gray, lineWidth: 1.5))
                        .position(x: pinLeftX, y: riggerPinY)
                }
                
                // MARK: - Dimension Lines (Top View)
                if selectedField == .span || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isSpanActive = selectedField == .span
                    if isScull {
                        DimensionLine(
                            startX: pinLeftX,
                            endX: pinRightX,
                            y: riggerPinY - 18,
                            label: String(format: "Span".localized + ": %.1f cm", span),
                            isActive: isSpanActive,
                            arrowUp: true
                        )
                    } else {
                        DimensionLine(
                            startX: centerlineX,
                            endX: pinRightX,
                            y: riggerPinY - 18,
                            label: String(format: "Spread".localized + ": %.1f cm", span),
                            isActive: isSpanActive,
                            arrowUp: true
                        )
                    }
                }
                
                if selectedField == .footstretch || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isFSActive = selectedField == .footstretch
                    let fsColor = isFSActive ? Theme.accent : Color.gray.opacity(0.5)
                    
                    // Pin-to-pin line (horizontal axis - 固定基準点pinYを使用)
                    Path { path in
                        path.move(to: CGPoint(x: pinLeftX, y: pinY))
                        path.addLine(to: CGPoint(x: pinRightX, y: pinY))
                    }
                    .stroke(fsColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    
                    // Shoe reference line (horizontal axis)
                    Path { path in
                        path.move(to: CGPoint(x: centerlineX - 35, y: feetY))
                        path.addLine(to: CGPoint(x: centerlineX + 35, y: feetY))
                    }
                    .stroke(fsColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    
                    // Vertical lines extending from shoes straight up to the pin line
                    Path { path in
                        path.move(to: CGPoint(x: centerlineX - 8, y: feetY))
                        path.addLine(to: CGPoint(x: centerlineX - 8, y: pinY))
                        path.move(to: CGPoint(x: centerlineX + 8, y: feetY))
                        path.addLine(to: CGPoint(x: centerlineX + 8, y: pinY))
                    }
                    .stroke(fsColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.0, dash: [2, 2]))
                    
                    // Vertical dimension line showing the footstretch
                    DimensionLineVertical(
                        startY: feetY,
                        endY: pinY,
                        x: centerlineX - 25,
                        label: String(format: "Footstretch".localized + ": %.1f cm", footstretch),
                        isActive: isFSActive,
                        arrowLeft: true
                    )
                }
                
                if selectedField == .footplateAngle || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isAngleActive = selectedField == .footplateAngle
                    // Horizontal reference line (seat-rail plane = 0°)
                    Path { path in
                        path.move(to: CGPoint(x: centerlineX + 8, y: feetY))
                        path.addLine(to: CGPoint(x: centerlineX + 38, y: feetY))
                    }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Arc from 0° (horizontal, seat-rail plane) to actual footplate angle
                    // In 2D top view the footplate rises toward the bow (negative Y direction on screen)
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: centerlineX + 10, y: feetY),
                            radius: 22,
                            startAngle: .degrees(0),        // horizontal = seat rail plane
                            endAngle: .degrees(-footplateAngle), // upward tilt of plate
                            clockwise: true
                        )
                    }
                    .stroke(isAngleActive ? Theme.accent : Color.gray.opacity(0.6), lineWidth: isAngleActive ? 1.5 : 1.0)
                    
                    Text(String(format: "Footplate Angle".localized + ": %.0f°", footplateAngle))
                        .font(.system(size: 9, weight: isAngleActive ? .bold : .semibold, design: .rounded))
                        .foregroundColor(isAngleActive ? Theme.accent : Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.6).cornerRadius(3))
                        .position(x: centerlineX + 68, y: feetY - 14)
                }
                
                if selectedField == .seatPosition || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isSeatActive = selectedField == .seatPosition
                    
                    Path { path in
                        path.move(to: CGPoint(x: centerlineX - 40, y: seatY))
                        path.addLine(to: CGPoint(x: centerlineX + 40, y: seatY))
                    }
                    .stroke(isSeatActive ? Theme.accent.opacity(0.3) : Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1.0, dash: [2, 2]))
                    
                    DimensionLineVertical(
                        startY: pinY,
                        endY: seatY,
                        x: centerlineX + 30,
                        label: String(format: "Seat Position".localized + ": %.1f cm", seatPosition),
                        isActive: isSeatActive,
                        arrowLeft: false
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isRiggerAdjustMode.toggle()
                            dragStartPinYOffset = riggerPinYOffset
                            dragStartBowOffset = riggerBowOffset
                            dragStartStrokeOffset = riggerStrokeOffset
                        }
                    }
            )
        }
    }
    
    // MARK: - Diagonal View Diagram (3D Perspective Cockpit Preview)
    private var diagonalViewDiagram: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerlineX = w * 0.5
            
            let isScull = oarType == .scull
            let halfSpanVal = isScull ? (span / 2.0) : span
            let halfSpan3D = halfSpanVal * CGFloat(riggerXScaleFactor) // ピンを近づける（ユーザー調整可能）
            
            let heelsY3d = -CGFloat(max(0.0, min(25.0, footplateHeight)))
            let z3d_foot = 20.0 + CGFloat(footstretch)
            // TopビューのriggerPinYOffset（pt）をスケール1.3で割りで3D空間のcmに変換
            // TopビューのY+方向（スターン側）→ 3DのZ+方向（スターン側）と同方向
            let z3d_pin: CGFloat = 40.0 + CGFloat(riggerPinYOffset) / 1.3
            let pinHeight3dPort = CGFloat(workHeightPort)
            let pinHeight3dStarboard = CGFloat(workHeightStarboard)
            
            // Check if user is focusing on footplate settings to zoom in closer
            let isZoomedIn = selectedField == .footplateAngle || selectedField == .footplateHeight
            
            // Base zoom is much closer when zoomed in to clearly show heel height and angle
            let baseZoom: CGFloat = isZoomedIn ? 3.5 : 1.5
            let zoom: CGFloat = baseZoom * userZoomFactor
            
            // Center shift moves focus directly to the footplate area when zoomed in
            let centerShiftZ: CGFloat = isZoomedIn ? (z3d_foot + 10.0) : 42.0
            let centerShiftY: CGFloat = isZoomedIn ? (heelsY3d + 8.0) : 0.0
            let distance: CGFloat = isZoomedIn ? 40.0 : 100.0
            
            // Calculates camera-space coordinates including drag rotation & zoom shifts
            let getRotatedPoint = { (p: Point3D) -> RotatedPoint in
                let dx = p.x
                let dy = p.y - centerShiftY
                let dz = p.z - centerShiftZ
                
                let yawRad = dragRotationY * .pi / 180.0
                let rx = dx * cos(yawRad) - dz * sin(yawRad)
                let rz = dx * sin(yawRad) + dz * cos(yawRad)
                
                let pitchRad = dragRotationX * .pi / 180.0
                let ry = dy * cos(pitchRad) - rz * sin(pitchRad)
                let rz2 = dy * sin(pitchRad) + rz * cos(pitchRad)
                
                return RotatedPoint(rx: rx, ry: ry, rz2: rz2)
            }
            
            // Near clipping plane to prevent divide-by-zero or backward projection stretch
            let nearClip: CGFloat = 3.0
            
            let projectRotated = { (rp: RotatedPoint) -> CGPoint in
                let factor = (rp.rz2 + distance) / distance
                let x = centerlineX + (rp.rx * 1.35 * zoom) / factor
                let y = h * 0.54 - (rp.ry * 1.2 * zoom) / factor
                return CGPoint(x: x, y: y)
            }
            
            // 3D to 2D projection function
            let project = { (x3d: CGFloat, y3d: CGFloat, z3d: CGFloat) -> CGPoint in
                let rp = getRotatedPoint(Point3D(x: x3d, y: y3d, z: z3d))
                return projectRotated(rp)
            }
            
            // Checks if a 3D point is in front of the near clipping plane
            let isPointVisible = { (p: Point3D) -> Bool in
                let rp = getRotatedPoint(p)
                return rp.rz2 + distance >= nearClip
            }
            
            // Clips a 3D polygon at the near clipping plane using Sutherland-Hodgman
            let clipPolygon = { (vertices: [Point3D]) -> [CGPoint] in
                let inputList = vertices.map { getRotatedPoint($0) }
                if inputList.isEmpty { return [] }
                
                var outputList: [RotatedPoint] = []
                
                for i in 0..<inputList.count {
                    let current = inputList[i]
                    let prev = inputList[(i + inputList.count - 1) % inputList.count]
                    
                    let dCurrent = current.rz2 + distance
                    let dPrev = prev.rz2 + distance
                    
                    if dCurrent >= nearClip {
                        if dPrev < nearClip {
                            let t = (nearClip - dPrev) / (dCurrent - dPrev)
                            let rx = prev.rx + t * (current.rx - prev.rx)
                            let ry = prev.ry + t * (current.ry - prev.ry)
                            let rz2 = -distance + nearClip
                            outputList.append(RotatedPoint(rx: rx, ry: ry, rz2: rz2))
                        }
                        outputList.append(current)
                    } else if dPrev >= nearClip {
                        let t = (nearClip - dPrev) / (dCurrent - dPrev)
                        let rx = prev.rx + t * (current.rx - prev.rx)
                        let ry = prev.ry + t * (current.ry - prev.ry)
                        let rz2 = -distance + nearClip
                        outputList.append(RotatedPoint(rx: rx, ry: ry, rz2: rz2))
                    }
                }
                
                return outputList.map { projectRotated($0) }
            }
            
            let drawClippedPolygon = { (vertices: [Point3D], path: inout Path) in
                let projectedPoints = clipPolygon(vertices)
                guard projectedPoints.count >= 3 else { return }
                path.move(to: projectedPoints[0])
                for i in 1..<projectedPoints.count {
                    path.addLine(to: projectedPoints[i])
                }
                path.closeSubpath()
            }
            
            let drawClippedLine = { (p1: Point3D, p2: Point3D, path: inout Path) in
                let rp1 = getRotatedPoint(p1)
                let rp2 = getRotatedPoint(p2)
                
                let d1 = rp1.rz2 + distance
                let d2 = rp2.rz2 + distance
                
                if d1 < nearClip && d2 < nearClip {
                    return
                }
                
                if d1 >= nearClip && d2 >= nearClip {
                    path.move(to: projectRotated(rp1))
                    path.addLine(to: projectRotated(rp2))
                } else {
                    let t = (nearClip - d1) / (d2 - d1)
                    let rx_clip = rp1.rx + t * (rp2.rx - rp1.rx)
                    let ry_clip = rp1.ry + t * (rp2.ry - rp1.ry)
                    let rz2_clip = -distance + nearClip
                    let rp_clip = RotatedPoint(rx: rx_clip, ry: ry_clip, rz2: rz2_clip)
                    
                    let pt_clip = projectRotated(rp_clip)
                    if d1 >= nearClip {
                        path.move(to: projectRotated(rp1))
                        path.addLine(to: pt_clip)
                    } else {
                        path.move(to: pt_clip)
                        path.addLine(to: projectRotated(rp2))
                    }
                }
            }
            
            let hullHalfWidthVal: CGFloat = isScull ? 16.0 : 26.0
            let angleRad = CGFloat(footplateAngle) * .pi / 180.0
            let plateLen3d: CGFloat = 20.0
            let z3d_top = z3d_foot + plateLen3d * cos(angleRad)
            let y3d_top = heelsY3d + plateLen3d * sin(angleRad)
            let isFootplateSelected = selectedField == .footplateAngle || selectedField == .footplateHeight
            
            let cosA = cos(angleRad)
            let sinA = sin(angleRad)
            
            // Helper to get Point3D on the shoe surface relative to footplate surface
            let getShoePoint = { (shoeCenterX: CGFloat, u: CGFloat, v: CGFloat, height: CGFloat) -> Point3D in
                let zPlate = z3d_foot + v * cosA
                let yPlate = heelsY3d + v * sinA
                let y = yPlate + height * cosA
                let z = zPlate - height * sinA
                let x = shoeCenterX + u
                return Point3D(x: x, y: y, z: z)
            }
            
            // Draw detailed parts of a rowing shoe (Sole, Body, Toe, Heel, Straps, Stripes)
            let drawDetailedShoe = { (shoeCenterX: CGFloat, path: inout Path, drawPart: String) in
                let pt = { (u: CGFloat, v: CGFloat, h: CGFloat) -> Point3D in
                    getShoePoint(shoeCenterX, u, v, h)
                }
                
                if drawPart == "sole" {
                    let soleTop = [
                        pt(-1.8, 1.0, 0.8),
                        pt(-2.0, 5.0, 0.8),
                        pt(-2.5, 10.0, 0.8),
                        pt(-3.1, 14.0, 0.8),
                        pt(-2.7, 17.5, 0.8),
                        pt(-1.5, 19.5, 0.8),
                        pt(0.5, 19.5, 0.8),
                        pt(2.1, 17.5, 0.8),
                        pt(2.5, 14.0, 0.8),
                        pt(1.7, 10.0, 0.8),
                        pt(1.7, 5.0, 0.8),
                        pt(1.8, 1.0, 0.8)
                    ]
                    drawClippedPolygon(soleTop, &path)
                } 
                else if drawPart == "sole_side" {
                    let soleProfile = [
                        (-1.8, 1.0),
                        (-2.0, 5.0),
                        (-2.5, 10.0),
                        (-3.1, 14.0),
                        (-2.7, 17.5),
                        (-1.5, 19.5),
                        (0.5, 19.5),
                        (2.1, 17.5),
                        (2.5, 14.0),
                        (1.7, 10.0),
                        (1.7, 5.0),
                        (1.8, 1.0)
                    ]
                    for i in 0..<soleProfile.count {
                        let nextIndex = (i + 1) % soleProfile.count
                        let p1 = soleProfile[i]
                        let p2 = soleProfile[nextIndex]
                        
                        let sideVerts = [
                            pt(p1.0, p1.1, 0),
                            pt(p1.0, p1.1, 0.8),
                            pt(p2.0, p2.1, 0.8),
                            pt(p2.0, p2.1, 0)
                        ]
                        drawClippedPolygon(sideVerts, &path)
                    }
                } 
                else if drawPart == "toe_cap" {
                    let toeLeft = [
                        pt(-3.1, 14.0, 0.8),
                        pt(-2.0, 14.0, 2.8),
                        pt(0.0, 14.0, 3.2),
                        pt(0.0, 17.5, 2.2),
                        pt(-2.0, 17.5, 1.8),
                        pt(-2.7, 17.5, 0.8)
                    ]
                    drawClippedPolygon(toeLeft, &path)
                    
                    let toeRight = [
                        pt(0.0, 14.0, 3.2),
                        pt(1.5, 14.0, 2.8),
                        pt(2.5, 14.0, 0.8),
                        pt(2.1, 17.5, 0.8),
                        pt(1.5, 17.5, 1.8),
                        pt(0.0, 17.5, 2.2)
                    ]
                    drawClippedPolygon(toeRight, &path)
                    
                    let tipLeft = [
                        pt(-2.7, 17.5, 0.8),
                        pt(-2.0, 17.5, 1.8),
                        pt(0.0, 17.5, 2.2),
                        pt(0.0, 19.5, 1.3),
                        pt(-1.5, 19.5, 0.8)
                    ]
                    drawClippedPolygon(tipLeft, &path)
                    
                    let tipRight = [
                        pt(0.0, 17.5, 2.2),
                        pt(1.5, 17.5, 1.8),
                        pt(2.1, 17.5, 0.8),
                        pt(0.5, 19.5, 0.8),
                        pt(0.0, 19.5, 1.3)
                    ]
                    drawClippedPolygon(tipRight, &path)
                } 
                else if drawPart == "body" {
                    let bodyLeft = [
                        pt(-3.1, 14.0, 0.8),
                        pt(-2.0, 14.0, 2.8),
                        pt(-1.8, 10.0, 4.0),
                        pt(-2.5, 10.0, 0.8)
                    ]
                    drawClippedPolygon(bodyLeft, &path)
                    
                    let bodyRight = [
                        pt(2.5, 14.0, 0.8),
                        pt(1.5, 14.0, 2.8),
                        pt(1.2, 10.0, 4.0),
                        pt(1.7, 10.0, 0.8)
                    ]
                    drawClippedPolygon(bodyRight, &path)
                    
                    let tongue = [
                        pt(-2.0, 14.0, 2.8),
                        pt(0.0, 14.0, 3.2),
                        pt(1.5, 14.0, 2.8),
                        pt(1.2, 10.0, 4.0),
                        pt(0.0, 10.0, 4.4),
                        pt(-1.8, 10.0, 4.0)
                    ]
                    drawClippedPolygon(tongue, &path)
                    
                    let midLeft = [
                        pt(-2.5, 10.0, 0.8),
                        pt(-1.8, 10.0, 4.0),
                        pt(-1.5, 6.0, 3.8),
                        pt(-2.0, 6.0, 0.8)
                    ]
                    drawClippedPolygon(midLeft, &path)
                    
                    let midRight = [
                        pt(1.7, 10.0, 0.8),
                        pt(1.2, 10.0, 4.0),
                        pt(1.2, 6.0, 3.8),
                        pt(1.7, 6.0, 0.8)
                    ]
                    drawClippedPolygon(midRight, &path)
                    
                    let instep = [
                        pt(-1.8, 10.0, 4.0),
                        pt(0.0, 10.0, 4.4),
                        pt(1.2, 10.0, 4.0),
                        pt(1.2, 6.0, 3.8),
                        pt(0.0, 6.0, 4.2),
                        pt(-1.5, 6.0, 3.8)
                    ]
                    drawClippedPolygon(instep, &path)
                } 
                else if drawPart == "heel" {
                    let heelLeft = [
                        pt(-2.0, 6.0, 0.8),
                        pt(-1.5, 6.0, 3.8),
                        pt(0.0, 1.0, 2.6),
                        pt(-1.8, 1.0, 0.8)
                    ]
                    drawClippedPolygon(heelLeft, &path)
                    
                    let heelRight = [
                        pt(1.7, 6.0, 0.8),
                        pt(1.2, 6.0, 3.8),
                        pt(0.0, 1.0, 2.6),
                        pt(1.8, 1.0, 0.8)
                    ]
                    drawClippedPolygon(heelRight, &path)
                } 
                else if drawPart == "straps" {
                    let strap1 = [
                        pt(-2.8, 11.5, 1.2),
                        pt(-1.0, 11.5, 3.6),
                        pt(0.8, 11.5, 3.6),
                        pt(2.2, 11.5, 1.2),
                        pt(2.0, 12.5, 1.2),
                        pt(0.8, 12.5, 3.6),
                        pt(-1.0, 12.5, 3.6),
                        pt(-2.6, 12.5, 1.2)
                    ]
                    drawClippedPolygon(strap1, &path)
                    
                    let strap2 = [
                        pt(-2.3, 8.5, 1.2),
                        pt(-1.0, 8.5, 3.9),
                        pt(0.8, 8.5, 3.9),
                        pt(1.7, 8.5, 1.2),
                        pt(1.7, 9.5, 1.2),
                        pt(0.8, 9.5, 3.9),
                        pt(-1.0, 9.5, 3.9),
                        pt(-2.1, 9.5, 1.2)
                    ]
                    drawClippedPolygon(strap2, &path)
                } 
                else if drawPart == "stripes" {
                    drawClippedLine(pt(-2.4, 8.8, 1.5), pt(-2.0, 10.8, 3.0), &path)
                    drawClippedLine(pt(-2.6, 8.3, 1.5), pt(-2.2, 10.3, 3.0), &path)
                    drawClippedLine(pt(-2.2, 9.3, 1.5), pt(-1.8, 11.3, 3.0), &path)
                    
                    drawClippedLine(pt(2.1, 8.8, 1.5), pt(1.7, 10.8, 3.0), &path)
                    drawClippedLine(pt(2.3, 8.3, 1.5), pt(1.9, 10.3, 3.0), &path)
                    drawClippedLine(pt(1.9, 9.3, 1.5), pt(1.5, 11.3, 3.0), &path)
                }
            }
            
            // Riggers are only rendered when NOT focusing on footplate settings (but keep them when showing footstretch)
            let showRiggers = !(selectedField == .footplateAngle || selectedField == .footplateHeight)
            
            ZStack {
                // Drag Rotation Hint overlay
                Text(LocalizationManager.shared.language == .japanese ? "ドラッグして回転・ピンチでズーム" : "Drag to rotate, pinch to zoom")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3).cornerRadius(6))
                    .position(x: w - 75, y: 15)
                
                // 3D Cockpit Deck Floor (Clipped - Semi-translucent panel look)
                let floorVertices = [
                    Point3D(x: -hullHalfWidthVal, y: 0, z: 5),
                    Point3D(x: hullHalfWidthVal, y: 0, z: 5),
                    Point3D(x: hullHalfWidthVal, y: 0, z: 85),
                    Point3D(x: -hullHalfWidthVal, y: 0, z: 85)
                ]
                Path { path in
                    drawClippedPolygon(floorVertices, &path)
                }
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.12), Color.white.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Slide Rails (Cut at appropriate position dynamically relative to footplate)
                let seatZ: CGFloat = 40.0 - CGFloat(seatPosition) * (20.0 / 28.0)
                let railsEndZ = max(seatZ + 4, z3d_foot - 3.0)
                
                Path { path in
                    drawClippedLine(Point3D(x: -6, y: 2, z: 8), Point3D(x: -6, y: 2, z: railsEndZ), &path)
                }
                .stroke(LinearGradient(colors: [Theme.accent.opacity(0.8), Theme.secondaryAccent.opacity(0.8)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                
                Path { path in
                    drawClippedLine(Point3D(x: 6, y: 2, z: 8), Point3D(x: 6, y: 2, z: railsEndZ), &path)
                }
                .stroke(LinearGradient(colors: [Theme.accent.opacity(0.8), Theme.secondaryAccent.opacity(0.8)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                
                // Seat
                let seatVertices = [
                    Point3D(x: -12, y: 4, z: seatZ + 12),
                    Point3D(x: 12, y: 4, z: seatZ + 12),
                    Point3D(x: 12, y: 4, z: seatZ),
                    Point3D(x: -12, y: 4, z: seatZ)
                ]
                Path { path in
                    drawClippedPolygon(seatVertices, &path)
                }
                .fill(Color.white.opacity(0.15))
                .overlay(
                    Path { path in
                        drawClippedPolygon(seatVertices, &path)
                    }
                    .stroke(selectedField == .seatPosition ? Theme.accent : Theme.textSecondary.opacity(0.3), lineWidth: 1)
                )
                
                // Seat wheels (Visibility checked)
                Group {
                    if isPointVisible(Point3D(x: -6, y: 2, z: seatZ + 10)) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                            .position(project(-6, 2, seatZ + 10))
                    }
                    
                    if isPointVisible(Point3D(x: 6, y: 2, z: seatZ + 10)) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                            .position(project(6, 2, seatZ + 10))
                    }
                    
                    if isPointVisible(Point3D(x: -6, y: 2, z: seatZ + 2)) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                            .position(project(-6, 2, seatZ + 2))
                    }
                    
                    if isPointVisible(Point3D(x: 6, y: 2, z: seatZ + 2)) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                            .position(project(6, 2, seatZ + 2))
                    }
                }
                
                // Footplate Mount / Side Tracks (Clipped)
                Path { path in
                    drawClippedLine(Point3D(x: -hullHalfWidthVal + 1.5, y: heelsY3d - 3, z: z3d_foot - 3), Point3D(x: -hullHalfWidthVal + 1.5, y: y3d_top + 3, z: z3d_top + 3), &path)
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                
                Path { path in
                    drawClippedLine(Point3D(x: hullHalfWidthVal - 1.5, y: heelsY3d - 3, z: z3d_foot - 3), Point3D(x: hullHalfWidthVal - 1.5, y: y3d_top + 3, z: z3d_top + 3), &path)
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                
                Path { path in
                    drawClippedLine(Point3D(x: -hullHalfWidthVal + 1.5, y: heelsY3d, z: z3d_foot), Point3D(x: hullHalfWidthVal - 1.5, y: heelsY3d, z: z3d_foot), &path)
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                
                // Footplate Board (Clipped)
                let footplateVertices = [
                    Point3D(x: -11, y: heelsY3d, z: z3d_foot),
                    Point3D(x: 11, y: heelsY3d, z: z3d_foot),
                    Point3D(x: 11, y: y3d_top, z: z3d_top),
                    Point3D(x: -11, y: y3d_top, z: z3d_top)
                ]
                Path { path in
                    drawClippedPolygon(footplateVertices, &path)
                }
                .fill(isFootplateSelected ? Theme.accent.opacity(0.2) : Color.white.opacity(0.06))
                .overlay(
                    Path { path in
                        drawClippedPolygon(footplateVertices, &path)
                    }
                    .stroke(isFootplateSelected ? Theme.accent : Color.white.opacity(0.2), lineWidth: isFootplateSelected ? 2.0 : 1.0)
                )
                
                // Side thickness for 3D look (Clipped)
                let boardLeftThickness = [
                    Point3D(x: -11, y: heelsY3d, z: z3d_foot),
                    getShoePoint(-11, 0, 0, 1.5),
                    getShoePoint(-11, 0, plateLen3d, 1.5),
                    Point3D(x: -11, y: y3d_top, z: z3d_top)
                ]
                Path { path in
                    drawClippedPolygon(boardLeftThickness, &path)
                }
                .fill(Color.white.opacity(0.1))
                
                let boardRightThickness = [
                    Point3D(x: 11, y: heelsY3d, z: z3d_foot),
                    getShoePoint(11, 0, 0, 1.5),
                    getShoePoint(11, 0, plateLen3d, 1.5),
                    Point3D(x: 11, y: y3d_top, z: z3d_top)
                ]
                Path { path in
                    drawClippedPolygon(boardRightThickness, &path)
                }
                .fill(Color.white.opacity(0.1))
                
                // 3D Shoes (Left and Right, rendered back-to-front / component sorted)
                // Left Shoe
                Path { path in drawDetailedShoe(-5.0, &path, "sole_side") }.fill(Color(hex: "0F0F0F"))
                Path { path in drawDetailedShoe(-5.0, &path, "sole") }.fill(Color(hex: "1C1C1C"))
                Path { path in drawDetailedShoe(-5.0, &path, "toe_cap") }.fill(Color(hex: "222222"))
                Path { path in drawDetailedShoe(-5.0, &path, "toe_cap") }.stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                Path { path in drawDetailedShoe(-5.0, &path, "body") }.fill(Theme.accent.opacity(0.85))
                Path { path in drawDetailedShoe(-5.0, &path, "body") }.stroke(Color.white.opacity(0.15), lineWidth: 1.0)
                Path { path in drawDetailedShoe(-5.0, &path, "heel") }.fill(Color(hex: "181818"))
                Path { path in drawDetailedShoe(-5.0, &path, "heel") }.stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                Path { path in drawDetailedShoe(-5.0, &path, "straps") }.fill(Theme.secondaryAccent)
                Path { path in drawDetailedShoe(-5.0, &path, "stripes") }.stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                
                // Right Shoe
                Path { path in drawDetailedShoe(5.0, &path, "sole_side") }.fill(Color(hex: "0F0F0F"))
                Path { path in drawDetailedShoe(5.0, &path, "sole") }.fill(Color(hex: "1C1C1C"))
                Path { path in drawDetailedShoe(5.0, &path, "toe_cap") }.fill(Color(hex: "222222"))
                Path { path in drawDetailedShoe(5.0, &path, "toe_cap") }.stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                Path { path in drawDetailedShoe(5.0, &path, "body") }.fill(Theme.accent.opacity(0.85))
                Path { path in drawDetailedShoe(5.0, &path, "body") }.stroke(Color.white.opacity(0.15), lineWidth: 1.0)
                Path { path in drawDetailedShoe(5.0, &path, "heel") }.fill(Color(hex: "181818"))
                Path { path in drawDetailedShoe(5.0, &path, "heel") }.stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                Path { path in drawDetailedShoe(5.0, &path, "straps") }.fill(Theme.secondaryAccent)
                Path { path in drawDetailedShoe(5.0, &path, "stripes") }.stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                
                // 3D Riggers (Only shown if focused setting doesn't hide them)
                if showRiggers {
                    let isWing3D = riggerType == "wing"
                    if isScull {
                        if isWing3D {
                            // ウィングリガー: ストローク側ブレース + ボウ側メインアーム
                            let thinStayAnchorZ3D = z3d_pin + 14.0  // ピンよりストローク側
                            let thickWingAnchorZ3D = z3d_pin - 20.0 // ピンよりボウ側
                            // ストローク側ブレース (細い線)
                            Path { path in
                                drawClippedLine(Point3D(x: -hullHalfWidthVal, y: 12, z: thinStayAnchorZ3D), Point3D(x: -halfSpan3D, y: pinHeight3dPort, z: z3d_pin), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thinStayAnchorZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(Color.gray.opacity(0.7), lineWidth: 1.8)
                            
                            // メインアーム (太い線)
                            Path { path in
                                drawClippedLine(Point3D(x: -halfSpan3D, y: pinHeight3dPort, z: z3d_pin), Point3D(x: -hullHalfWidthVal - 5, y: 12, z: thickWingAnchorZ3D), &path)
                                drawClippedLine(Point3D(x: -hullHalfWidthVal - 5, y: 12, z: thickWingAnchorZ3D), Point3D(x: hullHalfWidthVal + 5, y: 12, z: thickWingAnchorZ3D), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal + 5, y: 12, z: thickWingAnchorZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(LinearGradient(colors: [Color(hex: "E0E0E0"), Color(hex: "AAAAAA")], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        } else {
                            // ストレートリガー: V字ステー形状
                            let thinStayZ3D = z3d_pin + 14.0
                            let thickWingZ3D = z3d_pin - 20.0
                            Path { path in
                                drawClippedLine(Point3D(x: -hullHalfWidthVal, y: 12, z: thinStayZ3D), Point3D(x: -halfSpan3D, y: pinHeight3dPort, z: z3d_pin), &path)
                                drawClippedLine(Point3D(x: -hullHalfWidthVal, y: 12, z: thickWingZ3D), Point3D(x: -halfSpan3D, y: pinHeight3dPort, z: z3d_pin), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thinStayZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thickWingZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(LinearGradient(colors: [Color(hex: "E0E0E0"), Color(hex: "AAAAAA")], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                    } else {
                        if isWing3D {
                            // スウィープ + ウィング
                            let thinStayAnchorZ3D = z3d_pin + 14.0
                            let thickWingAnchorZ3D = z3d_pin - 20.0
                            Path { path in
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thinStayAnchorZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(Color.gray.opacity(0.7), lineWidth: 1.8)
                            
                            Path { path in
                                drawClippedLine(Point3D(x: -hullHalfWidthVal, y: 12, z: thickWingAnchorZ3D), Point3D(x: hullHalfWidthVal + 5, y: 12, z: thickWingAnchorZ3D), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal + 5, y: 12, z: thickWingAnchorZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(LinearGradient(colors: [Color(hex: "E0E0E0"), Color(hex: "AAAAAA")], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        } else {
                            // スウィープ + ストレート: V字ステー形状
                            let thinStayZ3D = z3d_pin + 14.0
                            let thickWingZ3D = z3d_pin - 20.0
                            Path { path in
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thinStayZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                                drawClippedLine(Point3D(x: hullHalfWidthVal, y: 12, z: thickWingZ3D), Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin), &path)
                            }
                            .stroke(LinearGradient(colors: [Color(hex: "E0E0E0"), Color(hex: "AAAAAA")], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                    }
                    
                    Path { path in
                        drawClippedLine(Point3D(x: halfSpan3D, y: pinHeight3dStarboard - 4, z: z3d_pin), Point3D(x: halfSpan3D, y: pinHeight3dStarboard + 6, z: z3d_pin), &path)
                    }
                    .stroke(Color.black, lineWidth: 2.5)
                    
                    if isScull {
                        Path { path in
                            drawClippedLine(Point3D(x: -halfSpan3D, y: pinHeight3dPort - 4, z: z3d_pin), Point3D(x: -halfSpan3D, y: pinHeight3dPort + 6, z: z3d_pin), &path)
                        }
                        .stroke(Color.black, lineWidth: 2.5)
                    }
                    
                    if isPointVisible(Point3D(x: halfSpan3D, y: pinHeight3dStarboard, z: z3d_pin)) {
                        Circle()
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Theme.accent.opacity(0.8), lineWidth: 1))
                            .position(project(halfSpan3D, pinHeight3dStarboard, z3d_pin))
                    }
                    
                    if isScull && isPointVisible(Point3D(x: -halfSpan3D, y: pinHeight3dPort, z: z3d_pin)) {
                        Circle()
                            .fill(Color(hex: "1A1A1A"))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Theme.accent.opacity(0.8), lineWidth: 1))
                            .position(project(-halfSpan3D, pinHeight3dPort, z3d_pin))
                    }
                    
                    // MARK: - デバッグオーバーレイ (3D View)
                    if riggerDebugOverlay {
                        let dbgWingAnchZ = z3d_pin - 20.0
                        let dbgStayAnchZ = z3d_pin + 14.0
                        VStack(alignment: .leading, spacing: 2) {
                            Text("── 3D Z座標 ──")
                                .foregroundColor(.white)
                            Text("z3d_pin = \(String(format:"%.1f",z3d_pin))")
                                .foregroundColor(.yellow)
                            Text("z3d_foot = \(String(format:"%.1f",z3d_foot))")
                                .foregroundColor(.green)
                            Text("wing_bowAncZ = \(String(format:"%.1f",dbgWingAnchZ))")
                                .foregroundColor(.cyan)
                            Text("stay_strkAncZ = \(String(format:"%.1f",dbgStayAnchZ))")
                                .foregroundColor(.orange)
                            Text("halfSpan = \(String(format:"%.1f",halfSpanVal))")
                                .foregroundColor(.purple)
                            Text("halfSpan3D = \(String(format:"%.1f",halfSpan3D))")
                                .foregroundColor(.indigo)
                            Text("xScale = \(String(format:"%.2f",riggerXScaleFactor))")
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(5)
                        .background(Color.black.opacity(0.8).cornerRadius(6))
                        .position(x: 62, y: 60)
                    }
                }
                
                // Footplate Height Indicator: vertical line from heel of left shoe up to seat level
                if selectedField == .footplateHeight || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isHeightActive = selectedField == .footplateHeight
                    let activeColor = isHeightActive ? Theme.accent : Color.gray.opacity(0.5)
                    
                    // Heel point of the left shoe: shoeCenterX = -5, u=0, v=1.0 (heel end), height=3.2 (top back of heel cup)
                    let heelPt3D = getShoePoint(-5.0, 0, 1.0, 3.2)
                    // Seat-level point directly above the heel (Y=4 is seat surface height)
                    let seatAboveHeel = Point3D(x: heelPt3D.x, y: 4.0, z: heelPt3D.z)
                    
                    // Vertical measurement line: heel → seat level
                    Path { path in
                        drawClippedLine(heelPt3D, seatAboveHeel, &path)
                    }
                    .stroke(activeColor, lineWidth: isHeightActive ? 2.0 : 1.0)
                    
                    // Dashed horizontal guide at seat level
                    Path { path in
                        drawClippedLine(
                            Point3D(x: heelPt3D.x - 8, y: 4.0, z: heelPt3D.z),
                            Point3D(x: heelPt3D.x + 8, y: 4.0, z: heelPt3D.z),
                            &path
                        )
                    }
                    .stroke(activeColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Dashed horizontal guide at heel level
                    Path { path in
                        drawClippedLine(
                            Point3D(x: heelPt3D.x - 8, y: heelPt3D.y, z: heelPt3D.z),
                            Point3D(x: heelPt3D.x + 8, y: heelPt3D.y, z: heelPt3D.z),
                            &path
                        )
                    }
                    .stroke(activeColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Heel dot marker
                    if isPointVisible(heelPt3D) {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                            .position(project(heelPt3D.x, heelPt3D.y, heelPt3D.z))
                    }
                    
                    // Label at midpoint
                    let midY3D = (heelPt3D.y + 4.0) / 2.0
                    if isPointVisible(Point3D(x: heelPt3D.x, y: midY3D, z: heelPt3D.z)) {
                        let displayVal = max(0.0, min(25.0, footplateHeight))
                        let pMid = project(heelPt3D.x, midY3D, heelPt3D.z)
                        Text(String(format: "Heel Depth".localized + ": %.1f cm", displayVal))
                            .font(.system(size: 8, weight: isHeightActive ? .bold : .semibold, design: .rounded))
                            .foregroundColor(isHeightActive ? Theme.accent : Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6).cornerRadius(3))
                            .position(x: pMid.x + 42, y: pMid.y) // Shift to right to avoid overlapping Footplate Angle
                    }
                }
                
                // Footplate Angle Arc Indicator in 3D (shown when angle field focused or idle)
                if selectedField == .footplateAngle || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isAngleActive = selectedField == .footplateAngle
                    let angleColor = isAngleActive ? Theme.accent : Color.gray.opacity(0.5)
                    
                    // Draw arc from horizontal (floor plane) to the footplate surface at the heel end
                    // Visualise using two reference lines: horizontal and along the plate, plus a 2D arc overlaid
                    // Horizontal reference at heel edge (z = z3d_foot, y = heelsY3d)
                    let arcOrigin3D = Point3D(x: -13, y: heelsY3d, z: z3d_foot)
                    let arcHoriz3D  = Point3D(x: -13, y: heelsY3d, z: z3d_foot + 12)
                    let arcPlate3D  = getShoePoint(-13, 0, 12, 0)
                    
                    // Horizontal reference line
                    Path { path in
                        drawClippedLine(arcOrigin3D, arcHoriz3D, &path)
                    }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Line along footplate surface
                    Path { path in
                        drawClippedLine(arcOrigin3D, arcPlate3D, &path)
                    }
                    .stroke(angleColor.opacity(isAngleActive ? 0.7 : 0.4), lineWidth: isAngleActive ? 1.5 : 1.0)
                    
                    // Footplate angle label
                    if isPointVisible(arcOrigin3D) {
                        let pOrigin = project(arcOrigin3D.x, arcOrigin3D.y, arcOrigin3D.z)
                        Text(String(format: "%.0f°", footplateAngle))
                            .font(.system(size: 9, weight: isAngleActive ? .black : .bold, design: .rounded))
                            .foregroundColor(isAngleActive ? Theme.accent : Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6).cornerRadius(3))
                            .position(x: pOrigin.x - 28, y: pOrigin.y - 10)
                    }
                }
                
                // Footstretch Length 3D Indicator
                if selectedField == .footstretch || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isFSActive = selectedField == .footstretch
                    let fsColor = isFSActive ? Theme.accent : Color.gray.opacity(0.5)
                    
                    // Footstretch measurement target Z along the shoe
                    let vTarget: CGFloat = footstretchMeasurementMethod == "fromHeel" ? 1.0 : 10.0
                    let targetZ = z3d_foot + vTarget * cosA
                    let targetY = heelsY3d + vTarget * sinA
                    
                    // Pin-to-pin axis line (horizontal axis in 3D)
                    Path { path in
                        drawClippedLine(
                            Point3D(x: -halfSpanVal, y: pinHeight3dStarboard, z: 40.0),
                            Point3D(x: halfSpanVal, y: pinHeight3dStarboard, z: 40.0),
                            &path
                        )
                    }
                    .stroke(fsColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    
                    // Shoe reference axis line (horizontal axis in 3D)
                    Path { path in
                        drawClippedLine(
                            Point3D(x: -11.0, y: targetY, z: targetZ),
                            Point3D(x: 11.0, y: targetY, z: targetZ),
                            &path
                        )
                    }
                    .stroke(fsColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    
                    // Vertical projection lines from shoes straight up to the pin level
                    Path { path in
                        drawClippedLine(
                            Point3D(x: -5.0, y: targetY, z: targetZ),
                            Point3D(x: -5.0, y: pinHeight3dStarboard, z: targetZ),
                            &path
                        )
                        drawClippedLine(
                            Point3D(x: 5.0, y: targetY, z: targetZ),
                            Point3D(x: 5.0, y: pinHeight3dStarboard, z: targetZ),
                            &path
                        )
                    }
                    .stroke(fsColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.0, dash: [2, 2]))
                    
                    // Longitudinal lines connecting shoe vertical projection to pin line (representing footstretch)
                    Path { path in
                        drawClippedLine(
                            Point3D(x: -5.0, y: pinHeight3dStarboard, z: targetZ),
                            Point3D(x: -5.0, y: pinHeight3dStarboard, z: 40.0),
                            &path
                        )
                        drawClippedLine(
                            Point3D(x: 5.0, y: pinHeight3dStarboard, z: targetZ),
                            Point3D(x: 5.0, y: pinHeight3dStarboard, z: 40.0),
                            &path
                        )
                    }
                    .stroke(fsColor, lineWidth: isFSActive ? 2.0 : 1.0)
                    
                    // Ticks/Dots at the endpoints of the footstretch measurement lines
                    Group {
                        if isPointVisible(Point3D(x: -5.0, y: pinHeight3dStarboard, z: targetZ)) {
                            Circle()
                                .fill(fsColor)
                                .frame(width: 4, height: 4)
                                .position(project(-5.0, pinHeight3dStarboard, targetZ))
                        }
                        if isPointVisible(Point3D(x: 5.0, y: pinHeight3dStarboard, z: targetZ)) {
                            Circle()
                                .fill(fsColor)
                                .frame(width: 4, height: 4)
                                .position(project(5.0, pinHeight3dStarboard, targetZ))
                        }
                        if isPointVisible(Point3D(x: -5.0, y: pinHeight3dStarboard, z: 40.0)) {
                            Circle()
                                .fill(fsColor)
                                .frame(width: 4, height: 4)
                                .position(project(-5.0, pinHeight3dStarboard, 40.0))
                        }
                        if isPointVisible(Point3D(x: 5.0, y: pinHeight3dStarboard, z: 40.0)) {
                            Circle()
                                .fill(fsColor)
                                .frame(width: 4, height: 4)
                                .position(project(5.0, pinHeight3dStarboard, 40.0))
                        }
                    }
                    
                    // Midpoint label
                    let midZ = (40.0 + targetZ) / 2.0
                    let labelPt = Point3D(x: 6.5, y: pinHeight3dStarboard + 1.0, z: midZ)
                    if isPointVisible(labelPt) {
                        let pLabel = project(labelPt.x, labelPt.y, labelPt.z)
                        Text(String(format: "Footstretch".localized + ": %.1f cm", footstretch))
                            .font(.system(size: 8, weight: isFSActive ? .bold : .semibold, design: .rounded))
                            .foregroundColor(isFSActive ? Theme.accent : Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6).cornerRadius(3))
                            .position(x: pLabel.x + 36, y: pLabel.y)
                    }
                }
                
                // Floating Camera Controls Panel
                VStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            userZoomFactor = min(3.5, userZoomFactor + 0.25)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            userZoomFactor = max(0.4, userZoomFactor - 0.25)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            dragRotationX = -15.0
                            dragRotationY = 20.0
                            userZoomFactor = 1.0
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                }
                .padding(8)
                .position(x: w - 20, y: h - 45)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        dragRotationY = previousRotationY + gesture.translation.width * 0.4
                        dragRotationX = max(-45, min(45, previousRotationX - gesture.translation.height * 0.4))
                    }
                    .onEnded { gesture in
                        previousRotationY = dragRotationY
                        previousRotationX = dragRotationX
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { val in
                        userZoomFactor = max(0.4, min(3.5, pinchScale * val))
                    }
                    .onEnded { val in
                        pinchScale = userZoomFactor
                    }
            )
        }
    }
    
    // MARK: - Side View Diagram (Height, Pitch, Lateral Pitch, Footplate Height)
    private var sideViewDiagram: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w * 0.5
            let seatY = h * 0.65
            let hullBottomY = h * 0.85
            let isScull = oarType == .scull
            let halfSpanVal = isScull ? (span / 2.0) : span
            let scale: CGFloat = 1.3
            let pinY = seatY - CGFloat(activeWorkHeight) * scale
            let pinRightX = centerX + CGFloat(halfSpanVal) * scale
            let pinLeftX = centerX - CGFloat(halfSpanVal) * scale
            let hullHalfWidth = (isScull ? 15.0 : 25.0) * scale
            let gunwaleY = seatY - 5.0
            
            ZStack {
                // Hull outline (Transverse Cross-section)
                Path { path in
                    path.move(to: CGPoint(x: centerX - hullHalfWidth, y: gunwaleY))
                    path.addQuadCurve(to: CGPoint(x: centerX + hullHalfWidth, y: gunwaleY), control: CGPoint(x: centerX, y: hullBottomY))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(hex: "333333"), Color(hex: "1A1A1A")], startPoint: .top, endPoint: .bottom))
                .overlay(Path { path in
                    path.move(to: CGPoint(x: centerX - hullHalfWidth, y: gunwaleY))
                    path.addQuadCurve(to: CGPoint(x: centerX + hullHalfWidth, y: gunwaleY), control: CGPoint(x: centerX, y: hullBottomY))
                }.stroke(Color.gray.opacity(0.5), lineWidth: 1.5))
                
                // Seat (Cross-section view at seat level)
                Path { path in
                    path.move(to: CGPoint(x: centerX - 12, y: seatY))
                    path.addLine(to: CGPoint(x: centerX + 12, y: seatY))
                    path.addLine(to: CGPoint(x: centerX + 10, y: seatY + 4))
                    path.addLine(to: CGPoint(x: centerX - 10, y: seatY + 4))
                    path.closeSubpath()
                }
                .fill(Color(hex: "444444"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: centerX - 12, y: seatY))
                        path.addLine(to: CGPoint(x: centerX + 12, y: seatY))
                    }
                    .stroke(Color.gray, lineWidth: 1.5)
                )
                
                // Riggers
                Path { path in
                    path.move(to: CGPoint(x: centerX + hullHalfWidth, y: gunwaleY))
                    path.addLine(to: CGPoint(x: pinRightX, y: pinY))
                }
                .stroke(selectedField == .workHeight || selectedField == .span ? Theme.accent : Color(hex: "777777"), lineWidth: 2)
                
                if isScull {
                    Path { path in
                        path.move(to: CGPoint(x: centerX - hullHalfWidth, y: gunwaleY))
                        path.addLine(to: CGPoint(x: pinLeftX, y: pinY))
                    }
                    .stroke(selectedField == .workHeight || selectedField == .span ? Theme.accent : Color(hex: "777777"), lineWidth: 2)
                }
                
                // Height (Work Height) Indicator in Side View
                if selectedField == .workHeight || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isHeightActive = selectedField == .workHeight
                    
                    // Dashed line at seat level
                    Path { path in
                        path.move(to: CGPoint(x: centerX, y: seatY))
                        path.addLine(to: CGPoint(x: pinRightX + 15, y: seatY))
                    }
                    .stroke(isHeightActive ? Theme.accent.opacity(0.3) : Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Dashed line at pin level
                    Path { path in
                        path.move(to: CGPoint(x: pinRightX, y: pinY))
                        path.addLine(to: CGPoint(x: pinRightX + 15, y: pinY))
                    }
                    .stroke(isHeightActive ? Theme.accent.opacity(0.3) : Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1.0, dash: [3, 3]))
                    
                    // Vertical dimension line
                    DimensionLineVertical(
                        startY: pinY,
                        endY: seatY,
                        x: pinRightX + 12,
                        label: String(format: "Height".localized + ": %.1f cm", activeWorkHeight),
                        isActive: isHeightActive,
                        arrowLeft: false
                    )
                }
                
                let lateralPitchDeg: CGFloat = {
                    if activeLateralPitch == "4/4" { return 0.0 }
                    if activeLateralPitch == "5/3" { return 1.0 }
                    if activeLateralPitch == "6/2" { return 2.0 }
                    if activeLateralPitch == "7/1" { return 3.0 }
                    if let val = Double(activeLateralPitch) { return CGFloat(val) }
                    return 0.0
                }()
                
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: pinRightX, y: pinY - 12))
                        path.addLine(to: CGPoint(x: pinRightX, y: pinY + 16))
                    }
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.0, dash: [2, 2]))
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.black)
                        .frame(width: 6, height: 12)
                        .rotationEffect(.degrees(selectedField == .pitch ? 10.0 : lateralPitchDeg), anchor: .center)
                        .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(selectedField == .pitch || selectedField == .lateralPitch ? Theme.accent : Color.gray, lineWidth: 1.0))
                        .position(x: pinRightX, y: pinY)
                }
                
                if isScull {
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: pinLeftX, y: pinY - 12))
                            path.addLine(to: CGPoint(x: pinLeftX, y: pinY + 16))
                        }
                        .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.0, dash: [2, 2]))
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.black)
                            .frame(width: 6, height: 12)
                            .rotationEffect(.degrees(-lateralPitchDeg), anchor: .center)
                            .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(selectedField == .lateralPitch ? Theme.accent : Color.gray, lineWidth: 1.0))
                            .position(x: pinLeftX, y: pinY)
                    }
                }
                
                if selectedField == .lateralPitch || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isLPActive = selectedField == .lateralPitch
                    Path { path in
                        path.addArc(center: CGPoint(x: pinRightX, y: pinY), radius: 18, startAngle: .degrees(-90), endAngle: .degrees(-90 - (lateralPitchDeg == 0 ? 4 : lateralPitchDeg * 8.0)), clockwise: true)
                    }
                    .stroke(isLPActive ? Theme.accent : Color.gray.opacity(0.5), lineWidth: isLPActive ? 1.5 : 1.0)
                    
                    let bushingLabel = activeLateralPitch
                    
                    Text("\("Lateral Pitch"): \(bushingLabel)")
                        .font(.system(size: 8, weight: isLPActive ? .bold : .semibold, design: .rounded))
                        .foregroundColor(isLPActive ? Theme.accent : Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.6).cornerRadius(3))
                        .position(x: pinRightX - 35, y: pinY - 15) // Position on the inside (left of pin) to prevent overlap with Work Height
                }
                
                if selectedField == .pitch || (selectedField == nil && showAllRiggingValuesWhenIdle) {
                    let isPitchActive = selectedField == .pitch
                    
                    Text(String(format: "Pitch".localized + ": %.1f°", activePitch))
                        .font(.system(size: 8, weight: isPitchActive ? .bold : .semibold, design: .rounded))
                        .foregroundColor(isPitchActive ? Theme.accent : Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.6).cornerRadius(3))
                        .position(x: pinRightX - 35, y: pinY + 15) // Position on the inside (left of pin) to prevent overlap with Work Height
                }
            }
        }
    }
    
    private func getHighlightDescription() -> String? {
        guard let field = selectedField else { return nil }
        switch field {
        case .span:
            return "Span Highlight Description".localized
        case .workHeight:
            return "Height Highlight Description".localized
        case .pitch:
            return "Pitch Highlight Description".localized
        case .lateralPitch:
            return "Lateral Pitch Highlight Description".localized
        case .footstretch:
            return "Footstretch Highlight Description".localized
        case .footplateAngle:
            return "Footplate Angle Highlight Description".localized
        case .footplateHeight:
            return "Footplate Height Highlight Description".localized
        case .seatPosition:
            return "Seat Position Highlight Description".localized
        case .oarLength:
            return "Total Length Highlight Description".localized
        case .oarInboard:
            return "Inboard Highlight Description".localized
        case .oarGripDiameter:
            return "Grip Diameter Highlight Description".localized
        }
    }
}

// MARK: - Vertical Dimension Line Subview (Re-defined here)

struct DimensionLineVertical: View {
    let startY: CGFloat
    let endY: CGFloat
    let x: CGFloat
    let label: String
    let isActive: Bool
    let arrowLeft: Bool
    
    var body: some View {
        ZStack {
            // Vertical line
            Path { path in
                path.move(to: CGPoint(x: x, y: startY))
                path.addLine(to: CGPoint(x: x, y: endY))
                
                // Top bracket
                path.move(to: CGPoint(x: x - 4, y: startY))
                path.addLine(to: CGPoint(x: x + 4, y: startY))
                
                // Bottom bracket
                path.move(to: CGPoint(x: x - 4, y: endY))
                path.addLine(to: CGPoint(x: x + 4, y: endY))
            }
            .stroke(isActive ? Theme.accent : Color.gray.opacity(0.5), lineWidth: isActive ? 2.0 : 1.0)
            
            // Arrows
            Path { path in
                // Top arrow
                path.move(to: CGPoint(x: x - 3, y: startY + 5))
                path.addLine(to: CGPoint(x: x, y: startY))
                path.addLine(to: CGPoint(x: x + 3, y: startY + 5))
                
                // Bottom arrow
                path.move(to: CGPoint(x: x - 3, y: endY - 5))
                path.addLine(to: CGPoint(x: x, y: endY))
                path.addLine(to: CGPoint(x: x + 3, y: endY - 5))
            }
            .stroke(isActive ? Theme.accent : Color.gray.opacity(0.5), lineWidth: isActive ? 2.0 : 1.0)
            
            // Label Text
            Text(label)
                .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundColor(isActive ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.5).cornerRadius(4))
                .rotationEffect(.degrees(90))
                .position(x: arrowLeft ? x - 25 : x + 25, y: (startY + endY) / 2)
        }
    }
}

// MARK: - 3D Coordinate Helper Structures

struct Point3D {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
}

struct RotatedPoint {
    var rx: CGFloat
    var ry: CGFloat
    var rz2: CGFloat
}

// MARK: - 3D Perspective Projection and Sutherland-Hodgman Clipping Projector

struct Rigging3DProjector {
    let centerlineX: CGFloat
    let h: CGFloat
    let zoom: CGFloat
    let distance: CGFloat
    let centerShiftY: CGFloat
    let centerShiftZ: CGFloat
    let dragRotationX: CGFloat
    let dragRotationY: CGFloat
    let nearClip: CGFloat = 3.0
    
    func getRotatedPoint(_ p: Point3D) -> RotatedPoint {
        let dx = p.x
        let dy = p.y - centerShiftY
        let dz = p.z - centerShiftZ
        
        let yawRad = dragRotationY * .pi / 180.0
        let rx = dx * cos(yawRad) - dz * sin(yawRad)
        let rz = dx * sin(yawRad) + dz * cos(yawRad)
        
        let pitchRad = dragRotationX * .pi / 180.0
        let ry = dy * cos(pitchRad) - rz * sin(pitchRad)
        let rz2 = dy * sin(pitchRad) + rz * cos(pitchRad)
        
        return RotatedPoint(rx: rx, ry: ry, rz2: rz2)
    }
    
    func projectRotated(_ rp: RotatedPoint) -> CGPoint {
        let factor = (rp.rz2 + distance) / distance
        let x = centerlineX + (rp.rx * 1.35 * zoom) / factor
        let y = h * 0.5 - (rp.ry * 1.25 * zoom) / factor
        return CGPoint(x: x, y: y)
    }
    
    func project(_ p: Point3D) -> CGPoint {
        return projectRotated(getRotatedPoint(p))
    }
    
    func isPointVisible(_ p: Point3D) -> Bool {
        let rp = getRotatedPoint(p)
        return rp.rz2 + distance >= nearClip
    }
    
    func clipPolygon(_ vertices: [Point3D]) -> [CGPoint] {
        let inputList = vertices.map { getRotatedPoint($0) }
        if inputList.isEmpty { return [] }
        
        var outputList: [RotatedPoint] = []
        
        for i in 0..<inputList.count {
            let current = inputList[i]
            let prev = inputList[(i + inputList.count - 1) % inputList.count]
            
            let dCurrent = current.rz2 + distance
            let dPrev = prev.rz2 + distance
            
            if dCurrent >= nearClip {
                if dPrev < nearClip {
                    let t = (nearClip - dPrev) / (dCurrent - dPrev)
                    let rx = prev.rx + t * (current.rx - prev.rx)
                    let ry = prev.ry + t * (current.ry - prev.ry)
                    let rz2 = -distance + nearClip
                    outputList.append(RotatedPoint(rx: rx, ry: ry, rz2: rz2))
                }
                outputList.append(current)
            } else if dPrev >= nearClip {
                let t = (nearClip - dPrev) / (dCurrent - dPrev)
                let rx = prev.rx + t * (current.rx - prev.rx)
                let ry = prev.ry + t * (current.ry - prev.ry)
                let rz2 = -distance + nearClip
                outputList.append(RotatedPoint(rx: rx, ry: ry, rz2: rz2))
            }
        }
        
        return outputList.map { projectRotated($0) }
    }
    
    func drawClippedPolygon(_ vertices: [Point3D], in path: inout Path) {
        let projectedPoints = clipPolygon(vertices)
        guard projectedPoints.count >= 3 else { return }
        path.move(to: projectedPoints[0])
        for i in 1..<projectedPoints.count {
            path.addLine(to: projectedPoints[i])
        }
        path.closeSubpath()
    }
    
    func drawClippedLine(_ p1: Point3D, _ p2: Point3D, in path: inout Path) {
        let rp1 = getRotatedPoint(p1)
        let rp2 = getRotatedPoint(p2)
        
        let d1 = rp1.rz2 + distance
        let d2 = rp2.rz2 + distance
        
        if d1 < nearClip && d2 < nearClip {
            return
        }
        
        if d1 >= nearClip && d2 >= nearClip {
            path.move(to: projectRotated(rp1))
            path.addLine(to: projectRotated(rp2))
        } else {
            let t = (nearClip - d1) / (d2 - d1)
            let rx_clip = rp1.rx + t * (rp2.rx - rp1.rx)
            let ry_clip = rp1.ry + t * (rp2.ry - rp1.ry)
            let rz2_clip = -distance + nearClip
            let rp_clip = RotatedPoint(rx: rx_clip, ry: ry_clip, rz2: rz2_clip)
            
            let pt_clip = projectRotated(rp_clip)
            if d1 >= nearClip {
                path.move(to: projectRotated(rp1))
                path.addLine(to: pt_clip)
            } else {
                path.move(to: pt_clip)
                path.addLine(to: projectRotated(rp2))
            }
        }
    }
}
