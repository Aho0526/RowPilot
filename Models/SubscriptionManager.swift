import Foundation
import CloudKit
import Combine
import SwiftUI

// MARK: - サブスクリプションレコード

/// App Store / RevenueCat から受け取るサブスクリプション情報
struct SubscriptionRecord: Codable {
    var subscriptionTier: SubscriptionPlan
    var autoRenew: Bool
    /// App Store が返す有効期限（ミリ秒 Unix タイムスタンプ）
    var expiresAtMs: Int64?
    /// 購入した商品ID
    var productId: String?

    var expiresAt: Date? {
        guard let ms = expiresAtMs else { return nil }
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    /// 現在有効かどうか（現在時刻 < expiresAt）
    var isActive: Bool {
        guard subscriptionTier != .free else { return true }
        guard let exp = expiresAt else { return false }
        return Date() < exp
    }

    /// 有効なプランを返す（期限切れなら .free）
    var effectivePlan: SubscriptionPlan {
        guard subscriptionTier != .free else { return .free }
        if isActive {
            return subscriptionTier
        } else {
            return .free
        }
    }
}

// MARK: - SubscriptionManager

/// サブスクリプション状態を管理するマネージャー
/// - App Store / RevenueCat の情報を正として expiresAt を保存
/// - 独自の期限延長・独自計算は行わない
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // CloudKitを使用するかどうかの制御フラグ
    let useCloudKit = false

    // MARK: - Persisted State（UserDefaults）

    private let recordKey = "RowPilot_SubscriptionRecord"

    /// 保存されている生のサブスクリプションレコード
    private var savedRecord: SubscriptionRecord {
        get {
            guard let data = UserDefaults.standard.data(forKey: recordKey),
                  let record = try? JSONDecoder().decode(SubscriptionRecord.self, from: data) else {
                return SubscriptionRecord(subscriptionTier: .free, autoRenew: false, expiresAtMs: nil, productId: nil)
            }
            return record
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: recordKey)
            }
        }
    }

    // MARK: - Published State

    /// 現在の有効プラン（期限切れなら .free）
    @Published var currentPlan: SubscriptionPlan = .free
    /// 自動更新が有効かどうか
    @Published var autoRenew: Bool = false
    /// 有効期限（App Store の値）
    @Published var expiresAt: Date? = nil

    // 旧APIの互換エイリアス
    var isAutoRenew: Bool { autoRenew }
    var expirationDate: Date? { expiresAt }

    // MARK: - Sharing State（Team/MAX）

    @Published var sharedMembers: [String] = []
    @Published var sharedMemberNames: [String: String] = [:]
    @Published var pendingRequests: [ShareRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var myUserRecordId: String = ""

    // 共有プラン受信（将来のCloudKit共有機能用）
    var isSharedManagerPlan: Bool {
        get { UserDefaults.standard.bool(forKey: "isSharedManagerPlan") }
        set {
            UserDefaults.standard.set(newValue, forKey: "isSharedManagerPlan")
            objectWillChange.send()
        }
    }

    var sharedFromOwnerId: String? {
        get { UserDefaults.standard.string(forKey: "sharedFromOwnerId") }
        set {
            UserDefaults.standard.set(newValue, forKey: "sharedFromOwnerId")
            objectWillChange.send()
        }
    }

    // MARK: - CloudKit

    private var database: CKDatabase? {
        guard useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }

    private let mockDbKey = "RowPilot_MockCloudKit_SubscriptionShares"

    // MARK: - Timer

    private var statusTimer: AnyCancellable?

    // MARK: - Init

    init() {
        fetchMyUserRecordID()
        refreshPublishedState()

        // 定期チェック：期限切れ検出 → Freeへ自動移行
        statusTimer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkSubscriptionStatus()
            }
    }

    // MARK: - Core: 公開状態を保存レコードから同期

    private func refreshPublishedState() {
        let record = savedRecord
        let effective = record.effectivePlan

        currentPlan = effective
        autoRenew   = effective == .free ? false : record.autoRenew
        expiresAt   = effective == .free ? nil   : record.expiresAt

        // 全ビューの @AppStorage("userSubscriptionPlan") と互换性のあるキーにも同期書き込み
        UserDefaults.standard.set(effective.rawValue, forKey: "userSubscriptionPlan")

        // 期限切れで降格した場合はレコードも更新
        if effective == .free && record.subscriptionTier != .free {
            var updated = record
            updated.subscriptionTier = .free
            updated.autoRenew = false
            savedRecord = updated
            print("Subscription expired. Downgraded to Free.")
        }
    }

    // MARK: - 定期チェック

    func checkSubscriptionStatus() {
        refreshPublishedState()

        if isSharedManagerPlan {
            syncSharedPlan()
        }
    }

    // MARK: - 購入（App Store / RevenueCat から呼び出す）

    /// App Store または RevenueCat の情報を受け取って保存する
    /// - Parameters:
    ///   - plan: 購入したプラン
    ///   - expiresAtMs: App Store が返す有効期限（ミリ秒 Unix タイムスタンプ）
    ///   - productId: 購入した商品ID
    func applyPurchase(plan: SubscriptionPlan, expiresAtMs: Int64, productId: String?) {
        let record = SubscriptionRecord(
            subscriptionTier: plan,
            autoRenew: true,
            expiresAtMs: expiresAtMs,
            productId: productId
        )
        savedRecord = record
        refreshPublishedState()

        print("Purchase applied: \(plan.displayName), expires: \(record.expiresAt?.description ?? "nil")")

        if plan == .team || plan == .max {
            uploadShareRecord()
        } else {
            deleteShareRecord()
        }
    }

    /// デバッグ・テスト用：1ヶ月後の期限で購入を適用する
    func purchasePlan(_ plan: SubscriptionPlan) {
        guard plan != .free else {
            cancelAndExpireNow()
            return
        }

        let oneMonthFromNow = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let ms = Int64(oneMonthFromNow.timeIntervalSince1970 * 1000)
        applyPurchase(plan: plan, expiresAtMs: ms, productId: "debug_\(plan.rawValue)_monthly")

        isSharedManagerPlan = false
        sharedFromOwnerId = nil
    }

    // MARK: - 自動更新の更新（App Store 課金成功時）

    /// 自動更新成功時に新しい有効期限を保存する
    func applyRenewal(newExpiresAtMs: Int64) {
        var record = savedRecord
        record.expiresAtMs = newExpiresAtMs
        record.autoRenew = true
        savedRecord = record
        refreshPublishedState()
        print("Subscription renewed. New expiration: \(record.expiresAt?.description ?? "nil")")
    }

    // MARK: - 解約（自動更新を停止）

    /// 解約処理：autoRenew を false にする。有効期限まではプラン継続。
    func cancelSubscription() {
        var record = savedRecord
        record.autoRenew = false
        savedRecord = record
        refreshPublishedState()

        print("Subscription cancelled. Active until: \(record.expiresAt?.description ?? "nil")")

        if currentPlan == .team || currentPlan == .max {
            uploadShareRecord()
        }
    }

    /// 即時失効（テスト用）
    private func cancelAndExpireNow() {
        savedRecord = SubscriptionRecord(subscriptionTier: .free, autoRenew: false, expiresAtMs: nil, productId: nil)
        refreshPublishedState()
        deleteShareRecord()
    }

    // MARK: - ユーザーID

    func fetchMyUserRecordID() {
        guard useCloudKit else {
            loadOrCreateLocalUserRecordId()
            return
        }

        CKContainer.default().fetchUserRecordID { [weak self] recordID, error in
            DispatchQueue.main.async {
                if let recordID = recordID {
                    self?.myUserRecordId = recordID.recordName
                } else {
                    self?.loadOrCreateLocalUserRecordId()
                }
                print("My User Record ID: \(self?.myUserRecordId ?? "")")
                if self?.currentPlan == .team || self?.currentPlan == .max {
                    self?.loadSharedMembers()
                }
            }
        }
    }

    private func loadOrCreateLocalUserRecordId() {
        if let savedId = UserDefaults.standard.string(forKey: "RowPilot_LocalUserRecordId") {
            self.myUserRecordId = savedId
        } else {
            let newId = "User_" + UUID().uuidString.prefix(8)
            UserDefaults.standard.set(newId, forKey: "RowPilot_LocalUserRecordId")
            self.myUserRecordId = newId
        }
        print("My Local User Record ID: \(self.myUserRecordId)")
        if self.currentPlan == .team || self.currentPlan == .max {
            self.loadSharedMembers()
        }
    }

    // MARK: - 共有上限

    var shareLimit: Int {
        switch currentPlan {
        case .team: return 3
        case .max:  return 5
        default:    return 0
        }
    }

    // MARK: - Core Sharing Logic

    func uploadShareRecord() {
        guard !myUserRecordId.isEmpty else { return }

        saveToMockDatabase(
            ownerId: myUserRecordId,
            plan: currentPlan.rawValue,
            isAutoRenew: autoRenew,
            expirationDate: expiresAt ?? Date().addingTimeInterval(3600 * 24 * 30),
            sharedMembers: sharedMembers
        )

        guard useCloudKit, let db = database else {
            print("Local: SubscriptionShare updated successfully (iCloud Disabled).")
            return
        }

        let recordIDName = "Share_\(myUserRecordId)"
        let recordID = CKRecord.ID(recordName: recordIDName)

        db.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            let recordToSave: CKRecord

            if let fetchedRecord = record {
                recordToSave = fetchedRecord
            } else {
                recordToSave = CKRecord(recordType: "SubscriptionShare", recordID: recordID)
            }

            recordToSave["ownerId"]       = self.myUserRecordId
            recordToSave["plan"]          = self.currentPlan.rawValue
            recordToSave["isAutoRenew"]   = (self.autoRenew ? 1 : 0)
            if let expDate = self.expiresAt {
                recordToSave["expirationDate"] = expDate
            }
            recordToSave["sharedMembers"] = self.sharedMembers

            db.save(recordToSave) { _, saveError in
                if let saveError = saveError {
                    print("CloudKit save warning: \(saveError.localizedDescription)")
                } else {
                    print("CloudKit: SubscriptionShare successfully uploaded.")
                }
            }
        }
    }

    func deleteShareRecord() {
        guard !myUserRecordId.isEmpty else { return }

        removeFromMockDatabase(ownerId: myUserRecordId)

        guard useCloudKit, let db = database else {
            print("Local: SubscriptionShare successfully deleted (iCloud Disabled).")
            return
        }

        let recordIDName = "Share_\(myUserRecordId)"
        let recordID = CKRecord.ID(recordName: recordIDName)

        db.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("CloudKit delete warning: \(error.localizedDescription)")
            } else {
                print("CloudKit: SubscriptionShare successfully deleted.")
            }
        }
    }

    func loadSharedMembers() {
        guard !myUserRecordId.isEmpty else { return }

        isLoading = true

        guard useCloudKit, let db = database else {
            DispatchQueue.main.async {
                self.isLoading = false
                if let mockRecord = self.getFromMockDatabase(ownerId: self.myUserRecordId) {
                    self.sharedMembers = mockRecord.sharedMembers
                } else {
                    self.sharedMembers = []
                    self.uploadShareRecord()
                }
            }
            return
        }

        let recordIDName = "Share_\(myUserRecordId)"
        let recordID = CKRecord.ID(recordName: recordIDName)

        db.fetch(withRecordID: recordID) { [weak self] record, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let record = record {
                    self?.sharedMembers = record["sharedMembers"] as? [String] ?? []
                } else {
                    if let mockRecord = self?.getFromMockDatabase(ownerId: self?.myUserRecordId ?? "") {
                        self?.sharedMembers = mockRecord.sharedMembers
                    } else {
                        self?.sharedMembers = []
                        self?.uploadShareRecord()
                    }
                }
            }
        }
    }

    func addMember(_ memberEmailOrId: String, completion: @escaping (Bool, String?) -> Void) {
        let targetId = memberEmailOrId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetId.isEmpty else {
            completion(false, "ユーザーIDまたはメールアドレスを入力してください。")
            return
        }

        if sharedMembers.count >= shareLimit {
            completion(false, "共有枠の上限（最大 \(shareLimit) 名）に達しています。")
            return
        }

        if sharedMembers.contains(targetId) {
            completion(false, "既に共有されているメンバーです。")
            return
        }

        if targetId == myUserRecordId {
            completion(false, "自分自身を共有メンバーに追加することはできません。")
            return
        }

        isLoading = true

        guard useCloudKit, let db = database else {
            DispatchQueue.main.async {
                self.isLoading = false
                var hasActivePlan = false
                if let mockRecord = self.getFromMockDatabase(ownerId: targetId) {
                    if mockRecord.plan != "free" {
                        hasActivePlan = true
                    }
                }

                if hasActivePlan {
                    completion(false, "このユーザーは既に個人で有料プランに加入しているため、共有できません。")
                } else {
                    self.sharedMembers.append(targetId)
                    self.uploadShareRecord()
                    completion(true, nil)
                }
            }
            return
        }

        let predicate = NSPredicate(format: "ownerId == %@", targetId)
        let query = CKQuery(recordType: "SubscriptionShare", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var hasActivePlan = false

        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                let planRaw = record["plan"] as? String ?? "free"
                if planRaw != "free" { hasActivePlan = true }
            }
        }

        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if case .failure = result {
                    if let mockRecord = self.getFromMockDatabase(ownerId: targetId) {
                        if mockRecord.plan != "free" { hasActivePlan = true }
                    }
                }

                if hasActivePlan {
                    completion(false, "このユーザーは既に個人で有料プランに加入しているため、共有できません。")
                } else {
                    self.sharedMembers.append(targetId)
                    self.uploadShareRecord()
                    completion(true, nil)
                }
            }
        }

        db.add(operation)
    }

    func removeMember(at offsets: IndexSet) {
        sharedMembers.remove(atOffsets: offsets)
        uploadShareRecord()
    }

    // MARK: - 共有プラン同期

    func syncSharedPlan() {
        guard !myUserRecordId.isEmpty else { return }

        isLoading = true

        guard useCloudKit, let db = database else {
            DispatchQueue.main.async {
                self.isLoading = false
                if let mockShare = self.findMockShareContaining(userId: self.myUserRecordId) {
                    self.processSharedRecord(
                        ownerId: mockShare.ownerId,
                        planRaw: mockShare.plan,
                        isOwnerAutoRenew: mockShare.isAutoRenew,
                        ownerExpDate: mockShare.expirationDate
                    )
                } else if self.isSharedManagerPlan {
                    self.downgradeSharedUser()
                }
            }
            return
        }

        let predicate = NSPredicate(format: "sharedMembers CONTAINS %@", myUserRecordId)
        let query = CKQuery(recordType: "SubscriptionShare", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var foundRecord: CKRecord? = nil

        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                foundRecord = record
            }
        }

        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let record = foundRecord {
                    let ownerId         = record["ownerId"] as? String ?? ""
                    let planRaw         = record["plan"] as? String ?? "free"
                    let isOwnerAutoRenew = (record["isAutoRenew"] as? Int ?? 1) == 1
                    let ownerExpDate    = record["expirationDate"] as? Date
                    self.processSharedRecord(ownerId: ownerId, planRaw: planRaw,
                                            isOwnerAutoRenew: isOwnerAutoRenew, ownerExpDate: ownerExpDate)
                } else if let mockShare = self.findMockShareContaining(userId: self.myUserRecordId) {
                    self.processSharedRecord(ownerId: mockShare.ownerId, planRaw: mockShare.plan,
                                            isOwnerAutoRenew: mockShare.isAutoRenew, ownerExpDate: mockShare.expirationDate)
                } else if self.isSharedManagerPlan {
                    self.downgradeSharedUser()
                }
            }
        }

        db.add(operation)
    }

    private func processSharedRecord(ownerId: String, planRaw: String, isOwnerAutoRenew: Bool, ownerExpDate: Date?) {
        guard planRaw != "free" else {
            if isSharedManagerPlan { downgradeSharedUser() }
            return
        }

        let now = Date()
        let isExpired = ownerExpDate != nil && now >= ownerExpDate!

        if isExpired {
            downgradeSharedUser()
        } else {
            isSharedManagerPlan = true
            sharedFromOwnerId = ownerId
            // 共有プランの期限は所有者に合わせる
            var record = savedRecord
            record.subscriptionTier = .team  // 共有は Team 相当
            record.expiresAtMs = ownerExpDate.map { Int64($0.timeIntervalSince1970 * 1000) }
            savedRecord = record
            refreshPublishedState()
            print("Sync Shared Plan: ACTIVE from owner \(ownerId).")
        }
    }

    private func downgradeSharedUser() {
        isSharedManagerPlan = false
        sharedFromOwnerId = nil
        savedRecord = SubscriptionRecord(subscriptionTier: .free, autoRenew: false, expiresAtMs: nil, productId: nil)
        refreshPublishedState()
        print("Sync Shared Plan: Shared plan ended.")
    }

    // MARK: - Mock Database Helpers

    struct MockShareRecord: Codable {
        let ownerId: String
        let plan: String
        let isAutoRenew: Bool
        let expirationDate: Date
        let sharedMembers: [String]
        var sharedMemberNames: [String: String]
    }

    private func getMockDatabase() -> [String: MockShareRecord] {
        guard let data = UserDefaults.standard.data(forKey: mockDbKey),
              let db = try? JSONDecoder().decode([String: MockShareRecord].self, from: data) else {
            return [:]
        }
        return db
    }

    private func saveMockDatabase(_ db: [String: MockShareRecord]) {
        if let data = try? JSONEncoder().encode(db) {
            UserDefaults.standard.set(data, forKey: mockDbKey)
        }
    }

    private func saveToMockDatabase(ownerId: String, plan: String, isAutoRenew: Bool, expirationDate: Date, sharedMembers: [String]) {
        var db = getMockDatabase()
        db[ownerId] = MockShareRecord(
            ownerId: ownerId,
            plan: plan,
            isAutoRenew: isAutoRenew,
            expirationDate: expirationDate,
            sharedMembers: sharedMembers,
            sharedMemberNames: self.sharedMemberNames
        )
        saveMockDatabase(db)
    }

    private func removeFromMockDatabase(ownerId: String) {
        var db = getMockDatabase()
        db.removeValue(forKey: ownerId)
        saveMockDatabase(db)
    }

    private func getFromMockDatabase(ownerId: String) -> MockShareRecord? {
        return getMockDatabase()[ownerId]
    }

    private func findMockShareContaining(userId: String) -> MockShareRecord? {
        let db = getMockDatabase()
        return db.values.first { $0.sharedMembers.contains(userId) }
    }
}
