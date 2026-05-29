import SwiftUI

struct ManagerSessionDetailView: View {
    let records: [RowingRecord]
    
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
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(record.pm5CustomName ?? record.pm5SerialNumber ?? "Unknown PM5")
                                            .font(.headline)
                                            .foregroundColor(Theme.textMain)
                                        if let serial = record.pm5SerialNumber, record.pm5CustomName != nil {
                                            Text(serial)
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    
                                    Button {
                                        let prepared = WorkoutShareManager.shared.prepareManagerRecord(record)
                                        WorkoutShareManager.shared.presentShareSheet(for: prepared)
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title3)
                                            .foregroundColor(Theme.accent)
                                            .padding(6)
                                            .contentShape(Rectangle())
                                    }
                                }
                                
                                Divider()
                                    .background(Theme.textSecondary.opacity(0.2))
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    DetailMetricRow(icon: "clock.fill", label: "Duration", value: record.formattedDuration)
                                    DetailMetricRow(icon: "ruler.fill", label: "Distance", value: record.formattedDistance)
                                    DetailMetricRow(icon: "timer", label: "Pace", value: record.formattedPace)
                                    if let watt = record.averageWatt {
                                        DetailMetricRow(icon: "bolt.fill", label: "Avg Watt", value: "\(watt) W")
                                    } else {
                                        DetailMetricRow(icon: "bolt.fill", label: "Avg Watt", value: "N/A")
                                    }
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
                }
                .padding()
            }
        }
        .navigationTitle("Manager Session Detail".localized)
        .navigationBarTitleDisplayMode(.inline)
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
