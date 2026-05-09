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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if SettingsManager.shared.settings.showHelpButtons {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HelpCircleButton {
                            showingHelp = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpView(
                    title: "Tide Help".localized,
                    content: """
    気象庁が提供する全国239地点の潮汐データを取得・表示することができます。
    GPSを用いて使用者の位置に最も近い場所の潮汐データを表示します。
    この際のGPS情報はアプリ内部で処理されるので位置情報の漏洩等の心配はありません。

    ⚠︎気象庁が予測している潮汐データに過ぎません。
    洪水時や観測点のずれなどにより表示される潮汐データと実際の潮位は異なる可能性がありますので必ず現地の状況に応じて練習の有無等を判断してください。

    ※当機能は日本国内でのみ利用可能です。
    """
                )
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
            VStack(alignment: .leading, spacing: 16) {
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
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textMain)
                                .contentTransition(.numericText())
                            Text("(\(dayFormatter.string(from: data.date)))")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
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
                
                Spacer()
            }
            .padding()
            .frame(width: 200)
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
                
                if let station = tideManager.nearestStation {
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
                    Spacer()
                }
            }
        }
        .padding()
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
        Task {
            let request = MKReverseGeocodingRequest(location: location)
            do {
                let mapItems = try await request?.mapItems
                if let first = mapItems?.first {
                    // プライバシー保護のため、詳細な住所（first.name）ではなく
                    // 県名や広域エリア名（administrativeArea）を優先して表示
                    let placemark = first.placemark
                    let name = placemark.administrativeArea ?? placemark.locality ?? first.name
                    await MainActor.run { completion(name ?? "Current Location".localized) }
                } else {
                    await MainActor.run { completion("Current Location".localized) }
                }
            } catch {
                await MainActor.run { completion("Current Location".localized) }
            }
        }
    }
}

// Chart View
struct TideChart: View {
    let date: Date
    @ObservedObject var tideManager: TideManager
    let isLandscape: Bool
    
    private var keyFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    var body: some View {
        let key = keyFormatter.string(from: date)
        let tideData = tideManager.tideDataCache[key]
        
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
                    
                    if Calendar.current.isDate(Date(), inSameDayAs: tideData.date) {
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        RuleMark(x: .value("Now", currentHour))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisTick().foregroundStyle(Color.white.opacity(0.5))
                        AxisValueLabel() {
                            if let level = value.as(Int.self) {
                                Text("\(level)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.7))
                                    .frame(width: 40, alignment: .trailing) // Even more secure width
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
                .padding(.leading, isLandscape ? 40 : 10) // Only heavy padding in landscape
                .padding(.trailing, isLandscape ? 5 : 10)  
                .padding(.bottom, 15)
                
            } else {
                Text("Loading...")
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
#Preview {
    TideView()
}

