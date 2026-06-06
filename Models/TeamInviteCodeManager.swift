import Foundation
import CloudKit

/// チーム専用の招待コードを管理するクラス
/// Manager Plan共有用の InviteCodeManager とは別のコードを発行する
class TeamInviteCodeManager: ObservableObject {
    static let shared = TeamInviteCodeManager()

    // MARK: - Published State

    @Published var teamInviteCode: String = ""
    @Published var lastResetDate: Date? = nil
    @Published var isLoading: Bool = false

    // MARK: - Keys

    private let localCodeKey = "RowPilot_TeamInviteCode"
    private let lastResetDateKey = "RowPilot_TeamInviteCodeLastResetDate"
    private let iCloudCodeKey = "RowPilot_TeamInviteCode"
    private let iCloudResetKey = "RowPilot_TeamInviteCodeLastResetDate"
    private let recordType = "TeamInviteCode"

    // MARK: - CloudKit

    private var database: CKDatabase? {
        guard SubscriptionManager.shared.useCloudKit else { return nil }
        return CKContainer.default().privateCloudDatabase
    }

    // MARK: - Init

    init() {
        loadFromLocal()
    }

    // MARK: - Load / Save

    func loadFromLocal() {
        let icloudStore = NSUbiquitousKeyValueStore.default
        icloudStore.synchronize()

        let storedCode = icloudStore.string(forKey: iCloudCodeKey)
            ?? UserDefaults.standard.string(forKey: localCodeKey)
            ?? ""

        let storedResetDate = icloudStore.object(forKey: iCloudResetKey) as? Date
            ?? UserDefaults.standard.object(forKey: lastResetDateKey) as? Date

        self.teamInviteCode = storedCode
        self.lastResetDate = storedResetDate
    }

    private func saveToLocal(code: String, resetDate: Date?) {
        UserDefaults.standard.set(code, forKey: localCodeKey)
        if let date = resetDate {
            UserDefaults.standard.set(date, forKey: lastResetDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastResetDateKey)
        }

        let icloudStore = NSUbiquitousKeyValueStore.default
        icloudStore.set(code, forKey: iCloudCodeKey)
        if let date = resetDate {
            icloudStore.set(date, forKey: iCloudResetKey)
        } else {
            icloudStore.removeObject(forKey: iCloudResetKey)
        }
        icloudStore.synchronize()
    }

    // MARK: - Generate

    func generateNewCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func randomSegment(_ length: Int) -> String {
            String((0..<length).compactMap { _ in chars.randomElement() })
        }
        return "\(randomSegment(4))-\(randomSegment(4))"
    }

    // MARK: - Ensure Code Exists

    func ensureCodeExists() {
        if teamInviteCode.isEmpty {
            issueNewCode()
        }
    }

    private func issueNewCode(completion: (() -> Void)? = nil) {
        let newCode = generateNewCode()
        self.teamInviteCode = newCode
        self.lastResetDate = nil
        saveToLocal(code: newCode, resetDate: nil)
        uploadToCloudKit(code: newCode)
        completion?()
    }

    // MARK: - Reset

    func resetCode(completion: @escaping (Bool, String?) -> Void) {
        if let lastReset = lastResetDate {
            let daysSinceReset = Calendar.current.dateComponents([.day], from: lastReset, to: Date()).day ?? 0
            if daysSinceReset < 7 {
                let remaining = 7 - daysSinceReset
                completion(false, "コードのリセットは1週間に1回のみ可能です。あと\(remaining)日後にリセットできます。")
                return
            }
        }

        let newCode = generateNewCode()
        let now = Date()
        self.teamInviteCode = newCode
        self.lastResetDate = now
        saveToLocal(code: newCode, resetDate: now)

        // 既存のチームメンバーを全削除
        let teamManager = TeamManager.shared
        teamManager.teamMembers.removeAll()
        teamManager.pendingTeamRequests.removeAll()

        // CloudKitにも更新
        uploadToCloudKit(code: newCode)

        completion(true, nil)
    }

    // MARK: - CloudKit Sync

    private func uploadToCloudKit(code: String) {
        guard let db = database,
              let ownerID = UserDefaults.standard.string(forKey: "RowPilot_LocalUserRecordId") else { return }

        let recordID = CKRecord.ID(recordName: "TeamInvite_\(ownerID)")
        db.fetch(withRecordID: recordID) { [weak self] record, _ in
            let r = record ?? CKRecord(recordType: self?.recordType ?? "TeamInviteCode", recordID: recordID)
            r["code"] = code
            r["ownerID"] = ownerID
            r["resetDate"] = self?.lastResetDate
            db.save(r) { _, error in
                if let error = error {
                    print("TeamInviteCode CloudKit upload error: \(error)")
                } else {
                    print("TeamInviteCode uploaded to CloudKit: \(code)")
                }
            }
        }
    }

    /// コードからオーナーIDを逆引き
    func findTeamOwner(forCode code: String, completion: @escaping (String?) -> Void) {
        guard let db = database else {
            // CloudKit無効時はローカルから検索
            let localCode = teamInviteCode
            if localCode == code {
                completion(SubscriptionManager.shared.myUserRecordId)
            } else {
                let mockKey = "RowPilot_MockTeamInviteCodeDB"
                if let data = UserDefaults.standard.data(forKey: mockKey),
                   let mockDB = try? JSONDecoder().decode([String: String].self, from: data),
                   let ownerID = mockDB[code] {
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

    // MARK: - Mock DB Helper

    private let mockDBKey = "RowPilot_MockTeamInviteCodeDB"

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
        let days = Calendar.current.dateComponents([.day], from: lastReset, to: Date()).day ?? 0
        return days >= 7
    }

    var daysUntilReset: Int {
        guard let lastReset = lastResetDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: lastReset, to: Date()).day ?? 0
        return max(0, 7 - days)
    }
}
