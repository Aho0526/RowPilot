import Foundation
import CloudKit

/// メンバー側：練習記録をCloudKit Shared Databaseにアップロードするクラス
/// 個人データの正本はPrivate Database（ICloudSyncManager経由）に保存済み
/// Team所属中のみ、Shared DBにSummary+Detailをコピーする
class TeamRecordUploader {
    static let shared = TeamRecordUploader()

    private init() {}

    // MARK: - チーム参加確認

    /// チームメンバーとして所属しているか
    var isTeamMember: Bool {
        CloudKitTeamManager.shared.isTeamMember
    }

    // MARK: - ワークアウトのアップロード

    /// 記録保存後に呼び出す。チーム所属中であれば Shared DB にサマリー＋詳細をコピー
    func uploadIfNeeded(record: RowingRecord) {
        guard isTeamMember else {
            print("TeamRecordUploader: Not a team member, skip upload.")
            return
        }

        let myName = SettingsManager.shared.settings.sharingName
        guard !myName.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("TeamRecordUploader: Sharing name is empty, skip upload.")
            return
        }

        print("TeamRecordUploader: Uploading workout \(record.id) to Shared DB...")
        CloudKitTeamManager.shared.uploadWorkoutToTeam(record: record)
    }
}
