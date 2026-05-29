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
                Text("\(crewInfo.boatType.displayName) (\(crewInfo.boatType.rawValue))")
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
                BoatHullShape(boatType: crewInfo.boatType)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.15), Theme.secondaryAccent.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                BoatHullShape(boatType: crewInfo.boatType)
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
                
                // オールの描画
                oarsOverlay(width: width, height: height)
                
                // 座席とクルー名
                seatsOverlay(width: width, height: height)
            }
        }
        .frame(height: seatRowHeight)
    }
    
    private var seatRowHeight: CGFloat {
        if isCompact {
            return crewInfo.boatType.isScull ? 80 : 80
        }
        return crewInfo.boatType.isScull ? 110 : 110
    }
    
    // MARK: - Oars
    
    private func oarsOverlay(width: CGFloat, height: CGFloat) -> some View {
        let seats = crewInfo.boatType.totalSeats
        let hasCox = crewInfo.boatType.hasCoxswain
        let rowerCount = crewInfo.boatType.rowerCount
        let isScull = crewInfo.boatType.isScull
        
        // 座席配置：左（船首/バウ）→ 右（船尾/ストローク）
        // コックスは一番右（船尾側）
        let usableWidth = width * 0.85
        let startX = width * 0.075
        let centerY = height / 2
        
        return ZStack {
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
    
    // MARK: - Seats
    
    private func seatsOverlay(width: CGFloat, height: CGFloat) -> some View {
        let seats = crewInfo.boatType.totalSeats
        let hasCox = crewInfo.boatType.hasCoxswain
        let rowerCount = crewInfo.boatType.rowerCount
        let labels = crewInfo.boatType.seatLabels
        
        let usableWidth = width * 0.85
        let startX = width * 0.075
        let centerY = height / 2
        
        return ZStack {
            ForEach(0..<seats, id: \.self) { index in
                let totalPositions = seats
                let seatX = startX + (usableWidth / CGFloat(totalPositions + 1)) * CGFloat(index + 1)
                let isCox = hasCox && index == seats - 1
                let memberName = index < crewInfo.members.count ? crewInfo.members[index] : ""
                let isEmpty = memberName.trimmingCharacters(in: .whitespaces).isEmpty
                
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
                            Image(systemName: "person.fill")
                                .font(.system(size: isCompact ? 8 : 10))
                                .foregroundColor(isEmpty ? Theme.textSecondary.opacity(0.5) : Theme.accent)
                        }
                    }
                    
                    // クルー名
                    Text(isEmpty ? "—" : memberName)
                        .font(.system(size: isCompact ? 8 : 10, weight: isEmpty ? .regular : .semibold))
                        .foregroundColor(isEmpty ? Theme.textSecondary.opacity(0.5) : Theme.textMain)
                        .lineLimit(1)
                        .frame(maxWidth: isCompact ? 40 : 55)
                }
                .position(x: seatX, y: centerY)
            }
            
            // 船首方向インジケーター
            HStack(spacing: 2) {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 8))
                Text("Bow")
                    .font(.system(size: 8))
            }
            .foregroundColor(Theme.textSecondary.opacity(0.5))
            .position(x: width * 0.03, y: height - 10)
        }
    }
}

// MARK: - Boat Hull Shape

struct BoatHullShape: Shape {
    let boatType: BoatType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let centerY = h / 2
        let boatHeight: CGFloat = h * 0.22 // ボートの高さ（幅）
        
        // 船首（左側）: 尖った形
        let bowX: CGFloat = w * 0.03
        // 船尾（右側）: やや丸い
        let sternX: CGFloat = w * 0.97
        
        // 上部ライン
        path.move(to: CGPoint(x: bowX, y: centerY))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.2, y: centerY - boatHeight),
            control: CGPoint(x: w * 0.08, y: centerY - boatHeight * 0.3)
        )
        path.addLine(to: CGPoint(x: w * 0.8, y: centerY - boatHeight))
        path.addQuadCurve(
            to: CGPoint(x: sternX, y: centerY),
            control: CGPoint(x: w * 0.95, y: centerY - boatHeight * 0.5)
        )
        
        // 下部ライン（逆方向）
        path.addQuadCurve(
            to: CGPoint(x: w * 0.8, y: centerY + boatHeight),
            control: CGPoint(x: w * 0.95, y: centerY + boatHeight * 0.5)
        )
        path.addLine(to: CGPoint(x: w * 0.2, y: centerY + boatHeight))
        path.addQuadCurve(
            to: CGPoint(x: bowX, y: centerY),
            control: CGPoint(x: w * 0.08, y: centerY + boatHeight * 0.3)
        )
        
        path.closeSubpath()
        return path
    }
}
