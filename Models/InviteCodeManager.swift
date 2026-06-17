// CloudKit依存 - Cloudflare移行中のため無効化
#if false
import Foundation
import CloudKit
import Combine

/// xxxx-xxxx形式の招待コードを生成・管理するクラス
/// Team/MAXユーザーが所持するユニークキー。ローカル＋CloudKit(iCloud)両方に保存。
class InviteCodeManager: ObservableObject {
    static let shared = InviteCodeManager()

    // MARK: - Published State

    @Published var inviteCode: String = ""
    @Published var lastResetDate: Date? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Keys

    private let localCodeKey = "RowPilot_InviteCode"
    private let lastResetDateKey = "RowPilot_InviteCodeLastResetDate"
    private let iCloudCodeKey = "RowPilot_InviteCode"
    private let iCloudResetKey = "RowPilot_InviteCodeLastResetDate"

    /// CloudKitレコードタイプ
    private let recordType = "InviteCode"

    // MARK: - CloudKit

    private var database: CKDatabase? {
        guard SubscriptionManager.shared.useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }

    // MARK: - Init

    init() {
        loadFromLocal()
    }

    // MARK: - Load / Save

    /// ローカルからコードを読み込む
    func loadFromLocal() {
        let storedCode = UserDefaults.standard.string(forKey: localCodeKey) ?? ""
        let storedResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date

        self.inviteCode = storedCode
        self.lastResetDate = storedResetDate
    }

    /// コードをローカルに保存
    private func saveToLocal(code: String, resetDate: Date?) {
        UserDefaults.standard.set(code, forKey: localCodeKey)
        if let date = resetDate {
            UserDefaults.standard.set(date, forKey: lastResetDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastResetDateKey)
        }
    }

    // MARK: - Generate

    /// 新しい招待コードを生成して保存する（初回 or リセット時）
    func generateNewCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // 紛らわしい文字を除外
        func randomSegment(_ length: Int) -> String {
            String((0..<length).compactMap { _ in chars.randomElement() })
        }
        return "\(randomSegment(4))-\(randomSegment(4))"
    }

    // MARK: - Ensure Code Exists

    /// コードがなければ新規発行する
    func ensureCodeExists() {
        if inviteCode.isEmpty {
            issueNewCode()
        }
    }

    /// 新規コードを発行して保存
    private func issueNewCode(completion: (() -> Void)? = nil) {
        let newCode = generateNewCode()
        self.inviteCode = newCode
        self.lastResetDate = nil
        saveToLocal(code: newCode, resetDate: nil)
        uploadToCloudKit(code: newCode)
        completion?()
    }

    // MARK: - Reset

    /// コードをリセット（5分に1回制限）
    /// リセット時は SubscriptionManager の sharedMembers も全削除
    func resetCode(completion: @escaping (Bool, String?) -> Void) {
        // 5分間制限チェック
        if let lastReset = lastResetDate {
            let minutesSinceReset = Calendar.current.dateComponents([.minute], from: lastReset, to: Date()).minute ?? 0
            if minutesSinceReset < 5 {
                let remaining = 5 - minutesSinceReset
                completion(false, "コードのリセットは5分に1回のみ可能です。あと\(remaining)分後にリセットできます。")
                return
            }
        }

        let newCode = generateNewCode()
        let now = Date()
        self.inviteCode = newCode
        self.lastResetDate = now
        saveToLocal(code: newCode, resetDate: now)

        // 既存の共有メンバーを全削除（コード流出リスク対応）
        let subManager = SubscriptionManager.shared
        subManager.sharedMembers.removeAll()
        subManager.pendingRequests.removeAll()
        subManager.uploadShareRecord()

        // CloudKitにも更新
        uploadToCloudKit(code: newCode)

        completion(true, nil)
    }

    // MARK: - CloudKit Sync

    /// CloudKit（publicDB）にコードをアップロード
    private func uploadToCloudKit(code: String) {
        guard let db = database,
              let ownerID = UserDefaults.standard.string(forKey: "RowPilot_LocalUserRecordId") else { return }

        let recordID = CKRecord.ID(recordName: "InviteCode_\(ownerID)")
        db.fetch(withRecordID: recordID) { [weak self] record, _ in
            let r = record ?? CKRecord(recordType: self?.recordType ?? "InviteCode", recordID: recordID)
            r["code"] = code
            r["ownerID"] = ownerID
            r["resetDate"] = self?.lastResetDate
            db.save(r) { _, error in
                if let error = error {
                    print("InviteCode CloudKit upload error: \(error)")
                } else {
                    print("InviteCode uploaded to CloudKit: \(code)")
                }
            }
        }
    }

    /// CloudKitからコードを検索（コード → ownerIDを逆引き）
    func findOwnerID(forCode code: String, completion: @escaping (String?) -> Void) {
        guard let db = database else {
            // CloudKit無効時はローカルのMockDBから検索
            let localCode = inviteCode
            if localCode == code {
                completion(SubscriptionManager.shared.myUserRecordId)
            } else {
                // ローカルMockDBからスキャン
                let mockKey = "RowPilot_MockInviteCodeDB"
                if let data = UserDefaults.standard.data(forKey: mockKey),
                   let db = try? JSONDecoder().decode([String: String].self, from: data),
                   let ownerID = db[code] {
                    completion(ownerID)
                } else {
                    completion(nil)
                }
            }
            return
        }

        let predicate = NSPredicate(format: "code == %@", code)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        var foundOwnerID: String? = nil

        let operation = CKQueryOperation(query: query)
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                foundOwnerID = record["ownerID"] as? String
            }
        }
        operation.queryResultBlock = { _ in
            DispatchQueue.main.async {
                completion(foundOwnerID)
            }
        }
        db.add(operation)
    }

    // MARK: - Mock DB Helper（CloudKit無効時用）

    /// CloudKit無効時のモックDB: [code: ownerID]
    private let mockDBKey = "RowPilot_MockInviteCodeDB"

    func saveMockEntry(code: String, ownerID: String) {
        var db = getMockDB()
        db[code] = ownerID
        if let data = try? JSONEncoder().encode(db) {
            UserDefaults.standard.set(data, forKey: mockDBKey)
        }
    }

    private func getMockDB() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: mockDBKey),
              let db = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return db
    }

    // MARK: - Helpers

    var canReset: Bool {
        guard let lastReset = lastResetDate else { return true }
        let minutes = Calendar.current.dateComponents([.minute], from: lastReset, to: Date()).minute ?? 0
        return minutes >= 5
    }

    var minutesUntilReset: Int {
        guard let lastReset = lastResetDate else { return 0 }
        let minutes = Calendar.current.dateComponents([.minute], from: lastReset, to: Date()).minute ?? 0
        return max(0, 5 - minutes)
    }
}
#endif // CloudKit依存 - Cloudflare移行中のため無効化
