import SwiftUI
import CoreBluetooth

/// マネージャーモード：横画面レース表示ビュー
/// 単一距離ワークアウト時にデバイスを横向きにすると表示される
/// 1位からのリアルタイム差分と進行度バーでレース状況を可視化
struct ManagerRaceView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @Binding var showRepeatAlert: Bool
    @Binding var showModeSettings: Bool
    @Binding var showEditSheet: Bool
    
    // MARK: - Zoom State
    @State private var showZoomSettings = false
    @AppStorage("raceZoomEnabled") private var zoomEnabled: Bool = false
    @AppStorage("raceZoomDistanceBehind") private var zoomDistanceBehind: Double = 100  // 先頭から後方何mまで表示
    @AppStorage("raceZoomMaxBoats") private var zoomMaxBoats: Int = 10                   // 後方何人まで表示
    
    /// ソート済みの選手データ（距離の多い順 = 先行順）
    private var rankedDevices: [(peripheral: CBPeripheral, metrics: PM5DeviceMetrics, rank: Int)] {
        let devices = viewModel.connectedDevices.compactMap { device -> (CBPeripheral, PM5DeviceMetrics)? in
            guard let m = viewModel.deviceMetrics[device.identifier] else { return nil }
            return (device, m)
        }
        let sorted = devices.sorted { $0.1.distance > $1.1.distance }
        return sorted.enumerated().map { (index, pair) in
            (peripheral: pair.0, metrics: pair.1, rank: index + 1)
        }
    }
    
    /// ズーム適用後の表示対象デバイス（上位N名）
    private var visibleDevices: [(peripheral: CBPeripheral, metrics: PM5DeviceMetrics, rank: Int)] {
        return rankedDevices.prefix(zoomMaxBoats).map { $0 }
    }
    
    private var leaderDistance: Double {
        rankedDevices.first?.metrics.distance ?? 0
    }
    
    private var targetDistance: Double {
        Double(viewModel.workoutDistance ?? 2000)
    }
    
    /// ズーム時の表示範囲（距離の開始〜終了）
    private var visibleDistanceRange: (start: Double, end: Double) {
        let totalDist = targetDistance
        guard zoomEnabled else {
            return (start: 0, end: totalDist)
        }
        
        let leader = leaderDistance
        // 実際のズーム幅は設定値と目標距離の小さい方
        let actualSpan = min(zoomDistanceBehind, totalDist)
        
        // 先頭の位置から後方 actualSpan 分の範囲を表示
        // 少し先頭の前方にも余裕を持たせる (10%)
        let frontMargin = actualSpan * 0.1
        let rangeEnd = min(leader + frontMargin, totalDist)
        let rangeStart = max(rangeEnd - actualSpan, 0)
        
        // rangeStartが0の場合、rangeEndを調整して常にactualSpan分表示するようにする（距離が短い場合に対応）
        if rangeStart == 0 {
            return (start: 0, end: min(actualSpan, totalDist))
        }
        
        return (start: rangeStart, end: rangeEnd)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                Color(hex: "1A1A2E").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Toolbar (上部)
                    raceToolbar
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                    
                    // MARK: - Distance Scale Header
                    raceScaleHeader(width: geo.size.width)
                        .padding(.bottom, 2)
                    
                    // MARK: - Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                    
                    // MARK: - Race Rows
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(visibleDevices.enumerated()), id: \.element.peripheral.identifier) { index, entry in
                                VStack(spacing: 0) {
                                    RaceRowView(
                                        rank: entry.rank,
                                        displayName: viewModel.displayName(for: entry.peripheral),
                                        deviceNumber: viewModel.deviceNumbers[entry.peripheral.identifier] ?? 0,
                                        metrics: entry.metrics,
                                        leaderDistance: leaderDistance,
                                        targetDistance: targetDistance,
                                        trackWidth: geo.size.width,
                                        isDisconnected: viewModel.disconnectedDeviceIDs.contains(entry.peripheral.identifier),
                                        zoomEnabled: zoomEnabled,
                                        visibleRangeStart: visibleDistanceRange.start,
                                        visibleRangeEnd: visibleDistanceRange.end
                                    )
                                    .zIndex(Double(visibleDevices.count - index))
                                    
                                    if index < visibleDevices.count - 1 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.8), value: visibleDevices.map { $0.peripheral.identifier })
                    }
                }
            }
        }
    }
    
    // MARK: - Top Toolbar
    private var raceToolbar: some View {
        HStack {
            // ズームインジケーター（有効時のみ）
            if zoomEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(Int(zoomDistanceBehind))m / \(zoomMaxBoats)艇")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Color(hex: "4FC3F7"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "4FC3F7").opacity(0.15))
                .cornerRadius(6)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // ズーム設定
                Button(action: { showZoomSettings.toggle() }) {
                    Image(systemName: "ruler")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(zoomEnabled ? Color(hex: "4FC3F7") : .white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(zoomEnabled ? Color(hex: "4FC3F7").opacity(0.2) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(zoomEnabled ? Color(hex: "4FC3F7").opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                }
                .popover(isPresented: $showZoomSettings) {
                    zoomSettingsPopover
                }
                
                // もう一度
                Button(action: { showRepeatAlert = true }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // モード設定
                Button(action: { showModeSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // PM5編集
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // MARK: - Zoom Settings Popover
    private var zoomSettingsPopover: some View {
        VStack(spacing: 16) {
            // ヘッダー
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(Color(hex: "4FC3F7"))
                Text("レースズーム")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            
            // ON/OFF トグル
            Toggle(isOn: $zoomEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: zoomEnabled ? "scope" : "arrow.left.and.right")
                        .foregroundColor(zoomEnabled ? Color(hex: "4FC3F7") : .secondary)
                    Text(zoomEnabled ? "ズーム有効" : "全体表示")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .tint(Color(hex: "4FC3F7"))
            
            if zoomEnabled {
                Divider()
                
                // 後方距離
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("表示範囲（先頭からの距離）")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(zoomDistanceBehind))m")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "4FC3F7"))
                    }
                    Slider(value: $zoomDistanceBehind, in: 20...500, step: 10)
                        .tint(Color(hex: "4FC3F7"))
                    HStack {
                        Text("20m")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("500m")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 最大表示人数
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("最大表示人数")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(zoomMaxBoats)艇")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "4FC3F7"))
                    }
                    Slider(value: Binding(
                        get: { Double(zoomMaxBoats) },
                        set: { zoomMaxBoats = Int($0) }
                    ), in: 2...10, step: 1)
                        .tint(Color(hex: "4FC3F7"))
                    HStack {
                        Text("2艇")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("10艇")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .presentationCompactAdaptation(.popover)
    }
    
    // MARK: - Distance Scale Header
    private func raceScaleHeader(width: CGFloat) -> some View {
        let nameColumnWidth: CGFloat = 120
        let rightInfoWidth: CGFloat = 100
        let trackWidth = width - nameColumnWidth - rightInfoWidth - 16
        
        let range = visibleDistanceRange
        let visibleSpan = range.end - range.start
        
        // ズーム時はより細かい目盛りを表示
        let markerStep: Double
        if zoomEnabled {
            // 表示範囲に応じて適切な目盛り間隔を決定
            if visibleSpan <= 30 {
                markerStep = 5
            } else if visibleSpan <= 60 {
                markerStep = 10
            } else if visibleSpan <= 150 {
                markerStep = 25
            } else if visibleSpan <= 300 {
                markerStep = 50
            } else {
                markerStep = 100
            }
        } else {
            let totalDist = targetDistance
            markerStep = totalDist / 5.0
        }
        
        // 目盛り位置を計算
        let firstMarker = ceil(range.start / markerStep) * markerStep
        var markers: [Double] = []
        var m = firstMarker
        while m <= range.end {
            markers.append(m)
            m += markerStep
        }
        
        return HStack(spacing: 0) {
            // 名前列の空白
            Color.clear.frame(width: nameColumnWidth)
            
            // スケールバー
            ZStack(alignment: .leading) {
                // 背景線
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 2)
                
                // 目盛り
                ForEach(Array(markers.enumerated()), id: \.offset) { _, dist in
                    let remaining = targetDistance - dist
                    let normalizedProgress: CGFloat = zoomEnabled
                        ? ((range.end - range.start) > 0 ? CGFloat((dist - range.start) / (range.end - range.start)) : 0)
                        : CGFloat(dist / targetDistance)
                    let xPos = trackWidth * normalizedProgress
                    
                    VStack(spacing: 0) {
                        Text("\(Int(remaining))m")
                            .font(.system(size: zoomEnabled ? 10 : 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 1, height: 6)
                    }
                    .position(x: xPos, y: 8)
                }
            }
            .frame(width: trackWidth, height: 28)
            
            // 右情報列の空白
            Color.clear.frame(width: rightInfoWidth)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Race Row View
struct RaceRowView: View {
    let rank: Int
    let displayName: String
    let deviceNumber: Int
    let metrics: PM5DeviceMetrics
    let leaderDistance: Double
    let targetDistance: Double
    let trackWidth: CGFloat
    let isDisconnected: Bool
    var zoomEnabled: Bool = false
    var visibleRangeStart: Double = 0
    var visibleRangeEnd: Double = 0
    
    private let nameColumnWidth: CGFloat = 120
    private let rightInfoWidth: CGFloat = 100
    
    /// 1位との差（メートル）
    private var gapToLeader: Double {
        leaderDistance - metrics.distance
    }
    
    /// レース進行度（0.0 ~ 1.0）
    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(metrics.distance / targetDistance, 1.0)
    }
    
    /// ズーム時の表示進行度
    private var displayProgress: Double {
        if zoomEnabled {
            let span = visibleRangeEnd - visibleRangeStart
            guard span > 0 else { return 0 }
            return min(max((metrics.distance - visibleRangeStart) / span, 0), 1.0)
        }
        return progress
    }
    
    /// ボートの色（1位は金色、2位は銀色、3位は銅色、4位以下は標準色）
    private var boatColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700")   // Gold
        case 2: return Color(hex: "C0C0C0")   // Silver
        case 3: return Color(hex: "CD7F32")   // Bronze
        default: return Color(hex: "4FC3F7")  // Light Blue
        }
    }
    
    /// ランクのバッジ色
    private var rankBadgeColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700")
        case 2: return Color(hex: "A0A0A0")
        case 3: return Color(hex: "CD7F32")
        default: return Color.white.opacity(0.3)
        }
    }
    
    var body: some View {
        let barTrackWidth = trackWidth - nameColumnWidth - rightInfoWidth - 16
        
        HStack(spacing: 0) {
            // MARK: - Left: Rank + Name
            HStack(spacing: 6) {
                // ランクバッジ
                Text("\(rank)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(rank <= 3 ? .black : .white)
                    .frame(width: 22, height: 22)
                    .background(rankBadgeColor)
                    .cornerRadius(4)
                
                // 名前
                Text(displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDisconnected ? .gray : .white)
                    .lineLimit(1)
            }
            .frame(width: nameColumnWidth, alignment: .leading)
            
            // MARK: - Center: Track with Boat
            ZStack(alignment: .leading) {
                // トラック背景
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 28)
                
                // ボートとテキスト
                let maxBoatX = barTrackWidth - 22
                let boatX = max(maxBoatX * CGFloat(displayProgress), 0)
                
                ZStack {
                    // ゴールタイム
                    if progress >= 1.0 {
                        Text(formatFinishTime(seconds: metrics.elapsedTime))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .position(x: boatX - 28, y: 14)
                    }
                    
                    // ボート
                    BoatShape()
                        .fill(boatColor)
                        .frame(width: 22, height: 12)
                        .shadow(color: boatColor.opacity(0.4), radius: 2, x: 0, y: 0)
                        .position(x: boatX + 11, y: 10)
                    
                    // 差分
                    if rank > 1 && gapToLeader > 0 && progress < 1.0 {
                        Text(zoomEnabled ? String(format: "%.1fm", gapToLeader) : "\(Int(gapToLeader))m")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                            .position(x: boatX + 22 + 16, y: 10)
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: displayProgress)
            }
            .frame(width: barTrackWidth, height: 28)
            
            // MARK: - Right: SPM + Pace
            HStack(spacing: 8) {
                // SPM
                Text("\(metrics.strokeRate)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isDisconnected ? .gray : .white)
                    .frame(width: 28, alignment: .trailing)
                
                // 500m Pace
                Text(formatPace(seconds: metrics.pace500m))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isDisconnected ? .gray : .white)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: rightInfoWidth, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rank == 1 ? Color(hex: "FFD700").opacity(0.06) : Color.clear)
        .opacity(isDisconnected ? 0.5 : 1.0)
    }
    
    private func formatPace(seconds: Double) -> String {
        guard seconds > 0 && seconds < 600 else { return "-:--" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private func formatFinishTime(seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let ms = Int((seconds - Double(totalSeconds)) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}

// MARK: - Boat Shape
/// 参考画像に近い、旗/ペナント型のボートシェイプ
/// 先端が右で、後方がV字にくぼんだ形
struct BoatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 後方左上
        path.move(to: CGPoint(x: 0, y: 0))
        // 上辺（先端に向かって若干すぼまる）
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.1))
        // 先端（シャープなポイント）
        path.addLine(to: CGPoint(x: w, y: h * 0.5))
        // 下辺
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.9))
        // 後方左下
        path.addLine(to: CGPoint(x: 0, y: h))
        // 後方のV字くぼみ
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.5))
        path.closeSubpath()
        
        return path
    }
}
