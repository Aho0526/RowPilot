import SwiftUI
import MapKit

struct RecordListView: View {
    @EnvironmentObject var app: AppViewModel
    private var recordManager: RecordManager { app.recordManager }
    
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var selectedRecord: RowingRecord?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            Group {
                if recordManager.records.isEmpty {
                    emptyView
                } else {
                    recordsList
                }
            }
            .navigationTitle("Records".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By".localized, selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.localized).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                NavigationStack {
                    RecordDetailView(record: record)
                }
            }
        }
    }
    
    // MARK: - Empty 
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Records".localized)
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Try recording a session".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Records List
    private var recordsList: some View {
        List {
            ForEach(sortedRecords) { record in
                RecordRow(record: record)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecord = record
                        showingDetail = true
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Computed Properties
    private var sortedRecords: [RowingRecord] {
        switch sortOrder {
        case .dateDescending:
            return recordManager.records.sorted { $0.date > $1.date }
        case .dateAscending:
            return recordManager.records.sorted { $0.date < $1.date }
        case .distanceDescending:
            return recordManager.records.sorted { $0.distance > $1.distance }
        case .durationDescending:
            return recordManager.records.sorted { $0.duration > $1.duration }
        }
    }
}

// MARK: - Sort Order
enum SortOrder: String, CaseIterable {
    case dateDescending = "Sort_Date_Desc"
    case dateAscending = "Sort_Date_Asc"
    case distanceDescending = "Sort_Dist_Desc"
    case durationDescending = "Sort_Duration_Desc"
    
    var localized: String {
        return self.rawValue.localized
    }
}

// MARK: - Record Row
struct RecordRow: View {
    let record: RowingRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.formattedDate)
                    .font(.headline)
                Spacer()
                if let tags = record.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            HStack(spacing: 20) {
                MetricLabel(icon: "clock", value: record.formattedDuration)
                MetricLabel(icon: "ruler", value: record.formattedDistance)
                MetricLabel(icon: "metronome", value: "\(record.averageSPM) SPM")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Label
struct MetricLabel: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
        }
    }
}

// MARK: - Record Detail View
struct RecordDetailView: View {
    let record: RowingRecord
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var app: AppViewModel
    
    @State private var editedNotes: String = ""
    @State private var editedTags: [String] = []
    @State private var newTag: String = ""
    @State private var isEditing = false
    @State private var showingSaveConfirmation = false
    @State private var showCrewSheet = false
    @State private var currentCrewInfo: CrewInfo? = nil
    @State private var showingExpandedMap = false
    
    private var isIndoorRecord: Bool {
        if let tags = record.tags, tags.contains("Indoor") { return true }
        if record.isManagerMode { return true }
        if record.pm5SerialNumber != nil { return true }
        return false
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date
                    headerSection
                    
                    // Map section (if location available)
                    if record.startLocation != nil || record.endLocation != nil {
                        mapSection
                    }
                    
                    // Performance metrics
                    metricsSection
                    
                    // Crew section (PM5/Indoor/Manager以外のRowMode記録のみ表示)
                    if !isIndoorRecord {
                        crewSection
                    }
                    
                    // Workout Details Graph Button
                    if let dataPoints = record.dataPoints, !dataPoints.isEmpty {
                        NavigationLink {
                            WorkoutGraphView(dataPoints: dataPoints)
                        } label: {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                Text("Workout Details".localized)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
                            .foregroundColor(Theme.accent)
                        }
                    }
                    
                    // Tags section
                    tagsSection
                    
                    // Notes section
                    notesSection
                }
                .padding()
            }
        }
        .navigationTitle("Record Detail".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 共有ボタン
                    Button {
                        WorkoutShareManager.shared.presentShareSheet(for: record)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.accent)
                    }
                    
                    // 編集/保存ボタン
                    Button(isEditing ? "Save".localized : "Edit".localized) {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .onAppear {
            editedNotes = record.notes ?? ""
            editedTags = record.tags ?? []
            currentCrewInfo = record.crewInfo
        }
        .sheet(isPresented: $showCrewSheet) {
            CrewEditSheet(
                recordId: record.id,
                existingCrewInfo: currentCrewInfo,
                onSave: { crewInfo in
                    currentCrewInfo = crewInfo
                    app.recordManager.updateCrewInfo(for: record.id, crewInfo: crewInfo)
                },
                onDelete: {
                    currentCrewInfo = nil
                    app.recordManager.updateCrewInfo(for: record.id, crewInfo: nil)
                }
            )
        }
        .sheet(isPresented: $showingExpandedMap) {
            ExpandedMapView(record: record)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.rower")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primaryGradient)
            
            Text(record.formattedDate)
                .font(Theme.headerFont())
                .foregroundColor(Theme.textMain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route".localized, systemImage: "map.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            RecordMapView(startLocation: record.startLocation, endLocation: record.endLocation, routePoints: record.routePoints)
                .frame(height: 200)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showingExpandedMap = true
                }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance".localized, systemImage: "figure.outdoor.rowing")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(icon: "clock.fill", label: "Duration".localized, value: record.formattedDuration)
                MetricCard(icon: "ruler.fill", label: "Distance".localized, value: record.formattedDistance)
                MetricCard(icon: "metronome.fill", label: "Avg SPM".localized, value: "\(record.averageSPM)")
                if !(record.pm5SerialNumber != nil || record.isManagerMode || (record.tags?.contains("Indoor") == true)) {
                    MetricCard(icon: "speedometer", label: "Avg Speed".localized, value: String(format: "%.1f km/h", record.averageSpeed))
                }
                MetricCard(icon: "timer", label: "Pace".localized, value: record.formattedPace)
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.secondaryAccent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Crew Section
    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let crewInfo = currentCrewInfo {
                // クルー情報が登録済みの場合：ボート図を表示
                HStack {
                    Label("Crew", systemImage: "person.3.fill")
                        .font(Theme.subHeaderFont())
                        .foregroundColor(Theme.textMain)
                    
                    Spacer()
                    
                    Button(action: {
                        showCrewSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Edit".localized)
                               .font(.subheadline)
                            Image(systemName: "pencil")
                               .font(.caption)
                        }
                        .foregroundColor(Theme.accent)
                    }
                }
                
                BoatDiagramView(crewInfo: crewInfo)
                
                // 入力済みメンバー数
                HStack {
                    Image(systemName: "person.fill.checkmark")
                        .font(.caption)
                        .foregroundColor(Theme.accent)
                    Text("\(crewInfo.filledCount)/\(crewInfo.members.count) 名登録済み")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                // クルー未登録：追加ボタン
                Button(action: {
                    showCrewSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Theme.primaryGradient)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Crew")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textMain)
                            Text("クルーメンバーを記録")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tags".localized, systemImage: "tag.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            if isEditing {
                // Tag input
                HStack {
                    TextField("New Tag".localized, text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Theme.textMain)
                    
                    Button {
                        if !newTag.isEmpty {
                            editedTags.append(newTag)
                            newTag = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accent)
                            .font(.title2)
                    }
                }
            }
            
            if editedTags.isEmpty {
                Text("No Tags".localized)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(editedTags, id: \.self) { tag in
                        TagChip(tag: tag, isEditing: isEditing) {
                            editedTags.removeAll { $0 == tag }
                        }
                    }
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes".localized, systemImage: "note.text")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            if isEditing {
                TextEditor(text: $editedNotes)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(Theme.background.opacity(0.5))
                    .cornerRadius(12)
                    .foregroundColor(Theme.textMain)
            } else {
                Text(editedNotes.isEmpty ? "No Notes".localized : editedNotes)
                    .font(.body)
                    .foregroundColor(editedNotes.isEmpty ? Theme.textSecondary : Theme.textMain)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Save
    private func saveChanges() {
        app.recordManager.updateRecord(record.id, notes: editedNotes, tags: editedTags)
    }
}
 
// MARK: - Metric Card
struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.primaryGradient)
            
            Text(value)
                .font(.headline)
                .foregroundColor(Theme.textMain)
            
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.05, cornerRadius: 12)
    }
}


// MARK: - Tag Chip
struct TagChip: View {
    let tag: String
    let isEditing: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)
            
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.2))
        .foregroundColor(Theme.accent)
        .cornerRadius(12)
    }
}

// MARK: - Record Map View
struct RecordMapView: View {
    let startLocation: LocationData?
    let endLocation: LocationData?
    let routePoints: [LocationData]?
    
    var body: some View {
        Map {
            // 経路の描画 (セグメントに分割して、GPSロスト区間を破線で描画)
            if let points = routePoints, !points.isEmpty {
                // 正常区間 (ソリッド線)
                ForEach(Array(points.solidSegments().enumerated()), id: \.offset) { _, coords in
                    MapPolyline(coordinates: coords)
                        .stroke(Theme.accent, lineWidth: 4)
                }
                
                // GPSロスト復帰区間 (グレーの破線)
                ForEach(Array(points.gapSegments().enumerated()), id: \.offset) { _, coords in
                    MapPolyline(coordinates: coords)
                        .stroke(.gray, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                }
            }
            
            if let start = startLocation {
                Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            
            if let end = endLocation {
                Annotation("Goal", coordinate: CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude)) {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}

// MARK: - Expanded Map View
struct ExpandedMapView: View {
    let record: RowingRecord
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                RecordMapView(startLocation: record.startLocation, endLocation: record.endLocation, routePoints: record.routePoints)
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
            }
            .navigationTitle("Route".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close".localized) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

// MARK: - LocationData Array Extension
extension Array where Element == LocationData {
    func solidSegments() -> [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        var currentSegment: [CLLocationCoordinate2D] = []
        
        for point in self {
            let coord = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            if point.isPostGap == true {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                currentSegment = [coord]
            } else {
                currentSegment.append(coord)
            }
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        return segments
    }
    
    func gapSegments() -> [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        for i in 1..<self.count {
            if self[i].isPostGap == true {
                let prev = self[i - 1]
                let curr = self[i]
                segments.append([
                    CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude),
                    CLLocationCoordinate2D(latitude: curr.latitude, longitude: curr.longitude)
                ])
            }
        }
        return segments
    }
}

// MARK: - Flow Layout (Simple Implementation)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
