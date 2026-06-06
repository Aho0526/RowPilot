import Foundation
import CloudKit

/// メンバー側：練習記録をCloud（またはMockDB）にアップロードするクラス
/// 記録保存時に自動的にサマリー＋フルデータをアップロードする
class TeamRecordUploader: ObservableObject {
    static let shared = TeamRecordUploader()

    // MARK: - CloudKit

    private var useCloudKit: Bool { SubscriptionManager.shared.useCloudKit }

    private var database: CKDatabase? {
        guard useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }

    // MARK: - Mock DB Keys

    private let mockSummariesKey = "RowPilot_MockTeamRecords"
    private let mockFullRecordsKey = "RowPilot_MockTeamFullRecords"

    // MARK: - チーム参加中かどうか

    var isTeamMember: Bool {
        return TeamManager.shared.isTeamMember
    }

    // MARK: - サマリーアップロード

    /// 記録のサマリーをCloudにアップロード（メンバーが記録保存時に呼ばれる）
    func uploadRecordSummary(_ record: RowingRecord) {
        guard isTeamMember else { return }

        let myID = SubscriptionManager.shared.myUserRecordId
        let myName = SettingsManager.shared.settings.sharingName

        guard !myID.isEmpty, !myName.isEmpty else {
            print("TeamRecordUploader: Missing user ID or sharing name, skipping upload.")
            return
        }

        let summary = TeamRecordSummary(
            id: record.id.uuidString,
            userId: myID,
            userName: myName,
            date: record.date,
            duration: record.duration,
            distance: record.distance,
            averageSPM: record.averageSPM,
            averagePace: record.averagePace,
            isManagerMode: record.isManagerMode,
            tags: record.tags
        )

        guard let db = database else {
            // Mock: ローカルに保存
            saveMockSummary(summary)
            uploadFullRecord(record)
            print("TeamRecordUploader: Summary saved to MockDB (id: \(record.id.uuidString))")
            return
        }

        let ckRecord = CKRecord(recordType: "TeamRecordSummary", recordID: CKRecord.ID(recordName: "Summary_\(record.id.uuidString)"))
        ckRecord["recordId"] = summary.id
        ckRecord["userId"] = summary.userId
        ckRecord["userName"] = summary.userName
        ckRecord["date"] = summary.date
        ckRecord["duration"] = summary.duration
        ckRecord["distance"] = summary.distance
        ckRecord["averageSPM"] = summary.averageSPM
        ckRecord["averagePace"] = summary.averagePace
        ckRecord["isManagerMode"] = summary.isManagerMode ? 1 : 0
        ckRecord["tags"] = summary.tags

        db.save(ckRecord) { [weak self] _, error in
            if let error = error {
                print("TeamRecordUploader: Summary upload error: \(error.localizedDescription)")
            } else {
                print("TeamRecordUploader: Summary uploaded successfully (id: \(record.id.uuidString))")
                // サマリーアップロード成功後にフルデータもアップロード
                self?.uploadFullRecord(record)
            }
        }
    }

    // MARK: - フルデータアップロード

    /// 記録の詳細データをCloudにアップロード
    func uploadFullRecord(_ record: RowingRecord) {
        guard isTeamMember else { return }

        let myID = SubscriptionManager.shared.myUserRecordId
        guard !myID.isEmpty else { return }

        guard let db = database else {
            // Mock: ローカルに保存
            saveMockFullRecord(record)
            print("TeamRecordUploader: Full record saved to MockDB (id: \(record.id.uuidString))")
            return
        }

        let ckRecord = CKRecord(recordType: "TeamFullRecord", recordID: CKRecord.ID(recordName: "Full_\(record.id.uuidString)"))
        ckRecord["recordId"] = record.id.uuidString
        ckRecord["userId"] = myID
        ckRecord["date"] = record.date
        ckRecord["duration"] = record.duration
        ckRecord["distance"] = record.distance
        ckRecord["averageSPM"] = record.averageSPM
        ckRecord["averageSpeed"] = record.averageSpeed
        ckRecord["averagePace"] = record.averagePace
        ckRecord["isManagerMode"] = record.isManagerMode ? 1 : 0
        ckRecord["notes"] = record.notes
        ckRecord["tags"] = record.tags

        if let watt = record.averageWatt {
            ckRecord["averageWatt"] = watt
        }

        // dataPointsはJSONデータとして保存
        if let dataPoints = record.dataPoints,
           let dpData = try? JSONEncoder().encode(dataPoints) {
            ckRecord["dataPointsJSON"] = dpData
        }

        db.save(ckRecord) { _, error in
            if let error = error {
                print("TeamRecordUploader: Full record upload error: \(error.localizedDescription)")
            } else {
                print("TeamRecordUploader: Full record uploaded successfully (id: \(record.id.uuidString))")
            }
        }
    }

    // MARK: - Mock DB Helpers

    private func saveMockSummary(_ summary: TeamRecordSummary) {
        var all = getAllMockSummaries()
        // 既存のものがあれば更新
        all.removeAll { $0.id == summary.id }
        all.append(summary)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: mockSummariesKey)
        }
    }

    private func getAllMockSummaries() -> [TeamRecordSummary] {
        guard let data = UserDefaults.standard.data(forKey: mockSummariesKey),
              let all = try? JSONDecoder().decode([TeamRecordSummary].self, from: data) else { return [] }
        return all
    }

    private func saveMockFullRecord(_ record: RowingRecord) {
        var allRecords: [String: Data] = [:]
        if let data = UserDefaults.standard.data(forKey: mockFullRecordsKey),
           let existing = try? JSONDecoder().decode([String: Data].self, from: data) {
            allRecords = existing
        }

        if let recordData = try? JSONEncoder().encode(record) {
            allRecords[record.id.uuidString] = recordData
        }

        if let data = try? JSONEncoder().encode(allRecords) {
            UserDefaults.standard.set(data, forKey: mockFullRecordsKey)
        }
    }
}
