import SwiftUI

struct ManagerSessionDetailView: View {
    let records: [RowingRecord]
    
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showMaxPlanAlert = false
    @State private var showSubscriptionView = false
    @State private var showingShareHelp = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.primaryGradient)
                        
                        Text("Manager Session".localized)
                            .font(Theme.headerFont())
                            .foregroundColor(Theme.textMain)
                        
                        if let firstRecord = records.first {
                            Text(firstRecord.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Theme.cardBackground)
                    .cornerRadius(20)
                    
                    // Device Records List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connected Devices".localized)
                            .font(Theme.subHeaderFont())
                            .foregroundColor(Theme.textMain)
                            .padding(.horizontal, 4)
                        
                        ForEach(records.sorted { ($0.pm5CustomName ?? "") < ($1.pm5CustomName ?? "") }) { record in
                            ManagerDeviceCardView(
                                record: record,
                                currentPlan: currentPlan,
                                onCSVExportLocked: { showMaxPlanAlert = true },
                                onShowShareHelp: { showingShareHelp = true }
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Manager Session Detail".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("RowPilot MAX Exclusive".localized, isPresented: $showMaxPlanAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("View Plans".localized) {
                showSubscriptionView = true
            }
        } message: {
            Text("CSV export is a RowPilot MAX exclusive feature. Upgrade to unlock this feature.".localized)
        }
        .sheet(isPresented: $showSubscriptionView) {
            NavigationStack {
                SubscriptionView()
            }
        }
        .sheet(isPresented: $showingShareHelp) {
            ShareHelpView()
        }
    }
}

// MARK: - Manager Device Card View
struct ManagerDeviceCardView: View {
    let record: RowingRecord
    let currentPlan: SubscriptionPlan
    let onCSVExportLocked: () -> Void
    let onShowShareHelp: () -> Void
    
    private var titleText: String {
        if let custom = record.pm5CustomName, !custom.isEmpty {
            return custom
        }
        if let serial = record.pm5SerialNumber, !serial.isEmpty {
            return serial
        }
        return "Unknown PM5"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                        .foregroundColor(Theme.textMain)
                    if let serial = record.pm5SerialNumber, record.pm5CustomName != nil {
                        Text(serial)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                
                HStack(spacing: 4) {
                    Menu {
                        Button {
                            let prepared = WorkoutShareManager.shared.prepareManagerRecord(record)
                            WorkoutShareManager.shared.presentShareSheet(for: prepared)
                        } label: {
                            Label("Share RowPilot Data (.rowpilot)".localized, systemImage: "doc.text")
                        }
                        
                        Button {
                            if currentPlan.hasCSVExport {
                                let prepared = WorkoutShareManager.shared.prepareManagerRecord(record)
                                WorkoutShareManager.shared.presentCSVShareSheet(for: prepared)
                            } else {
                                onCSVExportLocked()
                            }
                        } label: {
                            if currentPlan.hasCSVExport {
                                Label("Export CSV (.csv)".localized, systemImage: "tablecells")
                            } else {
                                Label("Export CSV (.csv) 👑".localized, systemImage: "tablecells")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(Theme.accent)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    
                    Button {
                        onShowShareHelp()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(Theme.accent)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                }
            }
            
            Divider()
                .background(Theme.textSecondary.opacity(0.2))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DetailMetricRow(icon: "clock.fill", label: "Duration", value: record.formattedDuration)
                DetailMetricRow(icon: "ruler.fill", label: "Distance", value: record.formattedDistance)
                DetailMetricRow(icon: "timer", label: "Pace", value: record.formattedPace)
                DetailMetricRow(icon: "metronome.fill", label: "Avg SPM", value: record.averageSPM > 0 ? "\(record.averageSPM)" : "-")
                if let watt = record.averageWatt {
                    DetailMetricRow(icon: "bolt.fill", label: "Avg Watt", value: "\(watt) W")
                } else {
                    DetailMetricRow(icon: "bolt.fill", label: "Avg Watt", value: "N/A")
                }
            }
            
            // 詳細確認リンク
            NavigationLink {
                RecordDetailView(record: record)
            } label: {
                HStack {
                    Text("View Details".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DetailMetricRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .font(.subheadline)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label.localized)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textMain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
