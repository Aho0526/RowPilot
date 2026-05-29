import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
    private var recordManager: RecordManager { app.recordManager }
    private var tideManager: TideManager { app.tideManager }
    private var weatherManager: WeatherManager { app.weatherManager }
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var selectedFilter: RecordFilter = .both
    @State private var selectedMonth: Date = Date()
    @State private var showMonthlySummary: Bool = false
    @State private var showCumulativeSummary: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header / Status Card
                        statusCard
                        
                        // MARK: - Filters & Month Selector
                        filterControls
                        monthSelector
                            .padding(.top, 8)
                        
                        // MARK: - Stats (Compact Summary Badges)
                        summaryBadges
                        
                        // MARK: - History
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                                .padding(.horizontal)
                            
                            
                            let currentItems = groupedRecords
                            if currentItems.isEmpty {
                                emptyHistoryView
                            } else {
                                historyList
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                 if let location = app.locationManager.previousLocation {
                     tideManager.findNearestStation(location: location)
                     if let station = tideManager.nearestStation {
                         tideManager.fetchTideData(for: station, date: Date())
                     }
                     weatherManager.fetchWeather(for: location)
                 }
            }
        }
        .id(themeManager.currentPreset)
    }
    
    // MARK: - Components
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date & Location Placeholder
            HStack {
                VStack(alignment: .leading) {
                    Text(dateFormatter.string(from: Date()))
                        .font(Theme.headerFont())
                        .foregroundColor(.white)
                    
                    if let tideData = tideManager.currentTideData {
                        Text(tideData.tideType)
                            .font(.headline)
                            .foregroundColor(Theme.accent)
                    } else if tideManager.isLoading {
                        Text("Fetching information...".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        // Not loading and no data? Try fetching
                        Text("--:--")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                // 天気ウィジェット（設定に応じて表示内容を切り替え）
                let mode = settingsManager.settings.weatherDisplayMode
                if mode != .hidden {
                    VStack(spacing: 3) {
                        if weatherManager.isLoading {
                            ProgressView().tint(.white).scaleEffect(1.1)
                        } else {
                            if mode.showIcon {
                                Image(systemName: weatherManager.currentSymbol)
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.primaryGradient)
                            }
                            if mode.showTemp, let temp = weatherManager.temperature {
                                Text(String(format: "%.0f°C", temp))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            if mode.showRain, let rain = weatherManager.precipitationProbability {
                                HStack(spacing: 2) {
                                    Image(systemName: "umbrella.fill")
                                        .font(.system(size: 9))
                                    Text("\(rain)%")
                                        .font(.caption2)
                                }
                                .foregroundColor(.cyan.opacity(0.9))
                            }
                            if mode.showLabel {
                                Text(weatherManager.currentLabel)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            
            // Tide Summary
            if let tideData = tideManager.currentTideData {
                HStack(spacing: 20) {
                    tideMiniInfo(title: "High".localized, time: tideData.highTides.first?.time ?? "--:--", icon: "arrow.up.circle.fill", color: .red)
                    tideMiniInfo(title: "Low".localized, time: tideData.lowTides.first?.time ?? "--:--", icon: "arrow.down.circle.fill", color: Theme.accent)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func tideMiniInfo(title: String, time: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(time)
                    .font(.headline)
                    .foregroundColor(Theme.textMain)
            }
        }
    }
    
    private var filterControls: some View {
        HStack(spacing: 0) {
            ForEach(RecordFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(filter.localized)
                        .font(.subheadline)
                        .fontWeight(selectedFilter == filter ? .bold : .medium)
                        .foregroundColor(selectedFilter == filter ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selectedFilter == filter {
                                    Theme.accent
                                        .cornerRadius(8)
                                        .shadow(color: Theme.accent.opacity(0.4), radius: 4, x: 0, y: 2)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var monthSelector: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.accent)
                    .padding(10)
                    .background(Theme.cardBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(monthYearFormatter.string(from: selectedMonth))
                .font(.headline)
                .foregroundColor(Theme.textMain)
                .contentTransition(.numericText())
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(isCurrentMonth ? Theme.textSecondary.opacity(0.3) : Theme.accent)
                    .padding(10)
                    .background(Theme.cardBackground)
                    .clipShape(Circle())
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 24)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            withAnimation {
                selectedMonth = newDate
            }
        }
    }
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    private var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年 M月"
        return f
    }
    
    private var summaryBadges: some View {
        let monthRecords = recordManager.records(for: selectedMonth, filter: selectedFilter)
        let monthStats = recordManager.stats(for: monthRecords)
        let allFiltered = recordManager.allRecords(filter: selectedFilter)
        let cumulativeStats = recordManager.stats(for: allFiltered)
        
        return VStack(spacing: 12) {
            // Compact badge row
            HStack(spacing: 12) {
                // Monthly Summary Badge
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showMonthlySummary.toggle()
                        if showMonthlySummary { showCumulativeSummary = false }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showMonthlySummary ? .white : Theme.accent)
                        Text("\(shortMonthFormatter.string(from: selectedMonth))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(showMonthlySummary ? .white : Theme.textMain)
                        Text("\(monthStats.count)件")
                            .font(.caption)
                            .foregroundColor(showMonthlySummary ? .white.opacity(0.8) : Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showMonthlySummary ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.cardBackground))
                    )
                    .shadow(color: showMonthlySummary ? Theme.accent.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
                }
                
                // Cumulative Summary Badge
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showCumulativeSummary.toggle()
                        if showCumulativeSummary { showMonthlySummary = false }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showCumulativeSummary ? .white : Theme.secondaryAccent)
                        Text("累積")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(showCumulativeSummary ? .white : Theme.textMain)
                        Text("\(cumulativeStats.count)件")
                            .font(.caption)
                            .foregroundColor(showCumulativeSummary ? .white.opacity(0.8) : Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showCumulativeSummary ? AnyShapeStyle(Theme.secondaryAccent) : AnyShapeStyle(Theme.cardBackground))
                    )
                    .shadow(color: showCumulativeSummary ? Theme.secondaryAccent.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Expandable Monthly Summary
            if showMonthlySummary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(monthYearFormatter.string(from: selectedMonth))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)
                    
                    HStack(spacing: 16) {
                        compactStat(icon: "ruler", value: formatDistance(monthStats.distance), color: Theme.accent)
                        compactStat(icon: "clock", value: formatDuration(monthStats.duration), color: Theme.secondaryAccent)
                        compactStat(icon: "number", value: "\(monthStats.count)", color: .orange)
                    }
                }
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(14)
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            // Expandable Cumulative Summary
            if showCumulativeSummary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("累積のサマリー")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)
                    
                    HStack(spacing: 16) {
                        compactStat(icon: "ruler", value: formatDistance(cumulativeStats.distance), color: Theme.accent)
                        compactStat(icon: "clock", value: formatDuration(cumulativeStats.duration), color: Theme.secondaryAccent)
                        compactStat(icon: "number", value: "\(cumulativeStats.count)", color: .orange)
                    }
                }
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(14)
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    private func compactStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .padding(5)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textMain)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var shortMonthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f
    }
    
    private var emptyHistoryView: some View {
        Text("No Records".localized)
            .foregroundColor(Theme.textSecondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    enum RecordListItem: Identifiable {
        case single(RowingRecord)
        case managerSession(UUID, [RowingRecord])
        
        var id: String {
            switch self {
            case .single(let r): return r.id.uuidString
            case .managerSession(let u, _): return u.uuidString
            }
        }
        
        var date: Date {
            switch self {
            case .single(let r): return r.date
            case .managerSession(_, let records): return records.first?.date ?? Date()
            }
        }
    }
    
    private var groupedRecords: [RecordListItem] {
        var items: [RecordListItem] = []
        var managerGroups: [UUID: [RowingRecord]] = [:]
        
        let filteredRecords = recordManager.records(for: selectedMonth, filter: selectedFilter)
        
        for record in filteredRecords {
            if record.isManagerMode, let sessionId = record.managerSessionId {
                managerGroups[sessionId, default: []].append(record)
            } else {
                items.append(.single(record))
            }
        }
        
        for (sessionId, records) in managerGroups {
            items.append(.managerSession(sessionId, records))
        }
        
        return items.sorted { $0.date > $1.date }
    }

    private var historyList: some View {
        LazyVStack(spacing: 12) {
            ForEach(groupedRecords) { item in
                switch item {
                case .single(let record):
                    NavigationLink(destination: RecordDetailView(record: record)) {
                        RecordRowCard(record: record)
                    }
                case .managerSession(_, let records):
                    // Manager Session group with navigation to detail view
                    NavigationLink(destination: ManagerSessionDetailView(records: records)) {
                        ManagerSessionRowCard(records: records)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        return String(format: "%.0f m", meters)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return String(format: "%d時間%d分", hours, minutes)
        } else {
            return String(format: "%d分", minutes)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }
}

// MARK: - Subviews

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMain)
                    .minimumScaleFactor(0.8)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
}

struct RecordRowCard: View {
    let record: RowingRecord
    
    var body: some View {
        HStack {
            // Date Box
            VStack {
                Text(dayStr(record.date))
                    .font(.title3)
                    .bold()
                    .foregroundColor(Theme.textMain)
                Text(monthStr(record.date))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            .padding(.trailing, 8)
            
            // Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Label(record.formattedDistance, systemImage: "ruler")
                        .font(.system(.body, design: .monospaced))
                    Label(record.formattedDuration, systemImage: "clock")
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(Theme.accent)
                
                HStack(spacing: 16) {
                    Text("\(record.averageSPM) SPM")
                    Text(record.formattedPace)
                }
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private func dayStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
    
    private func monthStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

struct ManagerSessionRowCard: View {
    let records: [RowingRecord]
    
    var body: some View {
        HStack {
            // Date Box
            VStack {
                Text(dayStr(records.first?.date ?? Date()))
                    .font(.title3)
                    .bold()
                    .foregroundColor(Theme.textMain)
                Text(monthStr(records.first?.date ?? Date()))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            .padding(.trailing, 8)
            
            // Stats
            VStack(alignment: .leading, spacing: 6) {
                Text("Manager Session".localized)
                    .font(.headline)
                    .foregroundColor(Theme.textMain)
                
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                    Text("\(records.count) Devices".localized)
                }
                .font(.subheadline)
                .foregroundColor(Theme.accent) // Visually distinct accent
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
    }
    
    private func dayStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
    
    private func monthStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}
