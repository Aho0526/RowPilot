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
class SubscriptionManager: ObservableObject, @unchecked Sendable {
    static let shared = SubscriptionManager()

    // CloudKitの旧SubscriptionShare共有は無効化（D1側で一元管理）
    let useCloudKit = false

    // MARK: - Persisted State（UserDefaults）

    private let recordKey = "RowPilot_SubscriptionRecord"
    private let stableUserIdKey = "RowPilot_StableUserId"
    private let deviceSecretKey = "RowPilot_DeviceSecret"

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

    /// 現在の有効プラン（個人契約＋チーム共有プラン統合後の実効値）
    @Published var currentPlan: SubscriptionPlan = .free
    /// 個人でStoreKitから契約しているプラン（チーム作成権限等の判定に使用）
    @Published var ownPlan: SubscriptionPlan = .free
    /// 自動更新が有効かどうか
    @Published var autoRenew: Bool = false
    /// 有効期限（App Store の値）
    @Published var expiresAt: Date? = nil
    /// 端末認証エラーメッセージ（別端末で同一IDが使われている場合等）
    @Published var authErrorMessage: String? = nil

    /// 次の更新期間から適用される予定のプラン（ダウングレード等）
    @Published var pendingPlan: SubscriptionPlan? = nil
    /// pendingPlan が適用される日（現在の期間終了日）
    @Published var pendingPlanDate: Date? = nil

    // MARK: - StoreKit2 Properties
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var isLoadingProducts = false
    @Published var productsLoadError: String? = nil

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

    // Cloudflare D1側でManager/Adminロールから付与されるチーム共有プラン
    var cloudflareSharedPlan: SubscriptionPlan? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "cloudflareSharedPlanRaw") else { return nil }
            return SubscriptionPlan(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: "cloudflareSharedPlanRaw")
            objectWillChange.send()
        }
    }

    var isSharedTeamBenefitActive: Bool {
        if isSharedManagerPlan { return true }
        guard let shared = cloudflareSharedPlan else { return false }
        return shared.level > ownPlan.level
    }

    // Cloudflare D1側でManagerロールに任命されているか（後方互換維持）
    var isCloudflareManager: Bool {
        get { UserDefaults.standard.bool(forKey: "isCloudflareManager") }
        set {
            UserDefaults.standard.set(newValue, forKey: "isCloudflareManager")
            objectWillChange.send()
        }
    }

    func setCloudflareManager(_ isManager: Bool) {
        DispatchQueue.main.async {
            self.isCloudflareManager = isManager
            if !isManager {
                self.cloudflareSharedPlan = nil
            }
            self.refreshPublishedState()
        }
    }

    func setCloudflareTeamRole(role: String?, teamPlan: SubscriptionPlan?, isSuspended: Bool) {
        DispatchQueue.main.async {
            var grantedPlan: SubscriptionPlan? = nil
            if !isSuspended, let role = role {
                if role == "manager" || role == "admin" {
                    if let tPlan = teamPlan {
                        if tPlan.level >= SubscriptionPlan.max.level {
                            grantedPlan = .max
                        } else if tPlan.level >= SubscriptionPlan.team.level {
                            grantedPlan = .manager
                        }
                    } else {
                        grantedPlan = .manager
                    }
                }
            }
            self.cloudflareSharedPlan = grantedPlan
            self.isCloudflareManager = (grantedPlan != nil)
            self.refreshPublishedState()
        }
    }

    var sharedFromOwnerId: String? {
        get { UserDefaults.standard.string(forKey: "sharedFromOwnerId") }
        set {
            UserDefaults.standard.set(newValue, forKey: "sharedFromOwnerId")
            objectWillChange.send()
        }
    }

    var apiToken: String {
        get { UserDefaults.standard.string(forKey: "apiToken") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "apiToken")
            objectWillChange.send()
        }
    }

    var lastVerifiedJWS: String? {
        get { UserDefaults.standard.string(forKey: "lastVerifiedJWS") }
        set { UserDefaults.standard.set(newValue, forKey: "lastVerifiedJWS") }
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
        print("[StoreKit] ✅ StoreKit initialization started")
        print("[StoreKit] Product IDs: \(productIds)")
        
        fetchMyUserRecordID()
        refreshPublishedState()

        // StoreKit 2 トランザクション監視の開始
        startTransactionListener()

        // 起動時に最新の契約状態を同期＆商品情報を取得
        Task {
            print("[StoreKit] Updating subscription status on launch...")
            await updateSubscriptionStatus()
            print("[StoreKit] Loading products on launch...")
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
        print("[StoreKit] Transaction listener started")
        updatesTask = Task {
            for await update in StoreKit.Transaction.updates {
                do {
                    let transaction = try checkVerified(update)
                    print("[StoreKit] Transaction update received: productID=\(transaction.productID)")
                    await updateSubscriptionStatus()
                    await transaction.finish()
                    print("[StoreKit] Transaction finished: productID=\(transaction.productID)")
                } catch {
                    print("[StoreKit] ❌ Transaction verification error: \(error)")
                }
            }
        }
    }

    func loadProducts() async {
        print("[StoreKit] Product request started — IDs: \(productIds)")
        await MainActor.run {
            self.isLoadingProducts = true
            self.productsLoadError = nil
        }

        do {
            let fetchedProducts = try await Product.products(for: productIds)
            print("[StoreKit] Product request completed")
            print("[StoreKit] Products loaded count: \(fetchedProducts.count)")

            if fetchedProducts.isEmpty {
                print("[StoreKit] ⚠️ WARNING: No products returned from App Store. Check product IDs and StoreKit configuration.")
            }

            for product in fetchedProducts {
                print("[StoreKit] ✅ Product loaded — ID: \(product.id), Name: \(product.displayName), Price: \(product.displayPrice)")
            }

            await MainActor.run {
                // SubscriptionPlan のレベル順にソートして保持
                self.products = fetchedProducts.sorted { p1, p2 in
                    let l1 = self.plan(for: p1.id)?.level ?? 0
                    let l2 = self.plan(for: p2.id)?.level ?? 0
                    return l1 < l2
                }
                self.isLoadingProducts = false
                self.productsLoadError = nil
            }
        } catch {
            print("[StoreKit] ❌ Product fetch failed: \(error.localizedDescription)")
            print("[StoreKit] ❌ Error detail: \(error)")
            await MainActor.run {
                self.isLoadingProducts = false
                self.productsLoadError = error.localizedDescription
            }
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        print("[StoreKit] Purchase button tapped — productID: \(product.id), price: \(product.displayPrice)")
        await MainActor.run { self.isPurchasing = true }
        defer {
            Task { @MainActor in self.isPurchasing = false }
        }

        print("[StoreKit] Purchase started — productID: \(product.id)")
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            print("[StoreKit] Purchase result: success — verifying...")
            let transaction = try checkVerified(verification)
            print("[StoreKit] ✅ Purchase completed — productID: \(transaction.productID), transactionID: \(transaction.id)")

            // トランザクションを先にfinishしてから状態を更新
            // （finish後にcurrentEntitlementsが正しく更新される）
            await transaction.finish()
            print("[StoreKit] Transaction finished, now updating subscription status...")

            // アップグレード購入後はcurrentEntitlementsが更新されるまで
            // 少し待機してから再取得する（StoreKit内部処理の完了を待つ）
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            await updateSubscriptionStatus()
            print("[StoreKit] Subscription status updated after purchase")
            return true
        case .pending:
            print("[StoreKit] Purchase result: pending (waiting for parent approval or SCA)")
            return false
        case .userCancelled:
            print("[StoreKit] Purchase result: user cancelled")
            return false
        @unknown default:
            print("[StoreKit] Purchase result: unknown")
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        print("[StoreKit] Restore purchases started")
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("[StoreKit] ✅ Restore purchases completed")
            return true
        } catch {
            print("[StoreKit] ❌ Failed to sync App Store: \(error)")
            return false
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("[StoreKit] ❌ Transaction unverified: \(error)")
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
        print("[StoreKit] Checking current entitlements...")
        var highestPlan: SubscriptionPlan = .free
        var latestExpirationDate: Date? = nil
        var activeProductId: String? = nil
        var hasActiveSubscription = false
        var highestJWS: String? = nil

        // ダウングレード予定の検出用
        var detectedPendingPlan: SubscriptionPlan? = nil
        var detectedPendingDate: Date? = nil

        for await result in StoreKit.Transaction.currentEntitlements {
            let transaction: StoreKit.Transaction
            switch result {
            case .verified(let t):
                transaction = t
            case .unverified(let t, let error):
                #if DEBUG
                print("[StoreKit] ⚠️ Using unverified transaction in DEBUG/Sandbox: \(error)")
                transaction = t
                #else
                print("[StoreKit] Skipping unverified entitlement: \(error)")
                continue
                #endif
            }

            // 失効済み（払い戻し等）はスキップ
            if let revocationDate = transaction.revocationDate {
                print("[StoreKit] Skipping revoked entitlement: \(transaction.productID), revoked: \(revocationDate)")
                continue
            }

            // 有効期限切れはスキップ
            if let expirationDate = transaction.expirationDate {
                if expirationDate < Date() {
                    print("[StoreKit] Skipping expired entitlement: \(transaction.productID), expired: \(expirationDate)")
                    continue
                }
            }

            // isUpgraded = true → このトランザクションは上位プランに置き換えられた（アップグレード済み）
            // 現在は上位プランが有効なので、このエントリは「過去のプラン」として pending 候補にはしない
            if transaction.isUpgraded {
                print("[StoreKit] Skipping upgraded-away entitlement: \(transaction.productID) (replaced by higher plan)")
                continue
            }

            if let plan = plan(for: transaction.productID) {
                print("[StoreKit] Valid entitlement: \(transaction.productID) → \(plan.displayName), expires: \(transaction.expirationDate?.description ?? "none"), isUpgraded: \(transaction.isUpgraded)")
                if plan.level >= highestPlan.level {
                    highestPlan = plan
                    latestExpirationDate = transaction.expirationDate
                    activeProductId = transaction.productID
                    hasActiveSubscription = true
                    highestJWS = result.jwsRepresentation
                }
            }
        }


        // ── プラン変更予定の検出 ──
        // StoreKit2 の正しいアプローチ: Product.SubscriptionInfo.Status の
        // renewalInfo.autoRenewProductID を確認する。
        // これが現在アクティブなプランのIDと異なる場合、次回の更新で別プランが適用される。
        // → アップグレード・ダウングレード両方を検出できる。
        // ※ 同一サブスクグループ内でのアップグレードは StoreKit が即時反映するため、
        //   この pendingPlan 検出は主にダウングレード・クロスグループ変更に有効。
        var detectedWillAutoRenew: Bool? = nil
        if !productIds.isEmpty {
            do {
                let storeProducts = try await Product.products(for: productIds)
                for product in storeProducts {
                    guard let subInfo = product.subscription else { continue }
                    let statuses = try await subInfo.status
                    for status in statuses {
                        let renewalInfo: Product.SubscriptionInfo.RenewalInfo
                        switch status.renewalInfo {
                        case .verified(let r):
                            renewalInfo = r
                        case .unverified(let r, let error):
                            #if DEBUG
                            print("[StoreKit] ⚠️ Using unverified renewalInfo in DEBUG: \(error)")
                            renewalInfo = r
                            #else
                            continue
                            #endif
                        }

                        let txn: StoreKit.Transaction
                        switch status.transaction {
                        case .verified(let t):
                            txn = t
                        case .unverified(let t, let error):
                            #if DEBUG
                            print("[StoreKit] ⚠️ Using unverified transaction in DEBUG: \(error)")
                            txn = t
                            #else
                            continue
                            #endif
                        }

                        // 失効・期限切れは無視
                        guard txn.revocationDate == nil else { continue }
                        if let exp = txn.expirationDate, exp < Date() { continue }

                        let currentProductID = txn.productID
                        if currentProductID == activeProductId {
                            detectedWillAutoRenew = renewalInfo.willAutoRenew
                        }
                        // autoRenewPreference: 次の更新時に適用されるプロダクトID（変更がなければ nil）
                        let autoRenewPreference = renewalInfo.autoRenewPreference

                        // 自動更新がオンで、かつ次回更新プランが現在と異なる場合 → 変更予定あり
                        if renewalInfo.willAutoRenew,
                           let nextID = autoRenewPreference,
                           nextID != currentProductID,
                           let nextPlan = plan(for: nextID) {
                            detectedPendingPlan = nextPlan
                            // 適用日は現在のトランザクションの有効期限（＝次の更新日）
                            detectedPendingDate = txn.expirationDate ?? latestExpirationDate
                            print("[StoreKit] Detected pending plan change: \(currentProductID) → \(nextID) (\(nextPlan.displayName)) at \(detectedPendingDate?.description ?? "unknown")")
                        }
                    }
                }
            } catch {
                print("[StoreKit] ⚠️ Could not fetch subscription status for pending detection: \(error)")
            }
        }

        print("[StoreKit] Effective plan: \(highestPlan.displayName), expires: \(latestExpirationDate?.description ?? "none")")
        if let pp = detectedPendingPlan {
            print("[StoreKit] Pending plan change: → \(pp.displayName) from \(detectedPendingDate?.description ?? "unknown")")
        }

        let planToApply = highestPlan
        let expiration = latestExpirationDate
        let prodId = activeProductId
        let isActive = hasActiveSubscription  // Swift 6対応: 変数をローカルにコピー
        let willAutoRenewValue = isActive ? (detectedWillAutoRenew ?? true) : false
        let pendingPlanValue = detectedPendingPlan
        let pendingDateValue = detectedPendingDate
        let fetchedJWS = highestJWS

        await MainActor.run {
            if let fetchedJWS = fetchedJWS {
                self.lastVerifiedJWS = fetchedJWS
            } else if !isActive {
                self.lastVerifiedJWS = nil
            }
            
            self.ownPlan = planToApply
            self.currentPlan = planToApply
            self.expiresAt = expiration
            self.autoRenew = willAutoRenewValue
            self.pendingPlan = pendingPlanValue
            self.pendingPlanDate = pendingDateValue

            let record = SubscriptionRecord(
                subscriptionTier: planToApply,
                autoRenew: willAutoRenewValue,
                expiresAtMs: expiration.map { Int64($0.timeIntervalSince1970 * 1000) },
                productId: prodId
            )
            self.savedRecord = record
            self.refreshPublishedState()
            
            // JWSの有無にかかわらずトークン取得とD1プラン同期を実行
            let ownerId = self.myUserRecordId
            if !ownerId.isEmpty {
                Task {
                    await self.syncTeamPlanWithCloudflare(ownerId: ownerId, jws: fetchedJWS)
                }
            }
        }
    }

    // MARK: - Core: 公開状態を保存レコードから同期

    private func refreshPublishedState() {
        let record = savedRecord
        let oldOwnPlan = ownPlan
        let personalPlan = record.effectivePlan
        ownPlan = personalPlan

        var effective = personalPlan

        // Cloudflare D1側で付与されたチーム権限（Team→manager, MAX/Org→max）を統合
        if let shared = cloudflareSharedPlan {
            if effective.level < shared.level {
                effective = shared
            }
        } else if isCloudflareManager {
            if effective.level < SubscriptionPlan.manager.level {
                effective = .manager
            }
        }

        currentPlan = effective
        autoRenew   = personalPlan == .free ? false : record.autoRenew
        expiresAt   = personalPlan == .free ? nil   : record.expiresAt

        // 全ビューの @AppStorage("userSubscriptionPlan") と互換性のあるキーにも同期書き込み
        UserDefaults.standard.set(effective.rawValue, forKey: "userSubscriptionPlan")

        // 期限切れで降格した場合はレコードも更新
        if personalPlan == .free && record.subscriptionTier != .free {
            var updated = record
            updated.subscriptionTier = .free
            updated.autoRenew = false
            savedRecord = updated
            print("[StoreKit] Subscription expired. Downgraded to Free.")
        }

        if oldOwnPlan != personalPlan {
            let ownerId = myUserRecordId
            let jws = lastVerifiedJWS
            Task {
                await syncTeamPlanWithCloudflare(ownerId: ownerId, jws: jws)
            }
        }
    }

    // MARK: - 定期チェック

    func checkSubscriptionStatus() {
        refreshPublishedState()
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

        print("[StoreKit] Purchase applied: \(plan.displayName), expires: \(record.expiresAt?.description ?? "nil")")
    }

    func getOrCreateDeviceSecret() -> String {
        if let keychainSecret = KeychainHelper.read(key: deviceSecretKey), keychainSecret.count >= 32 {
            if UserDefaults.standard.string(forKey: deviceSecretKey) != keychainSecret {
                UserDefaults.standard.set(keychainSecret, forKey: deviceSecretKey)
            }
            return keychainSecret
        }
        if let udSecret = UserDefaults.standard.string(forKey: deviceSecretKey), udSecret.count >= 32 {
            KeychainHelper.save(key: deviceSecretKey, value: udSecret)
            return udSecret
        }
        let newSecret = UUID().uuidString + UUID().uuidString
        KeychainHelper.save(key: deviceSecretKey, value: newSecret)
        UserDefaults.standard.set(newSecret, forKey: deviceSecretKey)
        return newSecret
    }

    var isApiTokenExpiredOrMissing: Bool {
        let token = apiToken
        guard !token.isEmpty else { return true }
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return true }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        return Date().timeIntervalSince1970 + 60 >= exp
    }

    @discardableResult
    func ensureValidApiToken() async -> Bool {
        if !isApiTokenExpiredOrMissing {
            return true
        }
        if myUserRecordId.isEmpty {
            await fetchMyUserRecordIDAsync()
        }
        guard !myUserRecordId.isEmpty else { return false }
        return await syncTeamPlanWithCloudflare(ownerId: myUserRecordId, jws: lastVerifiedJWS)
    }

    @discardableResult
    func refreshApiToken() async -> Bool {
        if myUserRecordId.isEmpty {
            await fetchMyUserRecordIDAsync()
        }
        guard !myUserRecordId.isEmpty else { return false }
        return await syncTeamPlanWithCloudflare(ownerId: myUserRecordId, jws: lastVerifiedJWS)
    }

    @discardableResult
    func syncTeamPlanWithCloudflare(ownerId: String, jws: String?) async -> Bool {
        guard !ownerId.isEmpty else { return false }
        
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/auth/verify-receipt"
        let deviceSecret = getOrCreateDeviceSecret()
        
        var body: [String: Any] = [
            "user_id": ownerId,
            "device_secret": deviceSecret
        ]
        if let jws = jws {
            body["jws"] = jws
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("[SubscriptionManager] Verify receipt success")
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let token = json["token"] as? String {
                    await MainActor.run {
                        self.apiToken = token
                        self.authErrorMessage = nil
                        NotificationCenter.default.post(name: NSNotification.Name("D1TeamPlanSynced"), object: nil)
                    }
                    return true
                } else {
                    await MainActor.run {
                        self.authErrorMessage = nil
                        NotificationCenter.default.post(name: NSNotification.Name("D1TeamPlanSynced"), object: nil)
                    }
                    return !self.apiToken.isEmpty
                }
            } else {
                let resStr = String(data: data, encoding: .utf8) ?? ""
                print("[SubscriptionManager] Verify receipt error response: \(resStr)")
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                    let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                        ?? "このユーザーIDは別の端末で登録されています。チーム管理者に認証リセットを依頼してください。"
                    await MainActor.run {
                        self.authErrorMessage = msg
                    }
                }
                return false
            }
        } catch {
            print("[SubscriptionManager] Verify receipt network error: \(error.localizedDescription)")
            return false
        }
    }


    /// サブスクリプション管理シートをアプリ内で表示する（Appleガイドライン3.1.1準拠）
    /// StoreKit 2公式API: AppStore.showManageSubscriptions(in:) を使用
    /// ユーザーは RowPilot のサブスクリプション管理画面に直接遷移できる
    @MainActor
    func showManageSubscriptions() async {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            // フォールバック：ブラウザでApp Storeを開く
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
            print("[StoreKit] ⚠️ No window scene found, falling back to URL.")
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: windowScene)
            print("[StoreKit] ✅ Showed manage subscriptions sheet.")
        } catch {
            // フォールバック：ブラウザでApp Storeを開く
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
            print("[StoreKit] ❌ showManageSubscriptions failed: \(error). Falling back to URL.")
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
        Task {
            await fetchMyUserRecordIDAsync()
        }
    }

    func fetchMyUserRecordIDAsync() async {
        // 既に確定済みのユーザーIDがある場合は維持（iCloudオン/オフ切替時のID分裂を防止）
        if let stable = KeychainHelper.read(key: stableUserIdKey) ?? UserDefaults.standard.string(forKey: stableUserIdKey),
           !stable.isEmpty {
            KeychainHelper.save(key: stableUserIdKey, value: stable)
            UserDefaults.standard.set(stable, forKey: stableUserIdKey)
            await MainActor.run {
                self.myUserRecordId = stable
            }
            print("[StoreKit] My Stable User Record ID: \(stable)")
            await self.syncTeamPlanWithCloudflare(ownerId: stable, jws: self.lastVerifiedJWS)
            return
        }

        // 初回確定: CloudKitのiCloudレコードIDが取れればそれを採用、不可ならローカルUUIDを発行して永続化
        let resolvedId: String = await withCheckedContinuation { continuation in
            CKContainer.default().fetchUserRecordID { recordID, _ in
                if let recordID = recordID {
                    continuation.resume(returning: recordID.recordName)
                } else if let legacyLocal = UserDefaults.standard.string(forKey: "RowPilot_LocalUserRecordId"), !legacyLocal.isEmpty {
                    continuation.resume(returning: legacyLocal)
                } else {
                    let newId = "User_" + UUID().uuidString.prefix(8)
                    UserDefaults.standard.set(newId, forKey: "RowPilot_LocalUserRecordId")
                    continuation.resume(returning: newId)
                }
            }
        }

        KeychainHelper.save(key: stableUserIdKey, value: resolvedId)
        UserDefaults.standard.set(resolvedId, forKey: stableUserIdKey)
        await MainActor.run {
            self.myUserRecordId = resolvedId
        }
        print("[StoreKit] Resolved & pinned User Record ID: \(resolvedId)")
        await self.syncTeamPlanWithCloudflare(ownerId: resolvedId, jws: self.lastVerifiedJWS)
    }

    // MARK: - 共有上限

    var shareLimit: Int {
        return currentPlan.managerShareLimit
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
        if savedRecord.productId == nil {
            savedRecord = SubscriptionRecord(subscriptionTier: .free, autoRenew: false, expiresAtMs: nil, productId: nil)
        }
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
