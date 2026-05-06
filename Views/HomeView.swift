import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
    private var recordManager: RecordManager { app.recordManager }
    private var tideManager: TideManager { app.tideManager }
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
                        
                        // MARK: - Monthly Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Records".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                                .padding(.horizontal)
                            
                            statsGrid
                        }
                        
                        // MARK: - History
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                                .padding(.horizontal)
                            
                            if recordManager.records.isEmpty {
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
                     // Explicitly trigger a fetch if current data is nil
                     if let station = tideManager.nearestStation {
                         tideManager.fetchTideData(for: station, date: Date())
                     }
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
                Image(systemName: "sun.max.fill") // Placeholder icon
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.primaryGradient)
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
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                icon: "ruler",
                label: "Distance".localized,
                value: formatDistance(recordManager.monthlyDistance),
                color: Theme.accent
            )
            StatCard(
                icon: "clock",
                label: "Duration".localized,
                value: formatDuration(recordManager.monthlyDuration),
                color: Theme.secondaryAccent
            )
            StatCard(
                icon: "number",
                label: "Count".localized, // Need to add to Manager
                value: "\(recordManager.recordsThisMonth.count)",
                color: .orange
            )
        }
        .padding(.horizontal)
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
    
    private var historyList: some View {
        LazyVStack(spacing: 12) {
            ForEach(recordManager.records.sorted { $0.date > $1.date }) { record in
                NavigationLink(destination: RecordDetailView(record: record)) {
                    RecordRowCard(record: record)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
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
