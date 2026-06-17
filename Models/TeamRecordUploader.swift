import Foundation
// CloudKit依存を削除済み（Cloudflare移行中）

/// メンバー側：練習記録のアップロードは現在無効化（Cloudflare移行中）
class TeamRecordUploader {
    static let shared = TeamRecordUploader()

    private init() {}

    // MARK: - チーム参加確認

    /// チームメンバーとして所属しているか（現在は常にfalse）
    var isTeamMember: Bool {
        // CloudKitTeamManager依存を削除 → 常にfalseを返す
        return false
    }

    // MARK: - ワークアウトのアップロード

    /// 記録保存後に呼び出す。現在はCloudflare移行中のため無効化
    func uploadIfNeeded(record: RowingRecord) {
        guard isTeamMember else {
            print("TeamRecordUploader: Not a team member (CloudKit disabled), skip upload.")
            return
        }
    }
}
