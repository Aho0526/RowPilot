import SwiftUI

struct TeamWorkoutRecordDetailView: View {
    let record: CloudflareWorkoutRecord
    @Environment(\.dismiss) private var dismiss
    
    private var decodedCrewInfo: CrewInfo? {
        guard let jsonString = record.crew_info,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(CrewInfo.self, from: data)
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 12) {
                        Image(systemName: "figure.rower")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.accent)
                            .padding(.top, 16)
                        
                        Text(record.athlete_name ?? "不明な選手".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let date = record.recordedDate {
                            Text(date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            Text(date, style: .time)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCardStyle(glowColor: Theme.accent, opacity: 0.1, cornerRadius: 20)
                    
                    // Stats Grid
                    VStack(spacing: 16) {
                        Text("ワークアウト結果".localized)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            statCard(title: "距離".localized, value: record.formattedDistance, icon: "ruler", color: Theme.accent)
                            statCard(title: "時間".localized, value: record.formattedDurationShort, icon: "timer", color: .blue)
                            statCard(title: "500m ペース".localized, value: record.formattedSplit, icon: "speedometer", color: .purple)
                            statCard(title: "ストロープレート".localized, value: record.stroke_rate.map { "\($0) spm" } ?? "- spm", icon: "waveform.path", color: .orange)
                        }
                    }
                    
                    // Crew Card
                    if let crewInfo = decodedCrewInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("クルー編成".localized)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            BoatDiagramView(crewInfo: crewInfo)
                                .frame(height: 180)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(12)
                            
                            HStack {
                                Spacer()
                                Text("\(crewInfo.filledCount)/\(crewInfo.members.count) 名登録済み")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06, cornerRadius: 16)
                    }
                    
                    // Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("詳細情報".localized)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        VStack(spacing: 12) {
                            detailRow(label: "ボートタイプ".localized, value: record.boat_type ?? "指定なし".localized)
                            Divider().background(Color.white.opacity(0.1))
                            detailRow(label: "ワークアウト種別".localized, value: record.workoutSummary)
                            Divider().background(Color.white.opacity(0.1))
                            detailRow(label: "レコードID".localized, value: record.id)
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                    .padding()
                    .glassCardStyle(glowColor: .white, opacity: 0.05, cornerRadius: 16)
                }
                .padding()
            }
        }
        .navigationTitle("トレーニング記録詳細".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
                .font(.subheadline)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .font(.subheadline)
        }
    }
}
