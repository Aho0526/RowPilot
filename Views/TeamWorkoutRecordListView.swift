import SwiftUI

struct TeamWorkoutRecordListView: View {
    let workouts: [CloudflareWorkoutRecord]
    @Environment(\.dismiss) private var dismiss
    
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if workouts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.2))
                    Text("まだトレーニング記録がありません".localized)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(workouts) { record in
                            workoutListRow(record: record)
                            if record.id != workouts.last?.id {
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                    }
                    .padding()
                    .glassCardStyle(glowColor: Theme.accent, opacity: 0.05, cornerRadius: 20)
                    .padding()
                }
            }
        }
        .navigationTitle("トレーニング記録".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる".localized) {
                    dismiss()
                }
                .foregroundColor(Theme.accent)
            }
        }
    }
    
    private func workoutListRow(record: CloudflareWorkoutRecord) -> some View {
        HStack(spacing: 14) {
            // 日付表示
            VStack(alignment: .leading, spacing: 2) {
                if let date = record.recordedDate {
                    Text("\(dayFormatter.string(from: date))日")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(monthFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("--")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 44, alignment: .leading)
            
            // 選手名 & ワークアウト概要
            VStack(alignment: .leading, spacing: 4) {
                Text(record.athlete_name ?? "不明")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))
                Text(record.workoutSummary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.accent)
            }
            
            Spacer()
            
            // 記録 (5025m / 7:30 / - )
            Text(record.recordSummaryText)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.white)
            
            // 詳細リンク
            NavigationLink(destination: TeamWorkoutRecordDetailView(record: record)) {
                HStack(spacing: 2) {
                    Text("詳細")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(Theme.accent)
            }
        }
        .padding(.vertical, 8)
    }
}
