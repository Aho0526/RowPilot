import SwiftUI

/// ボートの形状を視覚的に表示し、各座席にクルー名を表示するコンポーネント
struct BoatDiagramView: View {
    let crewInfo: CrewInfo
    var isCompact: Bool = false
    
    var body: some View {
        VStack(spacing: isCompact ? 8 : 16) {
            // ボートタイプラベル
            HStack(spacing: 6) {
                Image(systemName: crewInfo.boatType.iconName)
                    .font(.system(size: isCompact ? 14 : 16))
                    .foregroundColor(Theme.accent)
                Text("\(crewInfo.boatType.displayName) (\(crewInfo.boatType.displayName == "エイト" ? "8+" : crewInfo.boatType.rawValue))")
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textMain)
            }
            
            // ボート図
            boatDiagram
        }
    }
    
    private var boatDiagram: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                // ボート本体（船体）
                BoatHullShape(boatType: crewInfo.boatType, isCompact: isCompact)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.15), Theme.secondaryAccent.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                BoatHullShape(boatType: crewInfo.boatType, isCompact: isCompact)
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
                
                // オールの描画 (ペア、ダブル、シングル以外は表示しない)
                oarsOverlay(width: width, height: height)
                
                // 座席とクルー名
                seatsOverlay(width: width, height: height)
            }
        }
        .frame(height: seatRowHeight)
    }
    
    private var seatRowHeight: CGFloat {
        let type = crewInfo.boatType
        if isCompact {
            switch type {
            case .singleSculls, .doubleSculls, .pair:
                return 80
            case .coxedQuad, .four:
                return 110
            case .eight:
                return 130
            }
        } else {
            switch type {
            case .singleSculls, .doubleSculls, .pair:
                return 110
            case .coxedQuad, .four:
                return 140
            case .eight:
                return 170
            }
        }
    }
    
    // MARK: - Dimensions Calculation
    
    private func getBoatDimensions(width: CGFloat) -> (boatWidth: CGFloat, bowX: CGFloat, usableWidth: CGFloat, startX: CGFloat) {
        let widthFactor: CGFloat
        switch crewInfo.boatType {
        case .singleSculls: widthFactor = 0.52
        case .doubleSculls, .pair: widthFactor = 0.66
        case .coxedQuad, .four: widthFactor = 0.80
        case .eight: widthFactor = 1.00
        }
        
        let boatWidth = width * widthFactor
        let bowX = (width - boatWidth) / 2
        let usableWidth = boatWidth * 0.85
        let startX = bowX + boatWidth * 0.075
        
        return (boatWidth, bowX, usableWidth, startX)
    }
    
    // MARK: - Oars
    
    @ViewBuilder
    private func oarsOverlay(width: CGFloat, height: CGFloat) -> some View {
        let type = crewInfo.boatType
        // ペア(2-)とダブル(2x)、シングル(1x)以外はオールを表示しない
        if type == .doubleSculls || type == .pair || type == .singleSculls {
            let seats = type.totalSeats
            let hasCox = type.hasCoxswain
            let rowerCount = type.rowerCount
            let isScull = type.isScull
            
            let dim = getBoatDimensions(width: width)
            let usableWidth = dim.usableWidth
            let startX = dim.startX
            let centerY = height / 2
            
            ZStack {
                ForEach(0..<rowerCount, id: \.self) { index in
                    let totalPositions = hasCox ? seats : rowerCount
                    let seatX = startX + (usableWidth / CGFloat(totalPositions + 1)) * CGFloat(index + 1)
                    
                    if isScull {
                        // スカル: 両側にオール
                        // 上側オール
                        Path { path in
                            path.move(to: CGPoint(x: seatX, y: centerY))
                            path.addLine(to: CGPoint(x: seatX - 4, y: centerY - 22))
                        }
                        .stroke(Theme.accent.opacity(0.4), lineWidth: 1.5)
                        
                        // 下側オール
                        Path { path in
                            path.move(to: CGPoint(x: seatX, y: centerY))
                            path.addLine(to: CGPoint(x: seatX - 4, y: centerY + 22))
                        }
                        .stroke(Theme.accent.opacity(0.4), lineWidth: 1.5)
                    } else {
                        // スイープ: 交互にオール
                        let isPortSide = index % 2 == 0
                        Path { path in
                            path.move(to: CGPoint(x: seatX, y: centerY))
                            path.addLine(to: CGPoint(x: seatX - 6, y: isPortSide ? centerY - 24 : centerY + 24))
                        }
                        .stroke(Theme.accent.opacity(0.4), lineWidth: 1.5)
                    }
                }
            }
        }
    }
    
    // MARK: - Seats
    
    struct SeatLayoutInfo {
        let nameX: CGFloat
        let nameY: CGFloat
        let lineStart: CGPoint
        let lineMid: CGPoint
        let lineEnd: CGPoint
        let drawLine: Bool
    }
    
    private func getLayoutInfo(index: Int, centerY: CGFloat, seatX: CGFloat, boatType: BoatType) -> SeatLayoutInfo {
        let abs_dx: CGFloat = isCompact ? 9.0 : 12.0
        let horizontalLength: CGFloat = isCompact ? 12.0 : 16.0
        let dir: CGFloat = 1.0 // すべて右方向に曲げることでエレガントに統一
        
        switch boatType {
        case .singleSculls, .doubleSculls, .pair:
            // シングル、ダブル、ペア艇：既存のまま（下に縦並び、線は描画しない）
            let nameY = centerY + (isCompact ? 28.0 : 34.0)
            return SeatLayoutInfo(
                nameX: seatX,
                nameY: nameY,
                lineStart: .zero,
                lineMid: .zero,
                lineEnd: .zero,
                drawLine: false
            )
            
        case .coxedQuad, .four:
            // クォード、フォア：上下に1人飛ばしで配置
            let isTop = index % 2 == 0
            let nameOffsetY: CGFloat = isCompact ? 35.0 : 45.0
            let nameY = isTop ? centerY - nameOffsetY : centerY + nameOffsetY
            
            let lineStart = CGPoint(
                x: seatX,
                y: isTop ? centerY - (isCompact ? 9.0 : 12.0) : centerY + (isCompact ? 9.0 : 12.0)
            )
            let lineMid = CGPoint(
                x: seatX + dir * abs_dx,
                y: nameY
            )
            let lineEnd = CGPoint(
                x: seatX + dir * (abs_dx + horizontalLength),
                y: nameY
            )
            
            // テキストは水平線の上に載せる（または下に吊るす）
            let textY = isTop ? nameY - (isCompact ? 6.0 : 8.0) : nameY + (isCompact ? 6.0 : 8.0)
            let textX = seatX + dir * (abs_dx + horizontalLength / 2.0)
            
            return SeatLayoutInfo(
                nameX: textX,
                nameY: textY,
                lineStart: lineStart,
                lineMid: lineMid,
                lineEnd: lineEnd,
                drawLine: true
            )
            
        case .eight:
            // エイト：2人ずつ名前を配置し、被らないように少しずらす
            let isTop = (index / 2) % 2 == 0
            let isFurther = index % 2 != 0 && index != boatType.totalSeats - 1
            
            let nameOffsetY: CGFloat
            if isFurther {
                nameOffsetY = isCompact ? 52.0 : 68.0
            } else {
                nameOffsetY = isCompact ? 32.0 : 42.0
            }
            
            let nameY = isTop ? centerY - nameOffsetY : centerY + nameOffsetY
            
            let lineStart = CGPoint(
                x: seatX,
                y: isTop ? centerY - (isCompact ? 9.0 : 12.0) : centerY + (isCompact ? 9.0 : 12.0)
            )
            let lineMid = CGPoint(
                x: seatX + dir * abs_dx,
                y: nameY
            )
            let lineEnd = CGPoint(
                x: seatX + dir * (abs_dx + horizontalLength),
                y: nameY
            )
            
            let textY = isTop ? nameY - (isCompact ? 6.0 : 8.0) : nameY + (isCompact ? 6.0 : 8.0)
            let textX = seatX + dir * (abs_dx + horizontalLength / 2.0)
            
            return SeatLayoutInfo(
                nameX: textX,
                nameY: textY,
                lineStart: lineStart,
                lineMid: lineMid,
                lineEnd: lineEnd,
                drawLine: true
            )
        }
    }
    
    private func seatsOverlay(width: CGFloat, height: CGFloat) -> some View {
        let seats = crewInfo.boatType.totalSeats
        let hasCox = crewInfo.boatType.hasCoxswain
        let labels = crewInfo.boatType.seatLabels
        
        let dim = getBoatDimensions(width: width)
        let usableWidth = dim.usableWidth
        let startX = dim.startX
        let centerY = height / 2
        
        return ZStack {
            // グレーの引き出し線を描画 (斜め -> 水平)
            ForEach(0..<seats, id: \.self) { index in
                let totalPositions = seats
                let seatX = startX + (usableWidth / CGFloat(totalPositions + 1)) * CGFloat(index + 1)
                
                let layout = getLayoutInfo(index: index, centerY: centerY, seatX: seatX, boatType: crewInfo.boatType)
                
                if layout.drawLine {
                    Path { path in
                        path.move(to: layout.lineStart)
                        path.addLine(to: layout.lineMid)
                        path.addLine(to: layout.lineEnd)
                    }
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                }
            }
            
            // シートアイコンとラベルの描画
            ForEach(0..<seats, id: \.self) { index in
                let totalPositions = seats
                let seatX = startX + (usableWidth / CGFloat(totalPositions + 1)) * CGFloat(index + 1)
                let isCox = hasCox && index == seats - 1
                
                VStack(spacing: 2) {
                    // 座席ラベル
                    Text(labels[index])
                        .font(.system(size: isCompact ? 7 : 9, weight: .bold, design: .rounded))
                        .foregroundColor(isCox ? .orange : Theme.accent)
                    
                    // 座席アイコン
                    ZStack {
                        Circle()
                            .fill(isCox ? Color.orange.opacity(0.3) : Theme.accent.opacity(0.2))
                            .frame(width: isCompact ? 18 : 24, height: isCompact ? 18 : 24)
                        
                        if isCox {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: isCompact ? 8 : 10))
                                .foregroundColor(.orange)
                        } else {
                            let memberName = index < crewInfo.members.count ? crewInfo.members[index] : ""
                            let isEmpty = memberName.trimmingCharacters(in: .whitespaces).isEmpty
                            Image(systemName: "person.fill")
                                .font(.system(size: isCompact ? 8 : 10))
                                .foregroundColor(isEmpty ? Theme.textSecondary.opacity(0.5) : Theme.accent)
                        }
                    }
                }
                .position(x: seatX, y: centerY - (isCompact ? 5.5 : 6.5))
            }
            
            // クルー名の描画 (水平線の上または下)
            ForEach(0..<seats, id: \.self) { index in
                let totalPositions = seats
                let seatX = startX + (usableWidth / CGFloat(totalPositions + 1)) * CGFloat(index + 1)
                let memberName = index < crewInfo.members.count ? crewInfo.members[index] : ""
                let isEmpty = memberName.trimmingCharacters(in: .whitespaces).isEmpty
                
                let layout = getLayoutInfo(index: index, centerY: centerY, seatX: seatX, boatType: crewInfo.boatType)
                
                Text(isEmpty ? "—" : memberName)
                    .font(.system(size: isCompact ? 8 : 10, weight: isEmpty ? .regular : .semibold))
                    .foregroundColor(isEmpty ? Theme.textSecondary.opacity(0.5) : Theme.textMain)
                    .lineLimit(1)
                    .frame(maxWidth: isCompact ? 40 : 55)
                    .position(x: layout.nameX, y: layout.nameY)
            }
            
            // 船首方向インジケーター
            HStack(spacing: 2) {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 8))
                Text("Bow")
                    .font(.system(size: 8))
            }
            .foregroundColor(Theme.textSecondary.opacity(0.5))
            .position(x: dim.bowX + dim.boatWidth * 0.03, y: height - 10)
        }
    }
}

// MARK: - Boat Hull Shape

struct BoatHullShape: Shape {
    let boatType: BoatType
    let isCompact: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let centerY = h / 2
        let boatHeight: CGFloat = isCompact ? 9 : 13 // ボートの高さの半分（固定幅にしてスリムさを維持）
        
        // Calculate centered bounds based on widthFactor
        let widthFactor: CGFloat
        switch boatType {
        case .singleSculls: widthFactor = 0.52
        case .doubleSculls, .pair: widthFactor = 0.66
        case .coxedQuad, .four: widthFactor = 0.80
        case .eight: widthFactor = 1.00
        }
        
        let boatWidth = w * widthFactor
        let bowX = (w - boatWidth) / 2 + boatWidth * 0.03
        let sternX = (w - boatWidth) / 2 + boatWidth * 0.97
        
        // 上部ライン
        path.move(to: CGPoint(x: bowX, y: centerY))
        path.addQuadCurve(
            to: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.2, y: centerY - boatHeight),
            control: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.08, y: centerY - boatHeight * 0.3)
        )
        path.addLine(to: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.8, y: centerY - boatHeight))
        path.addQuadCurve(
            to: CGPoint(x: sternX, y: centerY),
            control: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.95, y: centerY - boatHeight * 0.5)
        )
        
        // 下部ライン（逆方向）
        path.addQuadCurve(
            to: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.8, y: centerY + boatHeight),
            control: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.95, y: centerY + boatHeight * 0.5)
        )
        path.addLine(to: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.2, y: centerY + boatHeight))
        path.addQuadCurve(
            to: CGPoint(x: bowX, y: centerY),
            control: CGPoint(x: (w - boatWidth) / 2 + boatWidth * 0.08, y: centerY + boatHeight * 0.3)
        )
        
        path.closeSubpath()
        return path
    }
}
