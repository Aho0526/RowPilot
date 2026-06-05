import Foundation
import CloudKit
import Combine

/// Manager Planの共有リクエスト（要求・承認・拒否）を管理するモデル
struct ShareRequest: Codable, Identifiable, Equatable {
    var id: String          // リクエストID (UUID)
    var requestorID: String // リクエスト送信者のuserRecordId
    var requestorName: String // 共有先の登録名
    var ownerID: String     // 共有元オーナーのuserRecordId
    var inviteCode: String  // 使用した招待コード
    var status: ShareRequestStatus
    var createdAt: Date

    enum ShareRequestStatus: String, Codable {
        case pending   // 承認待ち
        case approved  // 承認済み
        case rejected  // 拒否済み
    }
}

/// 共有リクエストの送受信・承認フローを管理するクラス
class ShareRequestManager: ObservableObject {
    static let shared = ShareRequestManager()

    // MARK: - Published State

    @Published var pendingRequests: [ShareRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - CloudKit

    private let recordType = "ShareRequest"

    private var database: CKDatabase? {
        guard SubscriptionManager.shared.useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }

    // MARK: - Keys

    private let localPendingKey = "RowPilot_PendingShareRequests"

    // MARK: - Init

    init() {
        loadLocalPendingRequests()
    }

    // MARK: - Load Local

    private func loadLocalPendingRequests() {
        guard let data = UserDefaults.standard.data(forKey: localPendingKey),
              let requests = try? JSONDecoder().decode([ShareRequest].self, from: data) else { return }
        self.pendingRequests = requests.filter { $0.status == .pending }
    }

    private func saveLocalPendingRequests() {
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        UserDefaults.standard.set(data, forKey: localPendingKey)
    }

    // MARK: - Send Request（メンバー側: コードを入力して送信）

    /// 招待コードを使って共有リクエストを送信する
    /// - Parameters:
    ///   - code: 入力した招待コード（xxxx-xxxx形式）
    ///   - requestorName: 共有先ユーザーの登録名
    ///   - requestorID: 共有先ユーザーのID
    ///   - completion: (成功, エラーメッセージ)
    func sendRequest(
        code: String,
        requestorName: String,
        requestorID: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard !requestorName.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "共有時の名前が設定されていません。設定画面から「共有時の名前」を入力してください。")
            return
        }

        isLoading = true

        // コードからオーナーを逆引き
        InviteCodeManager.shared.findOwnerID(forCode: code) { [weak self] ownerID in
            guard let self = self else { return }

            guard let ownerID = ownerID else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, "招待コードが見つかりません。コードを確認して再入力してください。")
                }
                return
            }

            guard ownerID != requestorID else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, "自分自身のコードは使用できません。")
                }
                return
            }

            let request = ShareRequest(
                id: UUID().uuidString,
                requestorID: requestorID,
                requestorName: requestorName.trimmingCharacters(in: .whitespaces),
                ownerID: ownerID,
                inviteCode: code,
                status: .pending,
                createdAt: Date()
            )

            self.saveRequest(request) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(success, error)
                }
            }
        }
    }

    // MARK: - Save Request

    private func saveRequest(_ request: ShareRequest, completion: @escaping (Bool, String?) -> Void) {
        guard let db = database else {
            // CloudKit無効時：ローカルMockDBに保存して、オーナーに通知するシミュレーション
            saveMockRequest(request)
            // オーナーが自分であれば即座にpendingListに追加（開発テスト用）
            if request.ownerID == SubscriptionManager.shared.myUserRecordId {
                DispatchQueue.main.async {
                    self.pendingRequests.append(request)
                    self.saveLocalPendingRequests()
                }
            }
            completion(true, nil)
            return
        }

        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: request.id))
        record["requestorID"] = request.requestorID
        record["requestorName"] = request.requestorName
        record["ownerID"] = request.ownerID
        record["inviteCode"] = request.inviteCode
        record["status"] = request.status.rawValue
        record["createdAt"] = request.createdAt

        db.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "リクエストの送信に失敗しました: \(error.localizedDescription)")
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // MARK: - Fetch Pending Requests（オーナー側）

    /// オーナーに届いた承認待ちリクエストを取得する
    func fetchPendingRequests(ownerID: String, completion: (() -> Void)? = nil) {
        guard !ownerID.isEmpty else { return }
        isLoading = true

        guard let db = database else {
            // CloudKit無効時はローカルMockDBから取得
            let mockRequests = getMockRequests(ownerID: ownerID)
            DispatchQueue.main.async {
                self.pendingRequests = mockRequests.filter { $0.status == .pending }
                self.saveLocalPendingRequests()
                self.isLoading = false
                completion?()
            }
            return
        }

        let predicate = NSPredicate(format: "ownerID == %@ AND status == %@", ownerID, "pending")
        let query = CKQuery(recordType: recordType, predicate: predicate)
        var requests: [ShareRequest] = []

        let operation = CKQueryOperation(query: query)
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result,
               let req = self.parseRecord(record) {
                requests.append(req)
            }
        }
        operation.queryResultBlock = { _ in
            DispatchQueue.main.async {
                self.pendingRequests = requests
                self.saveLocalPendingRequests()
                self.isLoading = false
                completion?()
            }
        }
        db.add(operation)
    }

    // MARK: - Approve / Reject

    /// リクエストを承認する → SubscriptionManagerのsharedMembersに追加
    func approveRequest(_ request: ShareRequest, completion: @escaping (Bool, String?) -> Void) {
        let subManager = SubscriptionManager.shared

        // 共有枠チェック
        if subManager.sharedMembers.count >= subManager.shareLimit {
            completion(false, "共有枠の上限（最大\(subManager.shareLimit)名）に達しています。")
            return
        }

        // 既存メンバーチェック
        if subManager.sharedMembers.contains(request.requestorID) {
            completion(false, "このユーザーは既に共有されています。")
            return
        }

        // sharedMembersに追加
        subManager.sharedMembers.append(request.requestorID)
        subManager.sharedMemberNames[request.requestorID] = request.requestorName
        subManager.uploadShareRecord()

        // リクエストのステータス更新
        updateRequestStatus(request.id, status: .approved)

        // ローカルから削除
        removePendingRequest(id: request.id)

        // CloudKit無効時のMock更新
        if database == nil {
            updateMockRequestStatus(request.id, status: .approved)
            // メンバー側の共有状態も更新（Mock）
            let mockKey = "RowPilot_MockSharedMemberStatus_\(request.requestorID)"
            UserDefaults.standard.set(request.ownerID, forKey: mockKey)
        }

        completion(true, nil)
    }

    /// リクエストを拒否する
    func rejectRequest(_ request: ShareRequest, completion: @escaping (Bool, String?) -> Void) {
        updateRequestStatus(request.id, status: .rejected)
        removePendingRequest(id: request.id)

        if database == nil {
            updateMockRequestStatus(request.id, status: .rejected)
        }

        completion(true, nil)
    }

    // MARK: - Status Update (CloudKit)

    private func updateRequestStatus(_ requestID: String, status: ShareRequest.ShareRequestStatus) {
        guard let db = database else { return }
        let recordID = CKRecord.ID(recordName: requestID)
        db.fetch(withRecordID: recordID) { record, error in
            guard let record = record else { return }
            record["status"] = status.rawValue
            db.save(record) { _, _ in }
        }
    }

    // MARK: - Local Helpers

    private func removePendingRequest(id: String) {
        pendingRequests.removeAll { $0.id == id }
        saveLocalPendingRequests()
    }

    private func parseRecord(_ record: CKRecord) -> ShareRequest? {
        guard let requestorID = record["requestorID"] as? String,
              let requestorName = record["requestorName"] as? String,
              let ownerID = record["ownerID"] as? String,
              let inviteCode = record["inviteCode"] as? String,
              let statusRaw = record["status"] as? String,
              let status = ShareRequest.ShareRequestStatus(rawValue: statusRaw),
              let createdAt = record["createdAt"] as? Date else { return nil }

        return ShareRequest(
            id: record.recordID.recordName,
            requestorID: requestorID,
            requestorName: requestorName,
            ownerID: ownerID,
            inviteCode: inviteCode,
            status: status,
            createdAt: createdAt
        )
    }

    // MARK: - Mock DB Helpers

    private let mockRequestsKey = "RowPilot_MockShareRequests"

    private func saveMockRequest(_ request: ShareRequest) {
        var all = getAllMockRequests()
        all.append(request)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: mockRequestsKey)
        }
    }

    private func getAllMockRequests() -> [ShareRequest] {
        guard let data = UserDefaults.standard.data(forKey: mockRequestsKey),
              let all = try? JSONDecoder().decode([ShareRequest].self, from: data) else { return [] }
        return all
    }

    private func getMockRequests(ownerID: String) -> [ShareRequest] {
        return getAllMockRequests().filter { $0.ownerID == ownerID }
    }

    private func updateMockRequestStatus(_ id: String, status: ShareRequest.ShareRequestStatus) {
        var all = getAllMockRequests()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx] = ShareRequest(
                id: all[idx].id,
                requestorID: all[idx].requestorID,
                requestorName: all[idx].requestorName,
                ownerID: all[idx].ownerID,
                inviteCode: all[idx].inviteCode,
                status: status,
                createdAt: all[idx].createdAt
            )
        }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: mockRequestsKey)
        }
    }
}
