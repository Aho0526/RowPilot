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
                RecordDetailView(record: record)
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
    
    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close".localized) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save".localized : "Edit".localized) {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .onAppear {
                editedNotes = record.notes ?? ""
                editedTags = record.tags ?? []
            }
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
        .background(Theme.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route".localized, systemImage: "map.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            RecordMapView(startLocation: record.startLocation, endLocation: record.endLocation)
                .frame(height: 200)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance".localized, systemImage: "chart.bar.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(icon: "clock.fill", label: "Duration".localized, value: record.formattedDuration)
                MetricCard(icon: "ruler.fill", label: "Distance".localized, value: record.formattedDistance)
                MetricCard(icon: "metronome.fill", label: "Avg SPM".localized, value: "\(record.averageSPM)")
                MetricCard(icon: "speedometer", label: "Avg Speed".localized, value: String(format: "%.1f km/h", record.averageSpeed))
                MetricCard(icon: "timer", label: "Pace".localized, value: record.formattedPace)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
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
        .background(Theme.cardBackground)
        .cornerRadius(20)
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
        .background(Theme.cardBackground)
        .cornerRadius(20)
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
        .background(Theme.background.opacity(0.5))
        .cornerRadius(12)
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
    
    var body: some View {
        Map {
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
