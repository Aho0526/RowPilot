import SwiftUI

/// サマリーをタップした時の詳細表示ビュー
/// Cloud（またはMockDB）からフルデータを取得して表示する
struct TeamRecordDetailView: View {
    let summary: TeamRecordSummary

    @ObservedObject var teamManager = TeamManager.shared
    @State private var fullRecord: RowingRecord? = nil
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if loadError && fullRecord == nil {
                errorView
            } else if let record = fullRecord {
                recordContent(record)
            } else {
                errorView
            }
        }
        .navigationTitle("\(summary.userName) の記録")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFullRecord()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                .scaleEffect(1.5)

            Text("記録を取得中..".localized)
                .font(.headline)
                .foregroundColor(.white)

            Text("\(summary.userName) さんの詳細データを\n読み込んでいます")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // サマリー情報を表示（ローディング中の情報提供）
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    miniStat(icon: "ruler", value: summary.formattedDistance)
                    miniStat(icon: "clock", value: summary.formattedDuration)
                    miniStat(icon: "metronome", value: "\(summary.averageSPM) SPM")
                }
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 40)
        }
    }

    private func miniStat(icon: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Theme.accent)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("記録の取得に失敗しました".localized)
                .font(.headline)
                .foregroundColor(.white)

            Text("ネットワーク接続を確認して\nもう一度お試しください".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: { loadFullRecord() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("再試行".localized)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.accent.opacity(0.2))
                .foregroundColor(Theme.accent)
                .cornerRadius(10)
            }

            // フォールバック：サマリーデータだけ表示
            VStack(alignment: .leading, spacing: 12) {
                Text("サマリー情報".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))

                summaryFallback
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Record Content

    private func recordContent(_ record: RowingRecord) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // メンバー情報ヘッダー
                memberHeader

                // パフォーマンスメトリクス
                metricsSection(record)

                // ワークアウトグラフ
                if let dataPoints = record.dataPoints, !dataPoints.isEmpty {
                    NavigationLink {
                        WorkoutGraphView(dataPoints: dataPoints)
                    } label: {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                            Text("ワークアウト詳細グラフ".localized)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
                        .foregroundColor(Theme.accent)
                    }
                }

                // タグ
                if let tags = record.tags, !tags.isEmpty {
                    tagsSection(tags)
                }

                // ノート
                if let notes = record.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
        }
    }

    // MARK: - Member Header

    private var memberHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.primaryGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 12)
                Text(String(summary.userName.prefix(1)))
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(.white)
            }

            Text(summary.userName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(summary.userId)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))

            Text(summary.date.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }

    // MARK: - Metrics

    private func metricsSection(_ record: RowingRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("パフォーマンス".localized, systemImage: "figure.outdoor.rowing")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricCard(icon: "clock.fill", label: "Duration", value: record.formattedDuration)
                MetricCard(icon: "ruler.fill", label: "Distance", value: record.formattedDistance)
                MetricCard(icon: "metronome.fill", label: "Avg SPM", value: "\(record.averageSPM)")
                MetricCard(icon: "timer", label: "Pace", value: record.formattedPace)
                if let watt = record.averageWatt {
                    MetricCard(icon: "bolt.fill", label: "Avg Watts", value: "\(watt) W")
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.secondaryAccent, opacity: 0.08, cornerRadius: 20)
    }

    // MARK: - Tags

    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("タグ".localized, systemImage: "tag.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)

            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.2))
                        .foregroundColor(Theme.accent)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("メモ".localized, systemImage: "note.text")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)

            Text(notes)
                .font(.body)
                .foregroundColor(Theme.textMain)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }

    // MARK: - Summary Fallback

    private var summaryFallback: some View {
        VStack(spacing: 8) {
            HStack {
                Text("距離:".localized)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(summary.formattedDistance)
                    .foregroundColor(.white)
            }
            HStack {
                Text("時間:".localized)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(summary.formattedDuration)
                    .foregroundColor(.white)
            }
            HStack {
                Text("SPM:")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("\(summary.averageSPM)")
                    .foregroundColor(.white)
            }
            HStack {
                Text("ペース:".localized)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(summary.formattedPace)
                    .foregroundColor(.white)
            }
        }
        .font(.subheadline)
    }

    // MARK: - Data Loading

    private func loadFullRecord() {
        isLoading = true
        loadError = false

        teamManager.fetchFullRecord(recordId: summary.id, userId: summary.userId) { record in
            DispatchQueue.main.async {
                self.isLoading = false
                if let record = record {
                    self.fullRecord = record
                } else {
                    self.loadError = true
                    // フォールバック: サマリーから簡易レコードを作成
                    self.fullRecord = RowingRecord(
                        id: UUID(uuidString: summary.id) ?? UUID(),
                        date: summary.date,
                        duration: summary.duration,
                        distance: summary.distance,
                        averageSPM: summary.averageSPM,
                        averageSpeed: 0,
                        averagePace: summary.averagePace,
                        tags: summary.tags,
                        isManagerMode: summary.isManagerMode
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TeamRecordDetailView(
            summary: TeamRecordSummary(
                id: UUID().uuidString,
                userId: "User_Test",
                userName: "テストユーザー",
                date: Date(),
                duration: 1800,
                distance: 5000,
                averageSPM: 26,
                averagePace: 120,
                isManagerMode: false,
                tags: ["朝練", "2000m"]
            )
        )
    }
}
