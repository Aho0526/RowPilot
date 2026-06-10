import Foundation
import CloudKit
import Combine
import SwiftUI
import StoreKit

// MARK: - サブスクリプションレコード

/// App Store から受け取るサブスクリプション情報
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
    
    // MARK: - StoreKit2 Properties
    @Published var products: [Product] = []
    @Published var isPurchasing = false

    private let productIds = [
        "rowpilot_pro",
        "rowpilot_manager",
        "rowpilot_team",
        "rowpilot_max",
        "rowpilot_org"
    ]

    private var updatesTask: Task<Void, Never>? = nil

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
        print("StoreKit: StoreKit初期化開始")
        print("StoreKit: Product ID一覧: \(productIds)")
        
        fetchMyUserRecordID()
        refreshPublishedState()

        // StoreKit 2 トランザクション監視の開始
        startTransactionListener()

        // 起動時に最新の契約状態を同期＆商品情報を取得
        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }

        // 定期チェック：期限切れ検出 → Freeへ自動移行
        statusTimer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkSubscriptionStatus()
            }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - StoreKit 2 Logic

    func startTransactionListener() {
        updatesTask = Task {
            for await update in Transaction.updates {
                do {
                    let transaction = try checkVerified(update)
                    await updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction verification error: \(error)")
                }
            }
        }
    }

    func loadProducts() async {
        print("StoreKit: Product.products(for:) 呼び出し前 (IDリスト: \(productIds))")
        do {
            let fetchedProducts = try await Product.products(for: productIds)
            print("StoreKit: Product.products(for:) 呼び出し後")
            print("StoreKit: 取得件数: \(fetchedProducts.count)")
            for product in fetchedProducts {
                print("StoreKit: 取得商品 - ID: \(product.id), 名称: \(product.displayName), 価格: \(product.displayPrice)")
            }

            await MainActor.run {
                // SubscriptionPlan のレベル順にソートして保持
                self.products = fetchedProducts.sorted { p1, p2 in
                    let l1 = self.plan(for: p1.id)?.level ?? 0
                    let l2 = self.plan(for: p2.id)?.level ?? 0
                    return l1 < l2
                }
            }
        } catch {
            print("StoreKit: 商品取得失敗エラー: \(error.localizedDescription) (詳細: \(error))")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        await MainActor.run { self.isPurchasing = true }
        defer {
            Task { @MainActor in self.isPurchasing = false }
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true
        case .pending:
            return false
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("StoreKit: Failed to sync App Store: \(error)")
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func plan(for productId: String) -> SubscriptionPlan? {
        switch productId {
        case "rowpilot_pro": return .pro
        case "rowpilot_manager": return .manager
        case "rowpilot_team": return .team
        case "rowpilot_max": return .max
        case "rowpilot_org": return .organization
        default: return nil
        }
    }

    func updateSubscriptionStatus() async {
        var highestPlan: SubscriptionPlan = .free
        var latestExpirationDate: Date? = nil
        var activeProductId: String? = nil
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if let expirationDate = transaction.expirationDate {
                if expirationDate < Date() {
                    continue // 期限切れ
                }
            }

            if let plan = plan(for: transaction.productID) {
                if plan.level > highestPlan.level {
                    highestPlan = plan
                    latestExpirationDate = transaction.expirationDate
                    activeProductId = transaction.productID
                    hasActiveSubscription = true
                }
            }
        }

        let planToApply = highestPlan
        let expiration = latestExpirationDate
        let prodId = activeProductId

        await MainActor.run {
            self.currentPlan = planToApply
            self.expiresAt = expiration
            self.autoRenew = hasActiveSubscription

            let record = SubscriptionRecord(
                subscriptionTier: planToApply,
                autoRenew: hasActiveSubscription,
                expiresAtMs: expiration.map { Int64($0.timeIntervalSince1970 * 1000) },
                productId: prodId
            )
            self.savedRecord = record
            self.refreshPublishedState()

            if planToApply == .team || planToApply == .max || planToApply == .organization {
                self.uploadShareRecord()
            } else {
                self.deleteShareRecord()
            }
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

    // MARK: - 購入（互換性のために残す、内部からは呼ばれない）

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

        if plan == .team || plan == .max || plan == .organization {
            uploadShareRecord()
        } else {
            deleteShareRecord()
        }
    }


    /// 解約処理：autoRenew を false にする。有効期限まではプラン継続。
    func cancelSubscription() {
        var record = savedRecord
        record.autoRenew = false
        savedRecord = record
        refreshPublishedState()

        print("Subscription cancelled. Active until: \(record.expiresAt?.description ?? "nil")")

        if currentPlan == .team || currentPlan == .max || currentPlan == .organization {
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
                if self?.currentPlan == .team || self?.currentPlan == .max || self?.currentPlan == .organization {
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
        if self.currentPlan == .team || self.currentPlan == .max || self.currentPlan == .organization {
            self.loadSharedMembers()
        }
    }

    // MARK: - 共有上限

    var shareLimit: Int {
        switch currentPlan {
        case .team: return 3
        case .max:  return 5
        case .organization: return 10
        case .enterprise: return 9999
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
