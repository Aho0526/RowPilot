import SwiftUI
import Charts
import CoreLocation
import MapKit

struct TideView: View {
    @EnvironmentObject var app: AppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        TideContent(tideManager: app.tideManager)
            .id(themeManager.currentPreset)
    }
}

//MARK: - Internal View
struct TideContent: View {
    @EnvironmentObject var app: AppViewModel
    @ObservedObject var tideManager: TideManager
    @State private var currentLocationName: String = "Waiting for GPS".localized
    @State private var showingHelp = false
    @State private var showingThresholdPopover = false
    @State private var showingStationMap = false
    
    @State private var dateList: [Date] = []
    
    private var appLocale: Locale {
        Locale(identifier: LocalizationManager.shared.language.identifier)
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = appLocale
        f.setLocalizedDateFormatFromTemplate("Md")
        return f
    }
    
    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = appLocale
        f.setLocalizedDateFormatFromTemplate("E")
        return f
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    
                    if isLandscape {
                        landscapeLayout
                    } else {
                        portraitLayout
                    }
                }
                
                // 右上に地図ボタン・定規ボタン・ヘルプボタンを配置
                VStack {
                    HStack(spacing: 10) {
                        Spacer()

                        // 観測所地図選択ボタン
                        Button {
                            showingStationMap = true
                        } label: {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(tideManager.selectedStation != nil ? Theme.secondaryAccent : Theme.accent)
                                .frame(width: 36, height: 36)
                                .background(Theme.cardBackground.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }

                        // 基準水位設定ポップオーバーボタン
                        Button {
                            showingThresholdPopover = true
                        } label: {
                            Image(systemName: "ruler.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .frame(width: 36, height: 36)
                                .background(Theme.cardBackground.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .popover(isPresented: $showingThresholdPopover) {
                            ThresholdSettingsPopoverView()
                        }

                        if SettingsManager.shared.settings.showHelpButtons {
                            HelpCircleButton {
                                showingHelp = true
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingHelp) {
                TideHelpView()
            }
            .sheet(isPresented: $showingStationMap) {
                TideStationMapView(tideManager: tideManager)
            }
            .animation(.easeInOut, value: LocalizationManager.shared.language)
            .onAppear {
                startLocationTracking()
                if dateList.isEmpty {
                    generateDateList(around: Date())
                }
            }
            .onChange(of: tideManager.currentDate) { _, _ in
                if dateList.isEmpty || !dateList.contains(tideManager.currentDate) {
                    generateDateList(around: tideManager.currentDate)
                }
            }
            .onChange(of: app.locationManager.previousLocation) { _, newLocation in
                if let newLoc = newLocation {
                    updateLocationInfo(location: newLoc)
                }
            }
        }
    }
    
    // MARK: - Portrait Layout
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            // 1. Header (Location & Date)
            headerView
                .padding(.bottom, 8)
                .background(Theme.cardBackground)
                .shadow(radius: 5)
            
            // 2. Chart Area
            if tideManager.isLoading && tideManager.tideDataCache.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chartTabView(isLandscape: false)
            }
            
            // 3. Info Area
            ScrollView {
                if let tideData = tideManager.currentTideData {
                    HStack(alignment: .top, spacing: 16) {
                        tideInfoColumn(title: "High".localized, events: tideData.highTides, color: Theme.secondaryAccent)
                        tideInfoColumn(title: "Low".localized, events: tideData.lowTides, color: Theme.accent)
                    }
                    .padding()
                    .animation(.easeInOut, value: tideData.date)
                }
            }
        }
    }
    
    // MARK: - Landscape Layout
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left Column: Date, Location, Tide Type & High/Low Times
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(Theme.accent)
                                Text(currentLocationName)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textMain)
                                    .lineLimit(1)
                            }
                            
                            if let station = tideManager.nearestStation {
                                Text(station.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        if let data = tideManager.currentTideData {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(dateFormatter.string(from: data.date))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textMain)
                                        .contentTransition(.numericText())
                                    Text("(\(dayFormatter.string(from: data.date)))")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textSecondary)
                                        .contentTransition(.numericText())
                                }
                                
                                Text(data.tideType)
                                    .font(.headline)
                                    .foregroundColor(Theme.accent)
                            }
                            
                            // High/Low Times
                            VStack(spacing: 8) {
                                landscapeTideInfo(title: "High".localized, events: data.highTides, color: Theme.secondaryAccent)
                                landscapeTideInfo(title: "Low".localized, events: data.lowTides, color: Theme.accent)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(width: 210)
            .background(Theme.cardBackground.opacity(0.5))
            .animation(.easeInOut(duration: 0.3), value: tideManager.currentDate)
            
            // Right: Chart
            VStack {
                chartTabView(isLandscape: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 10)
            .padding(.trailing, 20)
        }
    }
    
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Location
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Theme.accent)
                Text(currentLocationName)
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)

                if let selected = tideManager.selectedStation {
                    // 手動選択中の観測所を表示 ＋ GPS最寄りに戻すボタン
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.secondaryAccent)
                        Text(selected.name)
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.secondaryAccent)

                        Button {
                            withAnimation {
                                tideManager.resetToNearestStation()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.secondaryAccent.opacity(0.15))
                    .clipShape(Capsule())
                } else if let station = tideManager.nearestStation {
                    Text("(\(station.name))")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            // Date
            if let data = tideManager.currentTideData {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(dateFormatter.string(from: data.date))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textMain)
                        .contentTransition(.numericText())
                    Text("(\(dayFormatter.string(from: data.date)))")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                        .contentTransition(.numericText())
                    
                    Text(data.tideType)
                        .font(.title3)
                        .foregroundColor(Theme.accent)
                        .padding(.leading, 8)
                        .transition(.opacity)
                    Spacer()
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(dateFormatter.string(from: tideManager.currentDate))
                        .font(.title)
                        .foregroundColor(Theme.textMain)
                        .contentTransition(.numericText())
                    Text("(\(dayFormatter.string(from: tideManager.currentDate)))")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                        .contentTransition(.numericText())
                    Spacer()
                }
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.3), value: tideManager.currentDate)
    }
    
    private func chartTabView(isLandscape: Bool) -> some View {
        let dateBinding = Binding<Date>(
            get: { tideManager.currentDate },
            set: { tideManager.currentDate = $0 }
        )

        return TabView(selection: dateBinding) {
            ForEach(dateList, id: \.self) { date in
                TideChart(date: date, tideManager: tideManager, isLandscape: isLandscape)
                    .tag(date)
                    .padding(.top, isLandscape ? 10 : 20)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: isLandscape ? nil : 320)
    }
    
    private func tideInfoColumn(title: String, events: [(time: String, level: Int)], color: Color) -> some View {
        let isHigh = title == "High".localized || title == "High"
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
            }
            
            if events.isEmpty {
                Text("--:--")
                    .foregroundColor(Theme.textMain)
            } else {
                ForEach(events.indices, id: \.self) { index in
                    let event = events[index]
                    HStack {
                        Text(event.time)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textMain)
                            .contentTransition(.numericText())
                        
                        Text("\(event.level)cm")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .contentTransition(.numericText())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: tideManager.currentDate)
    }
    
    private func landscapeTideInfo(title: String, events: [(time: String, level: Int)], color: Color) -> some View {
        let isHigh = title == "High".localized || title == "High"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
            }
            
            ForEach(events.indices, id: \.self) { index in
                let event = events[index]
                HStack {
                    Text(event.time)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundColor(Theme.textMain)
                        .contentTransition(.numericText())
                    Spacer()
                    Text("\(event.level)cm")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                        .contentTransition(.numericText())
                }
            }
            
            if events.isEmpty {
                Text("--:--").font(.caption).foregroundColor(Theme.textSecondary)
            }
        }
        .padding(10)
        .background(Theme.cardBackground.opacity(0.3))
        .cornerRadius(10)
    }
    
    // MARK: - Logic
    
    private func generateDateList(around baseDate: Date) {
        let calendar = Calendar.current
        var dates: [Date] = []
        let startOfBaseDate = calendar.startOfDay(for: baseDate)
        
        for i in -60...60 { // 前後2ヶ月
            if let d = calendar.date(byAdding: .day, value: i, to: startOfBaseDate) {
                dates.append(d)
            }
        }
        self.dateList = dates
        
        if !dates.contains(tideManager.currentDate) {
            self.dateList.append(tideManager.currentDate)
            self.dateList.sort()
        }
    }
    
    private func startLocationTracking() {
        // 現在地がすでにある場合
        if let location = app.locationManager.previousLocation {
            updateLocationInfo(location: location)
        }
        
        // 位置情報取得を開始（権限リクエストを含む）
        app.locationManager.startTracking()
    }
    
    private func updateLocationInfo(location: CLLocation) {
        lookUpCurrentLocation(location: location) { name in
            currentLocationName = name
        }
        tideManager.findNearestStation(location: location)
    }
    
    // .onChange を body に追加して位置情報更新に対応する
    // (body内の NavigationStack に .onChange を追加)
    private func lookUpCurrentLocation(location: CLLocation, completion: @escaping (String) -> Void) {
        if let request = MKReverseGeocodingRequest(location: location) {
            Task {
                do {
                    let mapItems = try await request.mapItems
                    if let firstItem = mapItems.first {
                        var name = ""
                        if let cityName = firstItem.addressRepresentations?.cityName, !cityName.isEmpty {
                            name = cityName
                        } else if let itemName = firstItem.name, !itemName.isEmpty {
                            name = itemName
                        } else if let shortAddress = firstItem.address?.shortAddress, !shortAddress.isEmpty {
                            name = shortAddress
                        } else {
                            name = "Current Location".localized
                        }
                        completion(name)
                    } else {
                        completion("Current Location".localized)
                    }
                } catch {
                    completion("Current Location".localized)
                }
            }
        } else {
            completion("Current Location".localized)
        }
    }
}

// Chart View
struct TideChart: View {
    let date: Date
    @ObservedObject var tideManager: TideManager
    let isLandscape: Bool
    
    @AppStorage("tideThresholdEnabled") private var thresholdEnabled: Bool = false
    @AppStorage("tideThresholdLevel") private var thresholdLevel: Int = 100
    
    @State private var selectedHour: Int? = nil
    
    private var isJA: Bool {
        LocalizationManager.shared.language == .japanese
    }
    
    private var keyFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    var body: some View {
        let station = tideManager.selectedStation ?? tideManager.nearestStation
        let dateKey = keyFormatter.string(from: date)
        let cacheKey = station != nil ? "\(station!.id)_\(dateKey)" : dateKey
        let tideData = tideManager.tideDataCache[cacheKey]

        return VStack(spacing: 0) {
            // インタラクティブ表示部（高さ固定でレイアウト崩れを防ぐ）
            ZStack {
                if let tideData = tideData, let selectedHour = selectedHour,
                   let matched = tideData.hourlyLevels.first(where: { $0.hour == selectedHour }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Theme.accent)
                            .font(.caption)
                        Text("\(selectedHour)\(isJA ? "時" : "h"):")
                            .font(.system(.footnote, design: .rounded))
                            .bold()
                            .foregroundColor(Theme.textSecondary)
                        Text("\(matched.level)cm")
                            .font(.system(.subheadline, design: .monospaced))
                            .bold()
                            .foregroundColor(Theme.accent)

                        if thresholdEnabled {
                            let diff = matched.level - thresholdLevel
                            let sign = diff >= 0 ? "+" : ""
                            Text("(\(sign)\(diff)cm)")
                                .font(.system(.caption, design: .monospaced))
                                .bold()
                                .foregroundColor(diff >= 0 ? Theme.secondaryAccent : .red)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Theme.cardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                } else {
                    Color.clear
                }
            }
            .frame(height: 36)  // 固定高さでグラフ引き伸ばしを防ぐ

            ZStack {
                if let tideData = tideData {
                    Chart {
                        ForEach(tideData.hourlyLevels) { item in
                            LineMark(
                                x: .value("Hour", item.hour),
                                y: .value("Level", item.level)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.primaryGradient)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Hour", item.hour),
                                y: .value("Level", item.level)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(
                                colors: [Theme.accent.opacity(0.4), Theme.accent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                        }
                        
                        // 現在時刻インジケータ (今日の場合)
                        if Calendar.current.isDate(Date(), inSameDayAs: tideData.date) {
                            let currentHour = Calendar.current.component(.hour, from: Date())
                            RuleMark(x: .value("Now", currentHour))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        // 基準の高さの水平線
                        if thresholdEnabled {
                            RuleMark(y: .value("Threshold", thresholdLevel))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .annotation(position: .trailing, alignment: .trailing) {
                                    Text("\(thresholdLevel)cm")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 3)
                                        .background(Theme.background.opacity(0.8))
                                        .cornerRadius(3)
                                        .offset(x: isLandscape ? 0 : -8)
                                }
                        }
                        
                        // 選択された時間の垂直線 & 点
                        if let selectedHour = selectedHour,
                           let matched = tideData.hourlyLevels.first(where: { $0.hour == selectedHour }) {
                            RuleMark(x: .value("SelectedHour", selectedHour))
                                .lineStyle(StrokeStyle(lineWidth: 1))
                                .foregroundStyle(Theme.accent.opacity(0.7))
                            
                            PointMark(
                                x: .value("SelectedHour", selectedHour),
                                y: .value("SelectedLevel", matched.level)
                            )
                            .foregroundStyle(Theme.accent)
                            .symbolSize(80)
                        }
                    }
                    .chartXScale(domain: 0...23) // X軸範囲を0-23に固定（基準線描写などでの自動拡張を防ぐ）
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                            AxisTick().foregroundStyle(Color.white.opacity(0.5))
                            AxisValueLabel() {
                                if let level = value.as(Int.self) {
                                    Text("\(level)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.7))
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 3)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                            AxisTick().foregroundStyle(Color.white.opacity(0.5))
                            AxisValueLabel() {
                                if let hour = value.as(Int.self) {
                                    Text("\(hour)h")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    .chartXSelection(value: $selectedHour)
                    .padding(.leading, isLandscape ? 40 : 10)
                    .padding(.trailing, isLandscape ? 5 : 10)  
                    .padding(.bottom, 15)
                    
                } else {
                    Text("Loading...")
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Tide Threshold Settings View
struct ThresholdSettingsPopoverView: View {
    @AppStorage("tideThresholdEnabled") private var thresholdEnabled: Bool = false
    @AppStorage("tideThresholdLevel") private var thresholdLevel: Int = 100
    
    private var isJA: Bool {
        LocalizationManager.shared.language == .japanese
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $thresholdEnabled) {
                Text(isJA ? "基準水位を表示" : "Show Threshold")
                    .font(.footnote)
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            .tint(Theme.accent)
            
            if thresholdEnabled {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack(spacing: 8) {
                    Text(isJA ? "高さ:" : "Level:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    TextField("0", value: $thresholdLevel, format: .number)
                        .textFieldStyle(.plain)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .frame(width: 50)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(Theme.textMain)
                        .font(.system(.footnote, design: .monospaced))
                    
                    Text("cm")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Stepper("", value: $thresholdLevel, in: -500...500, step: 5)
                        .labelsHidden()
                }
            }
        }
        .padding(14)
        .frame(width: 220)
        .background(Theme.cardBackground)
        .presentationCompactAdaptation(.popover) // iPhoneでもpopover表示
    }
}

#Preview {
    TideView()
}

