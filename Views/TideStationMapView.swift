import SwiftUI
import MapKit
import Charts

// MARK: - Station Map View
struct TideStationMapView: View {
    @ObservedObject var tideManager: TideManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStation: TideStation? = nil
    @State private var currentSpanDelta: Double = 25.0
    @State private var isExpanded: Bool = false

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 25)
        )
    )

    private var isJA: Bool {
        LocalizationManager.shared.language == .japanese
    }

    /// 縮尺（latitudeDelta）に応じた動的タッチターゲットサイズ (44pt 〜 56pt)
    private var dynamicTapSize: CGFloat {
        if currentSpanDelta > 20 {
            return 56
        } else if currentSpanDelta > 8 {
            return 48
        } else {
            return 44
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Map
                    Map(position: $cameraPosition) {
                        ForEach(tideManager.allStations) { station in
                            Annotation(station.name, coordinate: station.coordinate, anchor: .center) {
                                StationPin(
                                    station: station,
                                    isSelected: selectedStation?.id == station.id,
                                    isCurrentStation: tideManager.nearestStation?.id == station.id,
                                    tapSize: dynamicTapSize
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedStation = station
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .onMapCameraChange { context in
                        currentSpanDelta = context.region.span.latitudeDelta
                    }
                    .ignoresSafeArea(edges: .bottom)

                    // Bottom Sheet for selected station (枠は固定、中身のみふわっと切替)
                    if let station = selectedStation {
                        StationDetailCard(
                            station: station,
                            tideManager: tideManager,
                            isCurrentStation: tideManager.nearestStation?.id == station.id,
                            isExpanded: $isExpanded,
                            maxHeight: geo.size.height * 0.55,
                            isJA: isJA,
                            onSelect: {
                                tideManager.selectStation(station)
                                dismiss()
                            },
                            onResetToNearest: {
                                tideManager.resetToNearestStation()
                                dismiss()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(isJA ? "観測所を選択" : "Select Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isJA ? "閉じる" : "Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .onAppear {
                let target = tideManager.selectedStation ?? tideManager.nearestStation
                if let target = target {
                    selectedStation = target
                }
            }
        }
    }
}

// MARK: - Station Pin
struct StationPin: View {
    let station: TideStation
    let isSelected: Bool
    let isCurrentStation: Bool
    let tapSize: CGFloat

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: tapSize, height: tapSize)
                .contentShape(Circle())

            Circle()
                .fill(isCurrentStation ? Theme.secondaryAccent : Theme.accent)
                .frame(width: isSelected ? 16 : 9, height: isSelected ? 16 : 9)
                .shadow(color: (isCurrentStation ? Theme.secondaryAccent : Theme.accent).opacity(0.7),
                        radius: isSelected ? 6 : 2)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.25 : 1.0)
        }
        .frame(width: tapSize, height: tapSize)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Station Detail Card (引き出し対応シート - ふわっと中身切替 & プリロード即時表示)
struct StationDetailCard: View {
    let station: TideStation
    @ObservedObject var tideManager: TideManager
    let isCurrentStation: Bool
    @Binding var isExpanded: Bool
    let maxHeight: CGFloat
    let isJA: Bool
    let onSelect: () -> Void
    let onResetToNearest: () -> Void

    @State private var previewTideData: TideData? = nil
    @State private var isLoadingPreview: Bool = false
    @GestureState private var dragOffset: CGFloat = 0

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: LocalizationManager.shared.language.identifier)
        f.setLocalizedDateFormatFromTemplate("MdE")
        return f
    }

    private var keyFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle Bar (ドラッグ・タップで展開/格納)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    Text(isExpanded ? (isJA ? "たたむ" : "Collapse") : (isJA ? "引き出して潮位を表示" : "Pull up for Tide"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.bottom, 8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if value.translation.height < -40 {
                                isExpanded = true
                            } else if value.translation.height > 40 {
                                isExpanded = false
                            }
                        }
                    }
            )

            // Header Section: Station Name & Action Buttons
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(isCurrentStation ? Theme.secondaryAccent : Theme.accent)
                            .font(.title3)

                        Text(station.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textMain)
                            .id("name_\(station.id)")
                            .transition(.opacity)

                        if let tideData = previewTideData {
                            Text(tideData.tideType)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.15))
                                .cornerRadius(6)
                                .id("tideType_\(station.id)")
                                .transition(.opacity)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(String(format: "%.4f°N, %.4f°E",
                                    station.coordinate.latitude,
                                    station.coordinate.longitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .id("coord_\(station.id)")
                            .transition(.opacity)
                    }

                    if isCurrentStation {
                        Text(isJA ? "現在地に最も近い地点" : "Nearest to your location")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(Theme.secondaryAccent)
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    Button {
                        onSelect()
                    } label: {
                        Text(isJA ? "ここを登録する" : "Register Station")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Theme.accent.opacity(0.4), radius: 6, y: 3)
                    }

                    if !isCurrentStation {
                        Button {
                            onResetToNearest()
                        } label: {
                            Text(isJA ? "GPS最寄りに戻す" : "Reset to Nearest")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.25), value: station.id)

            // Expanded Preview Section (指定観測所の潮位グラフ & 満干潮情報)
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 16)

                    if isLoadingPreview && previewTideData == nil {
                        ProgressView()
                            .tint(Theme.accent)
                            .frame(height: 140)
                            .transition(.opacity)
                    } else if let tideData = previewTideData {
                        VStack(spacing: 12) {
                            // 1. ミニ潮位グラフ (時間軸 + 高さ軸/水位cm付き)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dateFormatter.string(from: Date()))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.textMain)
                                    Spacer()
                                    Text(isJA ? "本日の潮位推移" : "Today's Tide Trend")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.horizontal, 20)

                                Chart {
                                    ForEach(tideData.hourlyLevels) { item in
                                        LineMark(
                                            x: .value("Hour", item.hour),
                                            y: .value("Level", item.level)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Theme.primaryGradient)
                                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                                        AreaMark(
                                            x: .value("Hour", item.hour),
                                            y: .value("Level", item.level)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(LinearGradient(
                                            colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ))
                                    }

                                    // 現在時刻インジケータ
                                    let currentHour = Calendar.current.component(.hour, from: Date())
                                    RuleMark(x: .value("Now", currentHour))
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .chartXScale(domain: 0...23)
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                                        AxisValueLabel {
                                            if let level = val.as(Int.self) {
                                                Text("\(level)cm")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: [0, 6, 12, 18, 23]) { val in
                                        AxisValueLabel {
                                            if let h = val.as(Int.self) {
                                                Text("\(h)h")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 110)
                                .padding(.leading, 12)
                                .padding(.trailing, 16)
                            }

                            // 2. 指定観測所の満潮 / 干潮 時刻一覧
                            HStack(spacing: 12) {
                                // 満潮
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(Theme.secondaryAccent)
                                            .font(.caption2)
                                        Text(isJA ? "満潮" : "High")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    ForEach(tideData.highTides.prefix(2), id: \.time) { event in
                                        HStack {
                                            Text(event.time)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundColor(Theme.textMain)
                                            Spacer()
                                            Text("\(event.level)cm")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    if tideData.highTides.isEmpty {
                                        Text("--:--").font(.caption).foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Theme.cardBackground.opacity(0.6))
                                .cornerRadius(10)

                                // 干潮
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(Theme.accent)
                                            .font(.caption2)
                                        Text(isJA ? "干潮" : "Low")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    ForEach(tideData.lowTides.prefix(2), id: \.time) { event in
                                        HStack {
                                            Text(event.time)
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundColor(Theme.textMain)
                                            Spacer()
                                            Text("\(event.level)cm")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    if tideData.lowTides.isEmpty {
                                        Text("--:--").font(.caption).foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Theme.cardBackground.opacity(0.6))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 16)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .frame(maxHeight: isExpanded ? maxHeight : nil)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: .black.opacity(0.35), radius: 20, y: -6)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
        .onChange(of: station.id, initial: true) { _, _ in
            loadTideDataForStation()
        }
    }

    private func loadTideDataForStation() {
        let todayKey = keyFormatter.string(from: Date())
        let cacheKey = "\(station.id)_\(todayKey)"

        // 1. 既にプリロード済みキャッシュにあれば即時（0ミリ秒）セット
        if let cached = tideManager.tideDataCache[cacheKey] {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.previewTideData = cached
                self.isLoadingPreview = false
            }
            return
        }

        // 2. キャッシュにまだ無ければ非同期取得
        withAnimation(.easeInOut(duration: 0.2)) {
            self.isLoadingPreview = true
        }
        tideManager.fetchTideData(for: station, date: Date()) { data in
            withAnimation(.easeInOut(duration: 0.25)) {
                self.previewTideData = data
                self.isLoadingPreview = false
            }
        }
    }
}
