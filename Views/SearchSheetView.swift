import SwiftUI

struct SearchSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var app: AppViewModel
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private var isJA: Bool {
        LocalizationManager.shared.language == .japanese
    }
    
    // 練習記録の項目モデル
    enum SearchRecordItem: Identifiable, Hashable {
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
    
    // 検索チップ用の推奨タグ
    private var availableTags: [String] {
        var allTags = Set<String>()
        // プリセットタグ
        allTags.insert(isJA ? "屋内" : "Indoor")
        allTags.insert(isJA ? "屋外" : "Outdoor")
        allTags.insert("1000m")
        allTags.insert("2000m")
        allTags.insert(isJA ? "利用規約" : "Terms")
        allTags.insert(isJA ? "計測" : "Tracking")
        allTags.insert(isJA ? "クレジット" : "Credits")
        
        // レコードからタグを収集
        for record in app.recordManager.records {
            if let tags = record.tags {
                for tag in tags {
                    allTags.insert(tag)
                }
            }
        }
        
        let presets = [
            isJA ? "屋内" : "Indoor",
            isJA ? "屋外" : "Outdoor",
            "1000m",
            "2000m",
            isJA ? "利用規約" : "Terms",
            isJA ? "計測" : "Tracking",
            isJA ? "クレジット" : "Credits"
        ]
        
        let customTags = allTags.subtracting(presets).sorted()
        return presets + customTags
    }
    
    // アプリ機能の検索結果
    private var filteredFunctions: [AppFunctionItem] {
        let items = SearchHelper.shared.getFunctionItems(isJA: isJA)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        
        return items.filter { item in
            item.title.lowercased().contains(q) ||
            item.description.lowercased().contains(q) ||
            item.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }
    
    // 練習セッションの全記録
    private var groupedRecords: [SearchRecordItem] {
        var items: [SearchRecordItem] = []
        var managerGroups: [UUID: [RowingRecord]] = [:]
        
        for record in app.recordManager.records {
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
    
    // 練習セッションの検索結果
    private var filteredGroupedRecords: [SearchRecordItem] {
        let allItems = groupedRecords
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allItems }
        
        return allItems.filter { item in
            switch item {
            case .single(let record):
                return matchesQuery(record: record, query: q)
            case .managerSession(_, let records):
                return records.contains { matchesQuery(record: $0, query: q) }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 検索バー
                    searchBarSection
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // タグチップ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                let isSelected = searchText.lowercased() == tag.lowercased()
                                Button(action: {
                                    withAnimation {
                                        if isSelected {
                                            searchText = ""
                                        } else {
                                            searchText = tag
                                        }
                                    }
                                }) {
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Theme.accent : Color.white.opacity(0.08))
                                        .foregroundColor(isSelected ? .black : Theme.textMain)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(isSelected ? Theme.accent : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // 検索結果
                    ScrollView {
                        VStack(spacing: 24) {
                            // 検索結果がない場合
                            if searchText.isEmpty {
                                initialContentView
                            } else if filteredFunctions.isEmpty && filteredGroupedRecords.isEmpty {
                                emptyStateView
                            } else {
                                searchResultsView
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(isJA ? "総合検索" : "Global Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isJA ? "キャンセル" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            // 遷移先の定義
            .navigationDestination(for: AppDestination.self) { dest in
                destinationView(for: dest)
            }
            .navigationDestination(for: RowingRecord.self) { record in
                RecordDetailView(record: record)
            }
            .navigationDestination(for: ManagerSessionItem.self) { session in
                ManagerSessionDetailView(records: session.records)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
            
            TextField(isJA ? "セッションや機能を検索..." : "Search sessions, terms, etc...", text: $searchText)
                .foregroundColor(Theme.textMain)
                .tint(Theme.accent)
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onAppear {
                    // 自動でキーボードを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isSearchFocused = true
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var initialContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // クイックアクセス機能
            VStack(alignment: .leading, spacing: 10) {
                Text(isJA ? "クイックアクセス" : "Quick Access")
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)
                    .padding(.horizontal)
                
                let functions = Array(filteredFunctions.prefix(4))
                LazyVStack(spacing: 8) {
                    ForEach(functions) { item in
                        functionRow(item)
                    }
                }
                .padding(.horizontal)
            }
            
            // 最近の記録
            VStack(alignment: .leading, spacing: 10) {
                Text(isJA ? "最近のセッション" : "Recent Sessions")
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)
                    .padding(.horizontal)
                
                let records = Array(groupedRecords.prefix(5))
                if records.isEmpty {
                    Text(isJA ? "履歴がありません" : "No recent activity")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { item in
                            recordRow(item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // アプリ機能セクション
            if !filteredFunctions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isJA ? "アプリ機能 (\(filteredFunctions.count))" : "App Features (\(filteredFunctions.count))")
                        .font(Theme.subHeaderFont())
                        .foregroundColor(Theme.textMain)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(filteredFunctions) { item in
                            functionRow(item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 練習セッションセクション
            if !filteredGroupedRecords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isJA ? "練習セッション (\(filteredGroupedRecords.count))" : "Rowing Sessions (\(filteredGroupedRecords.count))")
                        .font(Theme.subHeaderFont())
                        .foregroundColor(Theme.textMain)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(filteredGroupedRecords) { item in
                            recordRow(item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            
            Text(isJA ? "該当する結果が見つかりません" : "No results found")
                .font(.headline)
                .foregroundColor(Theme.textMain)
            
            Text(isJA ? "他のキーワードやタグで検索してください。" : "Try searching with other tags or keywords.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Row Builders
    
    private func functionRow(_ item: AppFunctionItem) -> some View {
        Group {
            switch item.action {
            case .changeTab(let tabIndex):
                Button(action: {
                    app.activeTab = tabIndex
                    dismiss()
                }) {
                    functionRowContent(item)
                }
                .buttonStyle(PlainButtonStyle())
            case .navigateToView(let dest):
                NavigationLink(value: dest) {
                    functionRowContent(item)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func functionRowContent(_ item: AppFunctionItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.iconName)
                .font(.title3)
                .foregroundColor(Theme.accent)
                .padding(10)
                .background(Theme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMain)
                
                Text(item.description)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06, cornerRadius: 12)
    }
    
    private func recordRow(_ item: SearchRecordItem) -> some View {
        Group {
            switch item {
            case .single(let record):
                NavigationLink(value: record) {
                    SearchRecordRowCard(record: record)
                }
                .buttonStyle(PlainButtonStyle())
            case .managerSession(let sessionId, let records):
                NavigationLink(value: ManagerSessionItem(id: sessionId, records: records)) {
                    SearchManagerSessionRowCard(records: records)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Destination Helper
    
    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .riggingManager:
            RiggingManagerView()
        case .subscription:
            SubscriptionView()
        case .terms:
            TermsView()
        case .about:
            AboutRowPilotView()
        case .credits:
            CreditsView()
        case .sosSettings:
            SOSSettingsView()
        case .teamMaxManager:
            TeamMaxManagerView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func matchesQuery(record: RowingRecord, query: String) -> Bool {
        if let tags = record.tags, tags.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }
        if let notes = record.notes, notes.lowercased().contains(query) {
            return true
        }
        let isOutdoor = app.recordManager.isOutdoor(record)
        if query == "屋内" || query == "屋内ワークアウト" || query == "indoor" {
            return !isOutdoor
        }
        if query == "屋外" || query == "屋外ワークアウト" || query == "outdoor" {
            return isOutdoor
        }
        if let distanceValue = extractDistance(from: query) {
            let diff = abs(record.distance - distanceValue)
            if diff < 100 {
                return true
            }
        }
        if let customName = record.pm5CustomName, customName.lowercased().contains(query) {
            return true
        }
        return false
    }
    
    private func extractDistance(from text: String) -> Double? {
        let cleaned = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasSuffix("km") {
            let numStr = cleaned.dropLast(2).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) {
                return val * 1000
            }
        }
        if cleaned.hasSuffix("m") {
            let numStr = cleaned.dropLast(1).trimmingCharacters(in: .whitespaces)
            if let val = Double(numStr) {
                return val
            }
        }
        if let val = Double(cleaned) {
            return val
        }
        return nil
    }
}

// MARK: - Record Row Cards for Search

struct SearchRecordRowCard: View {
    let record: RowingRecord
    
    var body: some View {
        HStack {
            VStack(spacing: 2) {
                Text(dayStr(record.date))
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(Theme.textMain)
                Text(monthStr(record.date))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    Label(record.formattedDistance, systemImage: "ruler")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                    Label(record.formattedDuration, systemImage: "clock")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                }
                .foregroundColor(Theme.accent)
                
                HStack(spacing: 12) {
                    Text("\(record.averageSPM) SPM")
                    Text(record.formattedPace)
                }
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.05, cornerRadius: 12)
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

struct SearchManagerSessionRowCard: View {
    let records: [RowingRecord]
    
    var body: some View {
        HStack {
            VStack(spacing: 2) {
                Text(dayStr(records.first?.date ?? Date()))
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundColor(Theme.textMain)
                Text(monthStr(records.first?.date ?? Date()))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Manager Session".localized)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMain)
                
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                    Text("\(records.count) Devices".localized)
                }
                .font(.caption)
                .foregroundColor(Theme.accent)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .glassCardStyle(glowColor: .indigo, opacity: 0.08, cornerRadius: 12)
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
