// CloudKit依存 - Cloudflare移行中のため無効化
#if false
import Foundation
import CloudKit
import Combine

// MARK: - Team Model

/// チームレコード（Shared Database）
struct CKTeam: Identifiable, Codable, Equatable {
    var id: String          // teamID (UUID)
    var teamName: String
    var inviteCode: String  // Teamに属するinviteCode（管理者全員が同じコードを共有）
    var ownerID: String     // 作成者のuserRecordID
    var createdAt: Date
    var lastInviteCodeResetAt: Date? // 追加: リセット日時

    static func == (lhs: CKTeam, rhs: CKTeam) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Membership Model

/// チームメンバーシップ（Shared Database）
struct CKMembership: Identifiable, Codable, Equatable {
    var id: String          // membershipID (UUID)
    var teamID: String
    var userID: String
    var userName: String    // 共有時の表示名
    var role: MemberRole
    var status: MemberStatus
    var joinedAt: Date
    var leftAt: Date?       // 脱退日時
    var removedAt: Date?    // 削除日時

    enum MemberRole: String, Codable {
        case owner
        case admin
        case member
    }

    enum MemberStatus: String, Codable {
        case active
        case left
        case removed
    }

    var isActive: Bool { status == .active }

    /// 30日保持期間内かどうか（脱退・削除後）
    var isWithinRetentionPeriod: Bool {
        let retentionDays = 30
        if let leftDate = leftAt {
            let daysSince = Calendar.current.dateComponents([.day], from: leftDate, to: Date()).day ?? 0
            return daysSince < retentionDays
        }
        if let removedDate = removedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: removedDate, to: Date()).day ?? 0
            return daysSince < retentionDays
        }
        return false
    }

    static func == (lhs: CKMembership, rhs: CKMembership) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - JoinRequest Model

/// チーム参加リクエスト（Shared Database）
struct CKJoinRequest: Identifiable, Codable, Equatable {
    var id: String
    var teamID: String
    var requestorID: String
    var requestorName: String
    var inviteCode: String
    var status: JoinRequestStatus
    var createdAt: Date

    enum JoinRequestStatus: String, Codable {
        case pending
        case approved
        case rejected
    }

    static func == (lhs: CKJoinRequest, rhs: CKJoinRequest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - TeamWorkoutSummary Model

/// 顧問一覧表示用の軽量ワークアウトサマリー（Shared Database）
struct CKTeamWorkoutSummary: Identifiable, Codable, Equatable {
    var id: String          // workoutID (RowingRecord.id)
    var teamID: String
    var athleteID: String
    var athleteName: String
    var date: Date
    var distance: Double    // メートル
    var duration: TimeInterval  // 秒
    var avgSplit: TimeInterval  // 500mペース（秒）
    var avgRate: Int            // SPM
    var createdAt: Date

    /// フォーマットされた時間
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// フォーマットされた距離
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// フォーマットされたペース
    var formattedSplit: String {
        let totalSeconds = Int(avgSplit)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /500m", minutes, seconds)
    }

    static func == (lhs: CKTeamWorkoutSummary, rhs: CKTeamWorkoutSummary) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - TeamWorkoutDetail Model

/// 顧問詳細表示用のワークアウト詳細（Shared Database）
struct CKTeamWorkoutDetail: Identifiable, Codable, Equatable {
    var id: String          // workoutID
    var teamID: String
    var athleteID: String
    var athleteName: String
    var date: Date
    var duration: TimeInterval
    var distance: Double
    var avgSplit: TimeInterval
    var avgRate: Int
    var avgWatt: Int?
    var notes: String?
    var tags: [String]?
    var dataPointsJSON: Data?   // [WorkoutDataPoint] をJSONエンコードしたもの
    var isManagerMode: Bool
    var createdAt: Date

    static func == (lhs: CKTeamWorkoutDetail, rhs: CKTeamWorkoutDetail) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CloudKitTeamManager

/// CloudKitを使ったチーム機能の中核クラス
/// - Private Database: ユーザー個人データ（Workout等）
/// - Shared Database: Team/Membership/JoinRequest/WorkoutSummary/WorkoutDetail
class CloudKitTeamManager: ObservableObject {
    static let shared = CloudKitTeamManager()

    // MARK: - Published State

    @Published var myTeam: CKTeam? = nil
    @Published var myMembership: CKMembership? = nil           // 選手として参加しているチームの自分のメンバーシップ
    @Published var memberships: [CKMembership] = []            // 管理者として見えるメンバーシップ一覧
    @Published var pendingJoinRequests: [CKJoinRequest] = []
    @Published var workoutSummaries: [CKTeamWorkoutSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Persistence Keys

    private let myTeamKey = "CKTeam_MyTeam"
    private let myMembershipKey = "CKTeam_MyMembership"
    private let membershipsKey = "CKTeam_Memberships"
    private let pendingRequestsKey = "CKTeam_PendingRequests"
    private let summariesKey = "CKTeam_Summaries"

    // MARK: - CloudKit Containers

    private let container = CKContainer.default()

    /// Private Database: 個人データの正本
    var privateDB: CKDatabase {
        container.privateCloudDatabase
    }

    /// Public Database: チーム機能専用（プランA-1: UUID難読化により他チームから保護）
    /// ※変数名は sharedDB のままですが、内部は publicCloudDatabase を使用します。
    var sharedDB: CKDatabase {
        container.publicCloudDatabase
    }

    // MARK: - Record Types

    private let teamRecordType        = "TeamV2"
    private let membershipRecordType  = "MembershipV2"
    private let joinRequestRecordType = "JoinRequestV2"
    private let summaryRecordType     = "TeamWorkoutSummary"
    private let detailRecordType      = "TeamWorkoutDetail"

    // MARK: - 招待コード検索レートリミット（クールダウン）対策

    private let lastSearchErrorTimeKey = "CKTeam_LastSearchErrorTime"
    private let searchFailureCountKey = "CKTeam_SearchFailureCount"

    /// クールダウンの残り時間を取得（0なら制限なし）
    private func checkSearchRateLimit() -> (isBlocked: Bool, waitSeconds: Int) {
        let failureCount = UserDefaults.standard.integer(forKey: searchFailureCountKey)
        guard failureCount > 0 else { return (false, 0) }

        // クールダウン時間の決定（回数に応じて秒数を段階的に増やす）
        let cooldown: TimeInterval
        switch failureCount {
        case 1: cooldown = 0      // 1回失敗はクールダウンなし
        case 2: cooldown = 5      // 2回失敗は5秒
        case 3: cooldown = 15     // 3回失敗は15秒
        case 4: cooldown = 60     // 4回失敗は1分
        default: cooldown = 300   // 5回以上は5分
        }

        if cooldown == 0 { return (false, 0) }

        if let lastErrorTime = UserDefaults.standard.object(forKey: lastSearchErrorTimeKey) as? Date {
            let timePassed = Date().timeIntervalSince(lastErrorTime)
            if timePassed < cooldown {
                let remaining = Int(ceil(cooldown - timePassed))
                return (true, remaining)
            }
        }
        return (false, 0)
    }

    /// 検索失敗を記録
    private func recordSearchFailure() {
        let currentCount = UserDefaults.standard.integer(forKey: searchFailureCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: searchFailureCountKey)
        UserDefaults.standard.set(Date(), forKey: lastSearchErrorTimeKey)
    }

    /// 検索成功時に失敗カウントをリセット
    private func resetSearchFailure() {
        UserDefaults.standard.removeObject(forKey: searchFailureCountKey)
        UserDefaults.standard.removeObject(forKey: lastSearchErrorTimeKey)
    }

    // MARK: - Init

    init() {
        loadLocalCache()
    }

    // MARK: - ローカルキャッシュ

    private func loadLocalCache() {
        if let data = UserDefaults.standard.data(forKey: myTeamKey),
           let team = try? JSONDecoder().decode(CKTeam.self, from: data) {
            self.myTeam = team
        }
        if let data = UserDefaults.standard.data(forKey: myMembershipKey),
           let m = try? JSONDecoder().decode(CKMembership.self, from: data) {
            self.myMembership = m
        }
        if let data = UserDefaults.standard.data(forKey: membershipsKey),
           let ms = try? JSONDecoder().decode([CKMembership].self, from: data) {
            self.memberships = ms
        }
        if let data = UserDefaults.standard.data(forKey: pendingRequestsKey),
           let rs = try? JSONDecoder().decode([CKJoinRequest].self, from: data) {
            self.pendingJoinRequests = rs.filter { $0.status == .pending }
        }
        if let data = UserDefaults.standard.data(forKey: summariesKey),
           let ss = try? JSONDecoder().decode([CKTeamWorkoutSummary].self, from: data) {
            self.workoutSummaries = ss
        }
    }

    func saveLocalCache() {
        if let team = myTeam, let data = try? JSONEncoder().encode(team) {
            UserDefaults.standard.set(data, forKey: myTeamKey)
        } else {
            UserDefaults.standard.removeObject(forKey: myTeamKey)
        }
        if let m = myMembership, let data = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(data, forKey: myMembershipKey)
        } else {
            UserDefaults.standard.removeObject(forKey: myMembershipKey)
        }
        if let data = try? JSONEncoder().encode(memberships) {
            UserDefaults.standard.set(data, forKey: membershipsKey)
        }
        if let data = try? JSONEncoder().encode(pendingJoinRequests) {
            UserDefaults.standard.set(data, forKey: pendingRequestsKey)
        }
        if let data = try? JSONEncoder().encode(workoutSummaries) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
    }

    // MARK: - 自分がチームメンバーかどうか

    /// 選手として何らかのチームに参加しているか
    var isTeamMember: Bool {
        myMembership?.isActive == true
    }

    /// 管理者（owner/admin）として所属しているチームID
    var myManagedTeamID: String? {
        myTeam?.id
    }

    // MARK: - チーム作成（Team/MAX/Org プランユーザー）

    func createTeam(teamName: String, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        let myID = SubscriptionManager.shared.myUserRecordId
        guard !myID.isEmpty else {
            completion(false, "ユーザーIDが取得できません。")
            return
        }

        let teamID = UUID().uuidString
        let inviteCode = generateInviteCode()
        let team = CKTeam(
            id: teamID,
            teamName: teamName,
            inviteCode: inviteCode,
            ownerID: myID,
            createdAt: Date()
        )

        // Shared DB に Team を保存
        let teamRecord = teamToCKRecord(team)
        sharedDB.save(teamRecord) { [weak self] savedRecord, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "チーム作成に失敗しました: \(error.localizedDescription)")
                }
                return
            }

            // オーナー自身のMembershipも作成
            let membership = CKMembership(
                id: UUID().uuidString,
                teamID: teamID,
                userID: myID,
                userName: SettingsManager.shared.settings.sharingName,
                role: .owner,
                status: .active,
                joinedAt: Date()
            )
            let memberRecord = membershipToCKRecord(membership)
            self.sharedDB.save(memberRecord) { _, _ in }

            DispatchQueue.main.async {
                self.myTeam = team
                self.saveLocalCache()
                completion(true, nil)
            }
        }
    }

    // MARK: - チーム参加フロー（選手側）

    /// 招待コードからチームを検索してJoinRequestを作成
    func sendJoinRequest(inviteCode: String, requesterName: String, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        guard !requesterName.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "表示名が設定されていません。設定画面から「共有時の名前」を入力してください。")
            return
        }

        let myID = SubscriptionManager.shared.myUserRecordId
        guard !myID.isEmpty else {
            completion(false, "ユーザーIDが取得できません。")
            return
        }

        // レートリミットチェック
        let limitCheck = checkSearchRateLimit()
        if limitCheck.isBlocked {
            completion(false, "連続して検索に失敗したため、一時的に制限されています。あと \(limitCheck.waitSeconds) 秒待ってから再試行してください。")
            return
        }

        isLoading = true

        // DB から inviteCode に一致するチームを検索
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: teamRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.recordSearchFailure()
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, "チームの検索に失敗しました: \(error.localizedDescription)")
                }
            case .success(let (matchResults, _)):
                guard let (_, recordResult) = matchResults.first,
                      case .success(let teamRecord) = recordResult,
                      let team = self.ckRecordToTeam(teamRecord) else {
                    self.recordSearchFailure()
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(false, "チーム招待コードが見つかりません。コードを確認して再入力してください。")
                    }
                    return
                }

                guard team.ownerID != myID else {
                    // 自分自身のチームへの参加申請は失敗とする（レートリミットはカウントしない）
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(false, "自分自身のチームコードは使用できません。")
                    }
                    return
                }

                // 検索に成功したため失敗履歴をリセット
                self.resetSearchFailure()

                // JoinRequest を作成
                let requestID = UUID().uuidString
                let request = CKJoinRequest(
                    id: requestID,
                    teamID: team.id,
                    requestorID: myID,
                    requestorName: requesterName.trimmingCharacters(in: .whitespaces),
                    inviteCode: inviteCode,
                    status: .pending,
                    createdAt: Date()
                )

                let requestRecord = self.joinRequestToCKRecord(request)
                self.sharedDB.save(requestRecord) { _, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error = error {
                            completion(false, "参加申請に失敗しました: \(error.localizedDescription)")
                        } else {
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 承認待ちリクエスト取得（管理者側）

    func fetchPendingJoinRequests(teamID: String) {
        return
        
        guard !teamID.isEmpty else { return }
        isLoading = true

        let predicate = NSPredicate(format: "teamID == %@ AND status == %@", teamID, "pending")
        let query = CKQuery(recordType: joinRequestRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("fetchPendingJoinRequests error: \(error)")
                }
            case .success(let (matchResults, _)):
                var requests: [CKJoinRequest] = []
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult,
                       let req = self.ckRecordToJoinRequest(record) {
                        requests.append(req)
                    }
                }
                DispatchQueue.main.async {
                    self.pendingJoinRequests = requests
                    self.saveLocalCache()
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - 参加申請承認（管理者側）

    func approveJoinRequest(_ request: CKJoinRequest, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        guard let team = myTeam else {
            completion(false, "チーム情報が見つかりません。")
            return
        }

        let activeCount = memberships.filter { $0.status == .active }.count
        let limit = SubscriptionManager.shared.currentPlan.teamMemberLimit
        if activeCount >= limit {
            completion(false, "チームメンバーの上限（最大\(limit)名）に達しています。")
            return
        }

        if memberships.contains(where: { $0.userID == request.requestorID && $0.status == .active }) {
            completion(false, "このユーザーは既にチームに参加しています。")
            return
        }

        // Membership を作成
        let membership = CKMembership(
            id: UUID().uuidString,
            teamID: team.id,
            userID: request.requestorID,
            userName: request.requestorName,
            role: .member,
            status: .active,
            joinedAt: Date()
        )

        let memberRecord = membershipToCKRecord(membership)
        sharedDB.save(memberRecord) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "承認に失敗しました: \(error.localizedDescription)")
                }
                return
            }

            // JoinRequest のステータスを approved に更新
            self.updateJoinRequestStatus(request.id, to: .approved)

            DispatchQueue.main.async {
                self.memberships.append(membership)
                self.pendingJoinRequests.removeAll { $0.id == request.id }
                self.saveLocalCache()
                completion(true, nil)
            }
        }
    }

    // MARK: - 参加申請拒否（管理者側）

    func rejectJoinRequest(_ request: CKJoinRequest, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        updateJoinRequestStatus(request.id, to: .rejected)
        DispatchQueue.main.async {
            self.pendingJoinRequests.removeAll { $0.id == request.id }
            self.saveLocalCache()
            completion(true, nil)
        }
    }

    // MARK: - メンバー脱退（選手側）

    /// 選手自身によるチーム脱退（即削除せずstatus=left）
    func leaveTeam(membershipID: String, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        let recordID = CKRecord.ID(recordName: membershipID)
        sharedDB.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            guard let record = record else {
                DispatchQueue.main.async {
                    // CloudKit非利用時はローカルのみ更新
                    self.myMembership = nil
                    self.saveLocalCache()
                    completion(true, nil)
                }
                return
            }
            record["status"] = CKMembership.MemberStatus.left.rawValue
            record["leftAt"] = Date() as CKRecordValue
            self.sharedDB.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, "脱退処理に失敗しました: \(error.localizedDescription)")
                    } else {
                        self.myMembership = nil
                        self.saveLocalCache()
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // MARK: - メンバー削除（管理者側）

    /// 管理者によるメンバー削除（即削除せずstatus=removed）
    func removeMember(_ membership: CKMembership, completion: @escaping (Bool, String?) -> Void) {
        completion(false, "現在Cloudflare移行中のため使用できません")
        return
        
        let recordID = CKRecord.ID(recordName: membership.id)
        sharedDB.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self else { return }
            guard let record = record else {
                DispatchQueue.main.async {
                    self.memberships.removeAll { $0.id == membership.id }
                    self.saveLocalCache()
                    completion(true, nil)
                }
                return
            }
            record["status"] = CKMembership.MemberStatus.removed.rawValue
            record["removedAt"] = Date() as CKRecordValue
            self.sharedDB.save(record) { _, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        completion(false, "削除に失敗しました: \(saveError.localizedDescription)")
                    } else {
                        if let idx = self.memberships.firstIndex(where: { $0.id == membership.id }) {
                            var updated = self.memberships[idx]
                            updated.status = .removed
                            updated.removedAt = Date()
                            self.memberships[idx] = updated
                        }
                        self.saveLocalCache()
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // MARK: - 完全削除（管理者 or 30日経過後）

    /// Membership + 関連WorkoutSummary/Detailを完全削除
    func permanentlyDeleteMember(_ membership: CKMembership, completion: @escaping (Bool) -> Void) {
        completion(false)
        return
        
        let memberRecordID = CKRecord.ID(recordName: membership.id)

        // Membership削除
        sharedDB.delete(withRecordID: memberRecordID) { [weak self] _, _ in
            guard let self = self else { return }

            // TeamWorkoutSummary削除
            let summaryPredicate = NSPredicate(format: "athleteID == %@ AND teamID == %@",
                                               membership.userID, membership.teamID)
            let summaryQuery = CKQuery(recordType: self.summaryRecordType, predicate: summaryPredicate)
            self.sharedDB.fetch(withQuery: summaryQuery) { result in
                if case .success(let (matchResults, _)) = result {
                    let ids = matchResults.compactMap { (_, recordResult) -> CKRecord.ID? in
                        if case .success(let r) = recordResult { return r.recordID }
                        return nil
                    }
                    let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                    self.sharedDB.add(deleteOp)
                }
            }

            // TeamWorkoutDetail削除
            let detailPredicate = NSPredicate(format: "athleteID == %@ AND teamID == %@",
                                              membership.userID, membership.teamID)
            let detailQuery = CKQuery(recordType: self.detailRecordType, predicate: detailPredicate)
            self.sharedDB.fetch(withQuery: detailQuery) { result in
                if case .success(let (matchResults, _)) = result {
                    let ids = matchResults.compactMap { (_, recordResult) -> CKRecord.ID? in
                        if case .success(let r) = recordResult { return r.recordID }
                        return nil
                    }
                    let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                    self.sharedDB.add(deleteOp)
                }
            }

            DispatchQueue.main.async {
                self.memberships.removeAll { $0.id == membership.id }
                self.workoutSummaries.removeAll { $0.athleteID == membership.userID }
                self.saveLocalCache()
                completion(true)
            }
        }
    }

    // MARK: - メンバー一覧取得（管理者側）

    func fetchMemberships(teamID: String) {
        return
        
        guard !teamID.isEmpty else { return }
        isLoading = true

        let predicate = NSPredicate(format: "teamID == %@", teamID)
        let query = CKQuery(recordType: membershipRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("fetchMemberships error: \(error)")
                }
            case .success(let (matchResults, _)):
                var ms: [CKMembership] = []
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult,
                       let m = self.ckRecordToMembership(record) {
                        ms.append(m)
                    }
                }
                DispatchQueue.main.async {
                    self.memberships = ms.filter { $0.status == .active }
                    self.saveLocalCache()
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - ワークアウトサマリー取得（管理者側・通信量削減優先）

    func fetchWorkoutSummaries(teamID: String) {
        return
        
        guard !teamID.isEmpty else { return }

        let predicate = NSPredicate(format: "teamID == %@", teamID)
        let query = CKQuery(recordType: summaryRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("fetchWorkoutSummaries error: \(error)")
            case .success(let (matchResults, _)):
                var summaries: [CKTeamWorkoutSummary] = []
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult,
                       let s = self.ckRecordToSummary(record) {
                        summaries.append(s)
                    }
                }
                DispatchQueue.main.async {
                    self.workoutSummaries = summaries
                    self.saveLocalCache()
                }
            }
        }
    }

    // MARK: - ワークアウト詳細取得（タップ時・遅延ロード）

    func fetchWorkoutDetail(workoutID: String, teamID: String, completion: @escaping (CKTeamWorkoutDetail?) -> Void) {
        completion(nil)
        return
        
        let predicate = NSPredicate(format: "workoutID == %@ AND teamID == %@", workoutID, teamID)
        let query = CKQuery(recordType: detailRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("fetchWorkoutDetail error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            case .success(let (matchResults, _)):
                var detail: CKTeamWorkoutDetail? = nil
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult {
                        detail = self.ckRecordToDetail(record)
                        break
                    }
                }
                DispatchQueue.main.async { completion(detail) }
            }
        }
    }

    // MARK: - ワークアウトをShared DBにアップロード（選手側・記録保存後）

    func uploadWorkoutToTeam(record: RowingRecord) {
        return
        
        guard isTeamMember,
              let membership = myMembership,
              membership.status == .active else { return }

        let teamID = membership.teamID
        let athleteID = membership.userID
        let athleteName = membership.userName

        // Summary（一覧表示用・軽量）
        let summaryID = "\(teamID)_\(record.id.uuidString)"
        let summaryRecord = CKRecord(recordType: summaryRecordType,
                                     recordID: CKRecord.ID(recordName: summaryID))
        summaryRecord["workoutID"]    = record.id.uuidString
        summaryRecord["teamID"]       = teamID
        summaryRecord["athleteID"]    = athleteID
        summaryRecord["athleteName"]  = athleteName
        summaryRecord["date"]         = record.date as CKRecordValue
        summaryRecord["distance"]     = record.distance as CKRecordValue
        summaryRecord["duration"]     = record.duration as CKRecordValue
        summaryRecord["avgSplit"]     = record.averagePace as CKRecordValue
        summaryRecord["avgRate"]      = record.averageSPM as CKRecordValue
        summaryRecord["createdAt"]    = Date() as CKRecordValue

        sharedDB.save(summaryRecord) { _, error in
            if let error = error {
                print("CloudKitTeamManager: Summary upload error: \(error.localizedDescription)")
            } else {
                print("CloudKitTeamManager: Summary uploaded for workout \(record.id)")
            }
        }

        // Detail（詳細表示用）
        let detailID = "Detail_\(teamID)_\(record.id.uuidString)"
        let detailRecord = CKRecord(recordType: detailRecordType,
                                     recordID: CKRecord.ID(recordName: detailID))
        detailRecord["workoutID"]     = record.id.uuidString
        detailRecord["teamID"]        = teamID
        detailRecord["athleteID"]     = athleteID
        detailRecord["athleteName"]   = athleteName
        detailRecord["date"]          = record.date as CKRecordValue
        detailRecord["duration"]      = record.duration as CKRecordValue
        detailRecord["distance"]      = record.distance as CKRecordValue
        detailRecord["avgSplit"]      = record.averagePace as CKRecordValue
        detailRecord["avgRate"]       = record.averageSPM as CKRecordValue
        detailRecord["isManagerMode"] = (record.isManagerMode ? 1 : 0) as CKRecordValue
        detailRecord["createdAt"]     = Date() as CKRecordValue

        if let watt = record.averageWatt {
            detailRecord["avgWatt"] = watt as CKRecordValue
        }
        if let notes = record.notes {
            detailRecord["notes"] = notes as CKRecordValue
        }
        if let tags = record.tags {
            detailRecord["tags"] = tags as CKRecordValue
        }
        if let dataPoints = record.dataPoints,
           let dpData = try? JSONEncoder().encode(dataPoints) {
            detailRecord["dataPointsJSON"] = dpData as CKRecordValue
        }

        sharedDB.save(detailRecord) { _, error in
            if let error = error {
                print("CloudKitTeamManager: Detail upload error: \(error.localizedDescription)")
            } else {
                print("CloudKitTeamManager: Detail uploaded for workout \(record.id)")
            }
        }
    }

    // MARK: - チーム情報取得（自分が管理するチームを取得）

    func fetchMyTeam(completion: @escaping (CKTeam?) -> Void) {
        let myID = SubscriptionManager.shared.myUserRecordId
        guard !myID.isEmpty else {
            completion(nil)
            return
        }

        let predicate = NSPredicate(format: "ownerID == %@", myID)
        let query = CKQuery(recordType: teamRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("fetchMyTeam error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            case .success(let (matchResults, _)):
                var team: CKTeam? = nil
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult {
                        team = self.ckRecordToTeam(record)
                        break
                    }
                }
                DispatchQueue.main.async {
                    self.myTeam = team
                    self.saveLocalCache()
                    completion(team)
                }
            }
        }
    }

    // MARK: - 自分のMembership取得（選手側）

    func fetchMyMembership(completion: @escaping (CKMembership?) -> Void) {
        let myID = SubscriptionManager.shared.myUserRecordId
        guard !myID.isEmpty else {
            completion(nil)
            return
        }

        let predicate = NSPredicate(format: "userID == %@ AND status == %@", myID, "active")
        let query = CKQuery(recordType: membershipRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("fetchMyMembership error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            case .success(let (matchResults, _)):
                var membership: CKMembership? = nil
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult {
                        membership = self.ckRecordToMembership(record)
                        break
                    }
                }
                DispatchQueue.main.async {
                    self.myMembership = membership
                    self.saveLocalCache()
                    completion(membership)
                }
            }
        }
    }

    // MARK: - 招待コードリセット

    func resetInviteCode(teamID: String, completion: @escaping (Bool, String?) -> Void) {
        // 5分制限チェック (テスト用)
        if let team = myTeam, let lastReset = team.lastInviteCodeResetAt {
            let minutesSinceReset = Calendar.current.dateComponents([.minute], from: lastReset, to: Date()).minute ?? 0
            if minutesSinceReset < 5 {
                let remaining = 5 - minutesSinceReset
                completion(false, "コードのリセットは5分に1回のみ可能です。あと\(remaining)分後にリセットできます。")
                return
            }
        }

        let recordID = CKRecord.ID(recordName: "Team_\(teamID)")

        sharedDB.fetch(withRecordID: recordID) { [weak self] record, error in
            guard let self = self, let record = record else {
                DispatchQueue.main.async {
                    completion(false, "チームレコードが見つかりません。")
                }
                return
            }
            let newCode = self.generateInviteCode()
            let now = Date()
            record["inviteCode"] = newCode
            record["lastInviteCodeResetAt"] = now as CKRecordValue
            
            self.sharedDB.save(record) { _, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        completion(false, "コードのリセットに失敗しました: \(saveError.localizedDescription)")
                    } else {
                        self.myTeam?.inviteCode = newCode
                        self.myTeam?.lastInviteCodeResetAt = now
                        self.saveLocalCache()
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // MARK: - inviteCode生成

    func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func seg(_ n: Int) -> String {
            String((0..<n).compactMap { _ in chars.randomElement() })
        }
        return "\(seg(4))-\(seg(4))"
    }

    // MARK: - CloudKit Record <-> Model 変換

    private func teamToCKRecord(_ team: CKTeam) -> CKRecord {
        let record = CKRecord(recordType: teamRecordType,
                               recordID: CKRecord.ID(recordName: "Team_\(team.id)"))
        record["teamID"]      = team.id
        record["teamName"]    = team.teamName
        record["inviteCode"]  = team.inviteCode
        record["ownerID"]     = team.ownerID
        record["createdAt"]   = team.createdAt as CKRecordValue
        if let resetAt = team.lastInviteCodeResetAt {
            record["lastInviteCodeResetAt"] = resetAt as CKRecordValue
        }
        return record
    }

    private func ckRecordToTeam(_ record: CKRecord) -> CKTeam? {
        guard let teamID    = record["teamID"] as? String,
              let teamName  = record["teamName"] as? String,
              let inviteCode = record["inviteCode"] as? String,
              let ownerID   = record["ownerID"] as? String,
              let createdAt = record["createdAt"] as? Date else { return nil }
        
        let lastInviteCodeResetAt = record["lastInviteCodeResetAt"] as? Date
        
        return CKTeam(id: teamID, teamName: teamName, inviteCode: inviteCode,
                      ownerID: ownerID, createdAt: createdAt, lastInviteCodeResetAt: lastInviteCodeResetAt)
    }

    private func membershipToCKRecord(_ m: CKMembership) -> CKRecord {
        let record = CKRecord(recordType: membershipRecordType,
                               recordID: CKRecord.ID(recordName: m.id))
        record["teamID"]    = m.teamID
        record["userID"]    = m.userID
        record["userName"]  = m.userName
        record["role"]      = m.role.rawValue
        record["status"]    = m.status.rawValue
        record["joinedAt"]  = m.joinedAt as CKRecordValue
        if let leftAt = m.leftAt { record["leftAt"] = leftAt as CKRecordValue }
        if let removedAt = m.removedAt { record["removedAt"] = removedAt as CKRecordValue }
        return record
    }

    private func ckRecordToMembership(_ record: CKRecord) -> CKMembership? {
        guard let teamID   = record["teamID"] as? String,
              let userID   = record["userID"] as? String,
              let userName = record["userName"] as? String,
              let roleRaw  = record["role"] as? String,
              let role     = CKMembership.MemberRole(rawValue: roleRaw),
              let statusRaw = record["status"] as? String,
              let status   = CKMembership.MemberStatus(rawValue: statusRaw),
              let joinedAt = record["joinedAt"] as? Date else { return nil }

        let leftAt    = record["leftAt"] as? Date
        let removedAt = record["removedAt"] as? Date

        return CKMembership(
            id: record.recordID.recordName,
            teamID: teamID,
            userID: userID,
            userName: userName,
            role: role,
            status: status,
            joinedAt: joinedAt,
            leftAt: leftAt,
            removedAt: removedAt
        )
    }

    private func joinRequestToCKRecord(_ req: CKJoinRequest) -> CKRecord {
        let record = CKRecord(recordType: joinRequestRecordType,
                               recordID: CKRecord.ID(recordName: req.id))
        record["teamID"]        = req.teamID
        record["requestorID"]   = req.requestorID
        record["requestorName"] = req.requestorName
        record["inviteCode"]    = req.inviteCode
        record["status"]        = req.status.rawValue
        record["createdAt"]     = req.createdAt as CKRecordValue
        return record
    }

    private func ckRecordToJoinRequest(_ record: CKRecord) -> CKJoinRequest? {
        guard let teamID        = record["teamID"] as? String,
              let requestorID   = record["requestorID"] as? String,
              let requestorName = record["requestorName"] as? String,
              let inviteCode    = record["inviteCode"] as? String,
              let statusRaw     = record["status"] as? String,
              let status        = CKJoinRequest.JoinRequestStatus(rawValue: statusRaw),
              let createdAt     = record["createdAt"] as? Date else { return nil }
        return CKJoinRequest(
            id: record.recordID.recordName,
            teamID: teamID,
            requestorID: requestorID,
            requestorName: requestorName,
            inviteCode: inviteCode,
            status: status,
            createdAt: createdAt
        )
    }

    private func ckRecordToSummary(_ record: CKRecord) -> CKTeamWorkoutSummary? {
        guard let workoutID   = record["workoutID"] as? String,
              let teamID      = record["teamID"] as? String,
              let athleteID   = record["athleteID"] as? String,
              let athleteName = record["athleteName"] as? String,
              let date        = record["date"] as? Date,
              let distance    = record["distance"] as? Double,
              let duration    = record["duration"] as? Double,
              let avgSplit    = record["avgSplit"] as? Double,
              let avgRate     = record["avgRate"] as? Int,
              let createdAt   = record["createdAt"] as? Date else { return nil }
        return CKTeamWorkoutSummary(
            id: workoutID, teamID: teamID, athleteID: athleteID,
            athleteName: athleteName, date: date, distance: distance,
            duration: duration, avgSplit: avgSplit, avgRate: avgRate,
            createdAt: createdAt
        )
    }

    private func ckRecordToDetail(_ record: CKRecord) -> CKTeamWorkoutDetail? {
        guard let workoutID   = record["workoutID"] as? String,
              let teamID      = record["teamID"] as? String,
              let athleteID   = record["athleteID"] as? String,
              let athleteName = record["athleteName"] as? String,
              let date        = record["date"] as? Date,
              let duration    = record["duration"] as? Double,
              let distance    = record["distance"] as? Double,
              let avgSplit    = record["avgSplit"] as? Double,
              let avgRate     = record["avgRate"] as? Int,
              let createdAt   = record["createdAt"] as? Date else { return nil }

        let isManagerMode = (record["isManagerMode"] as? Int ?? 0) == 1
        let avgWatt         = record["avgWatt"] as? Int
        let notes           = record["notes"] as? String
        let tags            = record["tags"] as? [String]
        let dataPointsJSON  = record["dataPointsJSON"] as? Data

        return CKTeamWorkoutDetail(
            id: workoutID, teamID: teamID, athleteID: athleteID,
            athleteName: athleteName, date: date, duration: duration,
            distance: distance, avgSplit: avgSplit, avgRate: avgRate,
            avgWatt: avgWatt, notes: notes, tags: tags,
            dataPointsJSON: dataPointsJSON, isManagerMode: isManagerMode,
            createdAt: createdAt
        )
    }

    // MARK: - JoinRequest ステータス更新

    private func updateJoinRequestStatus(_ requestID: String, to status: CKJoinRequest.JoinRequestStatus) {
        let recordID = CKRecord.ID(recordName: requestID)
        sharedDB.fetch(withRecordID: recordID) { [weak self] record, _ in
            guard let record = record else { return }
            record["status"] = status.rawValue
            self?.sharedDB.save(record) { _, _ in }
        }
    }

    // MARK: - 30日経過メンバーの自動クリーンアップ

    func cleanupExpiredMembers() {
        guard let teamID = myTeam?.id else { return }

        let predicate = NSPredicate(format: "teamID == %@ AND (status == %@ OR status == %@)",
                                    teamID, "left", "removed")
        let query = CKQuery(recordType: membershipRecordType, predicate: predicate)

        sharedDB.fetch(withQuery: query) { [weak self] result in
            guard let self = self else { return }
            if case .success(let (matchResults, _)) = result {
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult,
                       let m = self.ckRecordToMembership(record),
                       !m.isWithinRetentionPeriod {
                        self.permanentlyDeleteMember(m) { _ in }
                    }
                }
            }
        }
    }
}
#endif // CloudKit依存 - Cloudflare移行中のため無効化
