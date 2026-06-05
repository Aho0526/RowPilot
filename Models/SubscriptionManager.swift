import Foundation
import CloudKit
import Combine
import SwiftUI

/// サブスクリプション契約状態およびTeam/MAXの共有機能を管理するマネージャークラス
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // CloudKitを使用するかどうかの制御フラグ（iCloud Entitlementが設定されるまではfalseにしておきます）
    // 利用可能にする際はここを true に変更してください。
    let useCloudKit = false
    
    // AppStorageの代わりに、ゲッターセッターでUserDefaultsを操作する
    var currentPlan: SubscriptionPlan {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "userSubscriptionPlan"),
               let plan = SubscriptionPlan(rawValue: rawValue) {
                return plan
            }
            return .free
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "userSubscriptionPlan")
            objectWillChange.send()
        }
    }
    
    var isAutoRenew: Bool {
        get {
            return UserDefaults.standard.object(forKey: "subscriptionIsAutoRenew") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "subscriptionIsAutoRenew")
            objectWillChange.send()
        }
    }
    
    var expirationDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "subscriptionExpirationDate")
            objectWillChange.send()
        }
    }
    
    var isSharedManagerPlan: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "isSharedManagerPlan")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isSharedManagerPlan")
            objectWillChange.send()
        }
    }
    
    var sharedFromOwnerId: String? {
        get {
            return UserDefaults.standard.string(forKey: "sharedFromOwnerId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sharedFromOwnerId")
            objectWillChange.send()
        }
    }
    
    @Published var sharedMembers: [String] = []
    /// sharedMembersのID -> 表示名マッピング
    @Published var sharedMemberNames: [String: String] = [:]
    /// 承認待ちリクエスト（ShareRequestManagerと連携）
    @Published var pendingRequests: [ShareRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // 自身のユーザー識別子
    @Published var myUserRecordId: String = ""
    
    // CloudKit Database (useCloudKit が true の場合のみ安全に初期化)
    private var database: CKDatabase? {
        guard useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }
    
    // シミュレータなどでCloudKitが使えない場合や無効化時のローカルシミュレーション用DB (UserDefaultsに保存)
    private let mockDbKey = "RowPilot_MockCloudKit_SubscriptionShares"
    
    init() {
        fetchMyUserRecordID()
        checkSubscriptionStatus()
    }
    
    /// サブスクリプション状態の点検（期限切れや自動更新処理）
    func checkSubscriptionStatus() {
        let now = Date()
        
        // 1. 個人で加入しているプランのチェック
        if let expDate = expirationDate {
            if now > expDate {
                if isAutoRenew {
                    // 自動更新：有効期限を1ヶ月延長
                    let calendar = Calendar.current
                    expirationDate = calendar.date(byAdding: .month, value: 1, to: expDate)
                    print("Subscription auto-renewed. New expiration: \(String(describing: expirationDate))")
                    
                    // 共有レコード更新
                    if currentPlan == .team || currentPlan == .max {
                        uploadShareRecord()
                    }
                } else {
                    // 自動更新がオフかつ期限切れ：Freeへ自動移行
                    currentPlan = .free
                    expirationDate = nil
                    isSharedManagerPlan = false
                    sharedFromOwnerId = nil
                    print("Subscription expired. Downgraded to Free.")
                    
                    // 共有レコード削除
                    deleteShareRecord()
                }
            }
        }
        
        // 2. 共有されて使用しているManagerプランのチェック
        if isSharedManagerPlan {
            syncSharedPlan()
        }
    }
    
    /// サブスクプランの購入（月額）
    func purchasePlan(_ plan: SubscriptionPlan) {
        currentPlan = plan
        isAutoRenew = true
        
        // 1ヶ月の有効期限を設定
        let calendar = Calendar.current
        expirationDate = calendar.date(byAdding: .month, value: 1, to: Date())
        
        isSharedManagerPlan = false
        sharedFromOwnerId = nil
        
        print("Purchased plan: \(plan.displayName), Expiration: \(String(describing: expirationDate))")
        
        // 共有レコード更新
        if plan == .team || plan == .max {
            uploadShareRecord()
        } else {
            deleteShareRecord()
        }
    }
    
    /// サブスクプランのキャンセル（自動更新の停止）
    func cancelSubscription() {
        isAutoRenew = false
        print("Cancelled auto-renew. Plan remains active until: \(String(describing: expirationDate))")
        
        if currentPlan == .team || currentPlan == .max {
            uploadShareRecord()
        }
    }
    
    /// 自分のユーザー識別子（CloudKitのRecordIDまたはローカルID）を取得
    func fetchMyUserRecordID() {
        guard useCloudKit else {
            // CloudKit無効時はローカルの永続UUIDを使用
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
                
                // 自分がTeam/MAXなら、すでに共有しているメンバーを取得
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
    
    // プランに応じた共有上限
    var shareLimit: Int {
        switch currentPlan {
        case .team: return 3
        case .max: return 5
        default: return 0
        }
    }
    
    // MARK: - Core Sharing Logic
    
    /// 共有レコードをアップロード
    func uploadShareRecord() {
        guard !myUserRecordId.isEmpty else { return }
        
        // 常にローカルモックDBに最新状態を書き込み
        saveToMockDatabase(
            ownerId: myUserRecordId,
            plan: currentPlan.rawValue,
            isAutoRenew: isAutoRenew,
            expirationDate: expirationDate ?? Date().addingTimeInterval(3600*24*30),
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
            
            // 明示的な CKRecordValue キャストを排除 (Swiftが自動的にブリッジします)
            recordToSave["ownerId"] = self.myUserRecordId
            recordToSave["plan"] = self.currentPlan.rawValue
            recordToSave["isAutoRenew"] = (self.isAutoRenew ? 1 : 0)
            if let expDate = self.expirationDate {
                recordToSave["expirationDate"] = expDate
            }
            recordToSave["sharedMembers"] = self.sharedMembers
            
            db.save(recordToSave) { _, saveError in
                if let saveError = saveError {
                    print("CloudKit save warning (using local fallback): \(saveError.localizedDescription)")
                } else {
                    print("CloudKit: SubscriptionShare successfully uploaded.")
                }
            }
        }
    }
    
    /// 共有レコードを削除
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
                print("CloudKit delete warning (using local fallback): \(error.localizedDescription)")
            } else {
                print("CloudKit: SubscriptionShare successfully deleted.")
            }
        }
    }
    
    /// 共有メンバーのロード
    func loadSharedMembers() {
        guard !myUserRecordId.isEmpty else { return }
        
        isLoading = true
        
        guard useCloudKit, let db = database else {
            // iCloud無効時は常にローカルモックDBからロード
            DispatchQueue.main.async {
                self.isLoading = false
                if let mockRecord = self.getFromMockDatabase(ownerId: self.myUserRecordId) {
                    self.sharedMembers = mockRecord.sharedMembers
                    print("Local: Shared members loaded: \(self.sharedMembers)")
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
                    print("CloudKit: Shared members loaded: \(self?.sharedMembers ?? [])")
                } else {
                    if let mockRecord = self?.getFromMockDatabase(ownerId: self?.myUserRecordId ?? "") {
                        self?.sharedMembers = mockRecord.sharedMembers
                        print("Local Fallback: Shared members loaded: \(self?.sharedMembers ?? [])")
                    } else {
                        self?.sharedMembers = []
                        self?.uploadShareRecord()
                    }
                }
            }
        }
    }
    
    /// 共有メンバーの追加 (個人プラン加入者への追加制限含む)
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
            // iCloud無効時はローカルモックDBから直接検証して追加
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
        
        // CloudKitから重複課金チェック
        let predicate = NSPredicate(format: "ownerId == %@", targetId)
        let query = CKQuery(recordType: "SubscriptionShare", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var hasActivePlan = false
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                let planRaw = record["plan"] as? String ?? "free"
                if planRaw != "free" {
                    hasActivePlan = true
                }
            }
        }
        
        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if case .failure = result {
                    if let mockRecord = self.getFromMockDatabase(ownerId: targetId) {
                        if mockRecord.plan != "free" {
                            hasActivePlan = true
                        }
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
    
    /// 共有メンバーの削除
    func removeMember(at offsets: IndexSet) {
        sharedMembers.remove(atOffsets: offsets)
        uploadShareRecord()
    }
    
    /// 共有されたManagerプランの同期確認 (自分がFreeかつ誰かに共有されているかを確認)
    func syncSharedPlan() {
        guard !myUserRecordId.isEmpty else { return }
        
        isLoading = true
        
        guard useCloudKit, let db = database else {
            // iCloud無効時は常にローカルモックDBから検索
            DispatchQueue.main.async {
                self.isLoading = false
                if let mockShare = self.findMockShareContaining(userId: self.myUserRecordId) {
                    self.processSharedRecord(
                        ownerId: mockShare.ownerId,
                        planRaw: mockShare.plan,
                        isOwnerAutoRenew: mockShare.isAutoRenew,
                        ownerExpDate: mockShare.expirationDate
                    )
                } else {
                    if self.isSharedManagerPlan {
                        self.downgradeSharedUser()
                    }
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
                    let ownerId = record["ownerId"] as? String ?? ""
                    let planRaw = record["plan"] as? String ?? "free"
                    let isOwnerAutoRenew = (record["isAutoRenew"] as? Int ?? 1) == 1
                    let ownerExpDate = record["expirationDate"] as? Date
                    
                    self.processSharedRecord(
                        ownerId: ownerId,
                        planRaw: planRaw,
                        isOwnerAutoRenew: isOwnerAutoRenew,
                        ownerExpDate: ownerExpDate
                    )
                } else {
                    // CloudKitで検索できなかった場合、ローカルモックDBから検索
                    if let mockShare = self.findMockShareContaining(userId: self.myUserRecordId) {
                        self.processSharedRecord(
                            ownerId: mockShare.ownerId,
                            planRaw: mockShare.plan,
                            isOwnerAutoRenew: mockShare.isAutoRenew,
                            ownerExpDate: mockShare.expirationDate
                        )
                    } else {
                        if self.isSharedManagerPlan {
                            self.downgradeSharedUser()
                        }
                    }
                }
            }
        }
        
        db.add(operation)
    }
    
    private func processSharedRecord(ownerId: String, planRaw: String, isOwnerAutoRenew: Bool, ownerExpDate: Date?) {
        if planRaw != "free" {
            let now = Date()
            let isExpired = ownerExpDate != nil && now > ownerExpDate!
            
            // 共有元のユーザーが自動更新をオフにして有効期限が切れた場合（＝翌月）、または元々期限切れの場合
            if isExpired || (!isOwnerAutoRenew && ownerExpDate != nil && now > ownerExpDate!) {
                self.downgradeSharedUser()
            } else {
                // 共有が有効：ManagerPlanを適用
                self.isSharedManagerPlan = true
                self.sharedFromOwnerId = ownerId
                self.expirationDate = ownerExpDate
                self.currentPlan = .manager
                print("Sync Shared Plan: ACTIVE from owner \(ownerId). synced expiration date.")
            }
        } else {
            if self.isSharedManagerPlan {
                self.downgradeSharedUser()
            }
        }
    }
    
    private func downgradeSharedUser() {
        self.isSharedManagerPlan = false
        self.sharedFromOwnerId = nil
        self.expirationDate = nil
        if self.currentPlan == .manager {
            self.currentPlan = .free
        }
        print("Sync Shared Plan: Shared plan ended.")
    }
    
    // MARK: - Mock Database Helpers (UserDefaults based)
    
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
