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
    @State private var selectedDay: Date? = nil
    @State private var showCalendarSheet = false
    
    // 削除管理
    @State private var showingDeleteConfirm = false
    @State private var itemToDelete: RecordListItem? = nil
    @State private var itemIDBeingAnimated: String? = nil
    
    // 遷移管理
    @State private var selectedRecord: RowingRecord? = nil
    @State private var selectedManagerSession: ManagerSessionItem? = nil
    
    var body: some View {
        // 依存関係を明示することで、レコードの追加・削除（インポート含む）時に確実にUIを再描画する
        let _ = recordManager.records
        
        NavigationStack {
            ZStack {
                // 背景
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header / Status Card
                        statusCard
                        
                        // MARK: - Filters
                        filterControls
                        
                        // MARK: - Active Filter Chips
                        activeFilterChips
                        
                        // MARK: - History
                        historySection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCalendarSheet = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCalendarSheet) {
                NavigationStack {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        
                        ScrollView {
                            VStack(spacing: 24) {
                                // MARK: - Stats
                                statsDashboard
                                    .padding(.top)
                                
                                // MARK: - Calendar Card
                                calendarCard
                                
                                // MARK: - Sheet History
                                sheetHistorySection
                            }
                            .padding(.vertical)
                        }
                    }
                    .navigationTitle(LocalizationManager.shared.language == .japanese ? "カレンダー・サマリー" : "Calendar & Stats")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close".localized) {
                                showCalendarSheet = false
                            }
                            .foregroundColor(Theme.accent)
                        }
                    }
                    .alert("Delete Record".localized, isPresented: $showingDeleteConfirm) {
                        Button("Delete".localized, role: .destructive) {
                            if let item = itemToDelete {
                                confirmDelete(item)
                            }
                        }
                        Button("Cancel".localized, role: .cancel) {
                            itemToDelete = nil
                        }
                    } message: {
                        if let item = itemToDelete {
                            switch item {
                            case .single(_):
                                Text("Delete Record Message".localized)
                            case .managerSession(_, let records):
                                Text(String(format: "Delete Session Message".localized, records.count))
                            }
                        }
                    }
                    .navigationDestination(item: $selectedRecord) { record in
                        RecordDetailView(record: record)
                    }
                    .navigationDestination(item: $selectedManagerSession) { session in
                        ManagerSessionDetailView(records: session.records)
                    }
                }
                .presentationDetents([.large])
                .id(themeManager.currentPreset)
            }
            .onAppear {
                 if let location = app.locationManager.previousLocation {
                     tideManager.findNearestStation(location: location)
                     if let station = tideManager.nearestStation {
                         tideManager.fetchTideData(for: station, date: Date())
                     }
                     weatherManager.fetchWeather(for: location)
                 }
            }
            .navigationDestination(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
            .navigationDestination(item: $selectedManagerSession) { session in
                ManagerSessionDetailView(records: session.records)
            }
        }
        .id(themeManager.currentPreset)
        .alert("Delete Record".localized, isPresented: $showingDeleteConfirm) {
            Button("Delete".localized, role: .destructive) {
                if let item = itemToDelete {
                    confirmDelete(item)
                }
            }
            Button("Cancel".localized, role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                switch item {
                case .single(_):
                    Text("Delete Record Message".localized)
                case .managerSession(_, let records):
                    Text(String(format: "Delete Session Message".localized, records.count))
                }
            }
        }
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
    
    private var statsDashboard: some View {
        let monthRecords = recordManager.records(for: selectedMonth, filter: selectedFilter)
        let monthStats = recordManager.stats(for: monthRecords)
        let allFiltered = recordManager.allRecords(filter: selectedFilter)
        let cumulativeStats = recordManager.stats(for: allFiltered)
        
        return HStack(spacing: 12) {
            // This Month Card
            VStack(alignment: .leading, spacing: 8) {
                Text("\(shortMonthFormatter.string(from: selectedMonth))のサマリー")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    compactStat(icon: "ruler", value: formatDistanceKm(monthStats.distance), color: Theme.accent)
                    compactStat(icon: "clock", value: formatDuration(monthStats.duration), color: Theme.secondaryAccent)
                    compactStat(icon: "number", value: "\(monthStats.count)件", color: .orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            
            // Cumulative Card
            VStack(alignment: .leading, spacing: 8) {
                Text("累積のサマリー")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    compactStat(icon: "ruler", value: formatDistanceKm(cumulativeStats.distance), color: Theme.accent)
                    compactStat(icon: "clock", value: formatDuration(cumulativeStats.duration), color: Theme.secondaryAccent)
                    compactStat(icon: "number", value: "\(cumulativeStats.count)件", color: .orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    private var calendarCard: some View {
        VStack(spacing: 12) {
            // Month navigation inside the calendar
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.accent)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
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
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(isCurrentMonth)
            }
            .padding(.horizontal, 8)
            
            // Weekdays
            let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<calendarDays.count, id: \.self) { index in
                    if let day = calendarDays[index] {
                        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
                        let recordsCount = records(on: day).count
                        let hasRecords = recordsCount > 0
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isSelected {
                                    selectedDay = nil
                                } else {
                                    selectedDay = day
                                }
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: day))")
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .bold : (hasRecords ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .black : (hasRecords ? Theme.textMain : Theme.textSecondary.opacity(0.6)))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                Circle()
                                                    .fill(Theme.accent)
                                            } else if Calendar.current.isDateInToday(day) {
                                                Circle()
                                                    .stroke(Theme.accent.opacity(0.8), lineWidth: 1.5)
                                            }
                                        }
                                    )
                                
                                // Workout Dots
                                HStack(spacing: 3) {
                                    if hasOutdoorRecord(on: day) {
                                        Circle()
                                            .fill(Theme.accent)
                                            .frame(width: 4, height: 4)
                                    }
                                    if hasIndoorRecord(on: day) {
                                        Circle()
                                            .fill(Theme.secondaryAccent)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    } else {
                        // Empty cell for calendar offset
                        Spacer()
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(historyHeaderTitle)
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
    
    private var historyHeaderTitle: String {
        if let day = selectedDay {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return LocalizationManager.shared.language == .japanese ? "\(f.string(from: day))の履歴" : "History for \(f.string(from: day))"
        } else {
            return "History".localized
        }
    }
    
    private var activeFilterChips: some View {
        Group {
            if let day = selectedDay {
                HStack(spacing: 8) {
                    // Day Filter Chip
                    filterChip(
                        text: formatDateYMD(day),
                        icon: "calendar"
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDay = nil
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func filterChip(text: String, icon: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(Theme.accent)
        .background(Theme.accent.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func formatDateYMD(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            withAnimation {
                selectedMonth = newDate
                selectedDay = nil
            }
        }
    }
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    private var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M"
        return f
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
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = selectedMonth.startOfMonth(using: calendar)
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        
        // Sunday is 1. If weekdayOfFirst is 1 (Sunday), offset is 0.
        // If weekdayOfFirst is 2 (Monday), offset is 1.
        let offset = weekdayOfFirst - 1
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        if let range = calendar.range(of: .day, in: .month, for: selectedMonth) {
            let numDays = range.count
            for day in 1...numDays {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    private var filteredRecordsForMonth: [RowingRecord] {
        recordManager.records(for: selectedMonth, filter: selectedFilter)
    }
    
    private func records(on day: Date) -> [RowingRecord] {
        filteredRecordsForMonth.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }
    
    private func hasOutdoorRecord(on day: Date) -> Bool {
        records(on: day).contains { recordManager.isOutdoor($0) }
    }
    
    private func hasIndoorRecord(on day: Date) -> Bool {
        records(on: day).contains { !recordManager.isOutdoor($0) }
    }
    
    private func formatDistanceKm(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
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
        
        let filteredRecords: [RowingRecord]
        if let day = selectedDay {
            filteredRecords = recordManager.records(for: selectedMonth, filter: selectedFilter).filter {
                Calendar.current.isDate($0.date, inSameDayAs: day)
            }
        } else {
            filteredRecords = recordManager.allRecords(filter: selectedFilter)
        }
        
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
                SwipeToDelete(id: item.id, isAnimatingOut: itemIDBeingAnimated == item.id) {
                    prepareDelete(item)
                } onTap: {
                    switch item {
                    case .single(let record):
                        selectedRecord = record
                    case .managerSession(let sessionId, let records):
                        selectedManagerSession = ManagerSessionItem(id: sessionId, records: records)
                    }
                } content: {
                    Group {
                        switch item {
                        case .single(let record):
                            RecordRowCard(record: record)
                        case .managerSession(_, let records):
                            ManagerSessionRowCard(records: records)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var sheetGroupedRecords: [RecordListItem] {
        var items: [RecordListItem] = []
        var managerGroups: [UUID: [RowingRecord]] = [:]
        
        let filteredRecords: [RowingRecord]
        if let day = selectedDay {
            filteredRecords = recordManager.records(for: selectedMonth, filter: selectedFilter).filter {
                Calendar.current.isDate($0.date, inSameDayAs: day)
            }
        } else {
            filteredRecords = recordManager.records(for: selectedMonth, filter: selectedFilter)
        }
        
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
    
    private var sheetHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sheetHistoryHeaderTitle)
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
                .padding(.horizontal)
            
            let currentItems = sheetGroupedRecords
            if currentItems.isEmpty {
                Text("No Records".localized)
                    .foregroundColor(Theme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                sheetHistoryList
            }
        }
    }
    
    private var sheetHistoryHeaderTitle: String {
        if let day = selectedDay {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return LocalizationManager.shared.language == .japanese ? "\(f.string(from: day))の履歴" : "History for \(f.string(from: day))"
        } else {
            let f = DateFormatter()
            f.dateFormat = "MMMM"
            let monthName = f.string(from: selectedMonth)
            return LocalizationManager.shared.language == .japanese ? "\(shortMonthFormatter.string(from: selectedMonth))の履歴" : "\(monthName) History"
        }
    }
    
    private var sheetHistoryList: some View {
        LazyVStack(spacing: 12) {
            ForEach(sheetGroupedRecords) { item in
                SwipeToDelete(id: item.id, isAnimatingOut: itemIDBeingAnimated == item.id) {
                    prepareDelete(item)
                } onTap: {
                    switch item {
                    case .single(let record):
                        selectedRecord = record
                    case .managerSession(let sessionId, let records):
                        selectedManagerSession = ManagerSessionItem(id: sessionId, records: records)
                    }
                } content: {
                    Group {
                        switch item {
                        case .single(let record):
                            RecordRowCard(record: record)
                        case .managerSession(_, let records):
                            ManagerSessionRowCard(records: records)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Deletion Helpers
    
    private func prepareDelete(_ item: RecordListItem) {
        itemToDelete = item
        showingDeleteConfirm = true
    }
    
    private func confirmDelete(_ item: RecordListItem) {
        withAnimation {
            itemIDBeingAnimated = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            performDelete(item)
            itemIDBeingAnimated = nil
        }
    }
    
    private func performDelete(_ item: RecordListItem) {
        switch item {
        case .single(let record):
            recordManager.deleteRecord(record)
        case .managerSession(_, let records):
            for record in records {
                recordManager.deleteRecord(record)
            }
        }
        itemToDelete = nil
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

// MARK: - Date Extensions
extension Date {
    fileprivate func startOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: self)))!
    }
}

// MARK: - ManagerSessionItem
struct ManagerSessionItem: Identifiable, Hashable {
    let id: UUID
    let records: [RowingRecord]
}

// MARK: - Swipe to Delete Container View

struct SwipeToDelete<Content: View>: View {
    let id: String
    let isAnimatingOut: Bool
    let onDelete: () -> Void
    let onTap: () -> Void
    let content: () -> Content
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Content
            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSwiped {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                            isSwiped = false
                        }
                    } else {
                        onTap()
                    }
                }
                .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        let xTrans = value.translation.width
                        let yTrans = value.translation.height
                        
                        // Prevent horizontal swipe gesture from triggering during vertical scroll
                        guard abs(xTrans) > abs(yTrans) else { return }
                        
                        // Only allow swipe to left
                        withAnimation(.interactiveSpring()) {
                            if xTrans < 0 {
                                offset = isSwiped ? xTrans - 70 : xTrans
                            } else if xTrans > 0 && isSwiped {
                                offset = xTrans - 70
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if value.translation.width < -40 {
                                offset = -70
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            
            // Background Delete Button
            if offset < 0 {
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.trailing, 2)
                .transition(.opacity) // Smooth transition when showing up
            }
        }
        .onChange(of: isAnimatingOut) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset = -1000
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0
                    isSwiped = false
                }
            }
        }
    }
}
