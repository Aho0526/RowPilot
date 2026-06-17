import Foundation
import CloudKit
import Combine

// MARK: - チームメンバー

/// チームに参加しているメンバー
struct TeamMember: Codable, Identifiable, Equatable {
    var id: String          // ユーザーID
    var name: String        // 共有時の名前
    var joinedAt: Date

    static func == (lhs: TeamMember, rhs: TeamMember) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - チーム参加リクエスト

/// チーム参加リクエスト
struct TeamJoinRequest: Codable, Identifiable, Equatable {
    var id: String
    var requestorID: String
    var requestorName: String
    var ownerID: String
    var inviteCode: String
    var status: RequestStatus
    var createdAt: Date

    enum RequestStatus: String, Codable {
        case pending
        case approved
        case rejected
    }
}

// MARK: - メンバー記録サマリー（軽量）

/// 管理者端末に配信される軽量サマリーデータ
struct TeamRecordSummary: Codable, Identifiable, Equatable {
    var id: String          // recordId (UUID文字列)
    var userId: String
    var userName: String
    var date: Date
    var duration: TimeInterval
    var distance: Double
    var averageSPM: Int
    var averagePace: TimeInterval
    var isManagerMode: Bool
    var tags: [String]?

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
        return String(format: "%.0f m", distance)
    }

    /// フォーマットされたペース
    var formattedPace: String {
        let totalSeconds = Int(averagePace)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /500m", minutes, seconds)
    }
}

// MARK: - TeamManager

/// チーム機能の中核ロジックを管理するクラス
class TeamManager: ObservableObject {
    static let shared = TeamManager()

    // MARK: - Published State

    @Published var teamMembers: [TeamMember] = []
    @Published var pendingTeamRequests: [TeamJoinRequest] = []
    @Published var memberRecordSummaries: [TeamRecordSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Polling Timer

    private var pollingTimer: AnyCancellable?
    private let pollingInterval: TimeInterval = 60.0 // 1分

    // MARK: - Persistence Keys

    private let teamMembersKey = "RowPilot_TeamMembers"
    private let pendingRequestsKey = "RowPilot_TeamPendingRequests"
    private let summariesKey = "RowPilot_TeamRecordSummaries"
    private let mockTeamRecordsKey = "RowPilot_MockTeamRecords"
    private let myTeamOwnerKey = "RowPilot_MyTeamOwnerID"

    // MARK: - CloudKit

    private var useCloudKit: Bool { SubscriptionManager.shared.useCloudKit }

    private var database: CKDatabase? {
        guard useCloudKit else { return nil }
        return CKContainer.default().publicCloudDatabase
    }

    // MARK: - Init

    init() {
        loadLocalData()
    }

    // MARK: - チーム上限

    var teamLimit: Int {
        SubscriptionManager.shared.currentPlan.teamMemberLimit
    }

    // MARK: - ポーリング制御

    /// 1分間隔のサマリーポーリングを開始
    func startPolling() {
        stopPolling()
        // 初回即座に取得
        fetchMemberSummaries()

        pollingTimer = Timer.publish(every: pollingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchMemberSummaries()
            }
        print("TeamManager: Polling started (every \(Int(pollingInterval))s)")
    }

    /// ポーリングを停止
    func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
        print("TeamManager: Polling stopped")
    }

    // MARK: - ローカルデータ読み書き

    private func loadLocalData() {
        // チームメンバー
        if let data = UserDefaults.standard.data(forKey: teamMembersKey),
           let members = try? JSONDecoder().decode([TeamMember].self, from: data) {
            self.teamMembers = members
        }
        // 承認待ちリクエスト
        if let data = UserDefaults.standard.data(forKey: pendingRequestsKey),
           let requests = try? JSONDecoder().decode([TeamJoinRequest].self, from: data) {
            self.pendingTeamRequests = requests.filter { $0.status == .pending }
        }
        // サマリー
        if let data = UserDefaults.standard.data(forKey: summariesKey),
           let summaries = try? JSONDecoder().decode([TeamRecordSummary].self, from: data) {
            self.memberRecordSummaries = summaries
        }
    }

    private func saveTeamMembers() {
        if let data = try? JSONEncoder().encode(teamMembers) {
            UserDefaults.standard.set(data, forKey: teamMembersKey)
        }
    }

    private func savePendingRequests() {
        if let data = try? JSONEncoder().encode(pendingTeamRequests) {
            UserDefaults.standard.set(data, forKey: pendingRequestsKey)
        }
    }

    private func saveSummaries() {
        if let data = try? JSONEncoder().encode(memberRecordSummaries) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
    }

    // MARK: - 自分がチームに参加中かどうか

    var isTeamMember: Bool {
        myTeamOwnerID != nil
    }

    var myTeamOwnerID: String? {
        get { UserDefaults.standard.string(forKey: myTeamOwnerKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: myTeamOwnerKey)
            objectWillChange.send()
        }
    }

    // MARK: - リクエスト送信（メンバー側）

    func sendJoinRequest(code: String, requestorName: String, requestorID: String,
                         completion: @escaping (Bool, String?) -> Void) {
        guard !requestorName.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, "共有時の名前が設定されていません。設定画面から「共有時の名前」を入力してください。")
            return
        }

        isLoading = true

        // TeamInviteCodeManager依存を削除（Cloudflare移行中）
        // TeamInviteCodeManager.shared.findTeamOwner(forCode: code) { [weak self] ownerID in
        DispatchQueue.main.async {
            self.isLoading = false
            completion(false, "現在Cloudflare移行中のため、チーム参加機能は一時的に利用できません。")
        }
        /*
        TeamInviteCodeManager.shared.findTeamOwner(forCode: code) { [weak self] ownerID in
            guard let self = self else { return }

            guard let ownerID = ownerID else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false, "チーム招待コードが見つかりません。コードを確認して再入力してください。")
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

            let request = TeamJoinRequest(
                id: UUID().uuidString,
                requestorID: requestorID,
                requestorName: requestorName.trimmingCharacters(in: .whitespaces),
                ownerID: ownerID,
                inviteCode: code,
                status: .pending,
                createdAt: Date()
            )

            self.saveJoinRequest(request) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(success, error)
                }
            }
        }
        */ // end of TeamInviteCodeManager disabled block
    }

    private func saveJoinRequest(_ request: TeamJoinRequest, completion: @escaping (Bool, String?) -> Void) {
        guard let db = database else {
            // Mock: ローカル保存
            saveMockJoinRequest(request)
            // オーナーが自分の場合はpendingに追加
            if request.ownerID == SubscriptionManager.shared.myUserRecordId {
                DispatchQueue.main.async {
                    self.pendingTeamRequests.append(request)
                    self.savePendingRequests()
                }
            }
            completion(true, nil)
            return
        }

        let record = CKRecord(recordType: "TeamJoinRequest", recordID: CKRecord.ID(recordName: request.id))
        record["requestorID"] = request.requestorID
        record["requestorName"] = request.requestorName
        record["ownerID"] = request.ownerID
        record["inviteCode"] = request.inviteCode
        record["status"] = request.status.rawValue
        record["createdAt"] = request.createdAt

        db.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "リクエスト送信に失敗しました: \(error.localizedDescription)")
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // MARK: - リクエスト取得（管理者側）

    func fetchPendingRequests(ownerID: String) {
        guard !ownerID.isEmpty else { return }
        isLoading = true

        guard let db = database else {
            // Mock
            let mockRequests = getMockJoinRequests(ownerID: ownerID)
            DispatchQueue.main.async {
                self.pendingTeamRequests = mockRequests.filter { $0.status == .pending }
                self.savePendingRequests()
                self.isLoading = false
            }
            return
        }

        let predicate = NSPredicate(format: "ownerID == %@ AND status == %@", ownerID, "pending")
        let query = CKQuery(recordType: "TeamJoinRequest", predicate: predicate)
        var requests: [TeamJoinRequest] = []

        let operation = CKQueryOperation(query: query)
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result,
               let req = self.parseJoinRequestRecord(record) {
                requests.append(req)
            }
        }
        operation.queryResultBlock = { _ in
            DispatchQueue.main.async {
                self.pendingTeamRequests = requests
                self.savePendingRequests()
                self.isLoading = false
            }
        }
        db.add(operation)
    }

    // MARK: - 承認 / 拒否

    func approveRequest(_ request: TeamJoinRequest, completion: @escaping (Bool, String?) -> Void) {
        // 上限チェック
        if teamMembers.count >= teamLimit {
            completion(false, "チームメンバーの上限（最大\(teamLimit)名）に達しています。")
            return
        }

        // 重複チェック
        if teamMembers.contains(where: { $0.id == request.requestorID }) {
            completion(false, "このユーザーは既にチームに参加しています。")
            return
        }

        // メンバー追加
        teamMembers.append(TeamMember(
            id: request.requestorID,
            name: request.requestorName,
            joinedAt: Date()
        ))
        saveTeamMembers()

        // リクエストステータス更新
        updateJoinRequestStatus(request.id, status: .approved)
        pendingTeamRequests.removeAll { $0.id == request.id }
        savePendingRequests()

        // Mock: メンバー側のチーム参加状態を更新
        if database == nil {
            updateMockJoinRequestStatus(request.id, status: .approved)
            let mockKey = "RowPilot_MockTeamMemberOf_\(request.requestorID)"
            UserDefaults.standard.set(request.ownerID, forKey: mockKey)
        }

        completion(true, nil)
    }

    func rejectRequest(_ request: TeamJoinRequest, completion: @escaping (Bool, String?) -> Void) {
        updateJoinRequestStatus(request.id, status: .rejected)
        pendingTeamRequests.removeAll { $0.id == request.id }
        savePendingRequests()

        if database == nil {
            updateMockJoinRequestStatus(request.id, status: .rejected)
        }

        completion(true, nil)
    }

    func removeMember(_ memberId: String) {
        teamMembers.removeAll { $0.id == memberId }
        saveTeamMembers()

        // 該当メンバーのサマリーも削除
        memberRecordSummaries.removeAll { $0.userId == memberId }
        saveSummaries()

        // Mock: メンバーのチーム参加状態をクリア
        if database == nil {
            let mockKey = "RowPilot_MockTeamMemberOf_\(memberId)"
            UserDefaults.standard.removeObject(forKey: mockKey)
        }
    }

    // MARK: - サマリー取得（1分ポーリング）

    func fetchMemberSummaries() {
        let ownerID = SubscriptionManager.shared.myUserRecordId
        guard !ownerID.isEmpty, !teamMembers.isEmpty else { return }

        guard let db = database else {
            // Mock: ローカルのMockDBからサマリー取得
            DispatchQueue.main.async {
                let summaries = self.getMockSummaries(ownerID: ownerID)
                if !summaries.isEmpty {
                    self.memberRecordSummaries = summaries
                    self.saveSummaries()
                }
            }
            return
        }

        let memberIDs = teamMembers.map { $0.id }
        let predicate = NSPredicate(format: "userId IN %@", memberIDs)
        let query = CKQuery(recordType: "TeamRecordSummary", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        var summaries: [TeamRecordSummary] = []

        let operation = CKQueryOperation(query: query)
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result,
               let summary = self.parseSummaryRecord(record) {
                summaries.append(summary)
            }
        }
        operation.queryResultBlock = { _ in
            DispatchQueue.main.async {
                if !summaries.isEmpty {
                    self.memberRecordSummaries = summaries
                    self.saveSummaries()
                }
            }
        }
        db.add(operation)
    }

    // MARK: - 詳細データ取得（タップ時）

    func fetchFullRecord(recordId: String, userId: String, completion: @escaping (RowingRecord?) -> Void) {
        guard let db = database else {
            // Mock: ローカルから取得
            DispatchQueue.main.async {
                let record = self.getMockFullRecord(recordId: recordId, userId: userId)
                completion(record)
            }
            return
        }

        let predicate = NSPredicate(format: "recordId == %@ AND userId == %@", recordId, userId)
        let query = CKQuery(recordType: "TeamFullRecord", predicate: predicate)
        var result: RowingRecord? = nil

        let operation = CKQueryOperation(query: query)
        operation.recordMatchedBlock = { _, fetchResult in
            if case .success(let record) = fetchResult {
                result = self.parseFullRecordFromCK(record)
            }
        }
        operation.queryResultBlock = { _ in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        db.add(operation)
    }

    // MARK: - CloudKit Helpers

    private func updateJoinRequestStatus(_ requestID: String, status: TeamJoinRequest.RequestStatus) {
        guard let db = database else { return }
        let recordID = CKRecord.ID(recordName: requestID)
        db.fetch(withRecordID: recordID) { record, _ in
            guard let record = record else { return }
            record["status"] = status.rawValue
            db.save(record) { _, _ in }
        }
    }

    private func parseJoinRequestRecord(_ record: CKRecord) -> TeamJoinRequest? {
        guard let requestorID = record["requestorID"] as? String,
              let requestorName = record["requestorName"] as? String,
              let ownerID = record["ownerID"] as? String,
              let inviteCode = record["inviteCode"] as? String,
              let statusRaw = record["status"] as? String,
              let status = TeamJoinRequest.RequestStatus(rawValue: statusRaw),
              let createdAt = record["createdAt"] as? Date else { return nil }

        return TeamJoinRequest(
            id: record.recordID.recordName,
            requestorID: requestorID,
            requestorName: requestorName,
            ownerID: ownerID,
            inviteCode: inviteCode,
            status: status,
            createdAt: createdAt
        )
    }

    private func parseSummaryRecord(_ record: CKRecord) -> TeamRecordSummary? {
        guard let recordId = record["recordId"] as? String,
              let userId = record["userId"] as? String,
              let userName = record["userName"] as? String,
              let date = record["date"] as? Date,
              let duration = record["duration"] as? Double,
              let distance = record["distance"] as? Double,
              let averageSPM = record["averageSPM"] as? Int,
              let averagePace = record["averagePace"] as? Double else { return nil }

        let isManagerMode = record["isManagerMode"] as? Bool ?? false
        let tags = record["tags"] as? [String]

        return TeamRecordSummary(
            id: recordId,
            userId: userId,
            userName: userName,
            date: date,
            duration: duration,
            distance: distance,
            averageSPM: averageSPM,
            averagePace: averagePace,
            isManagerMode: isManagerMode,
            tags: tags
        )
    }

    private func parseFullRecordFromCK(_ record: CKRecord) -> RowingRecord? {
        guard let recordIdStr = record["recordId"] as? String,
              let recordId = UUID(uuidString: recordIdStr),
              let date = record["date"] as? Date,
              let duration = record["duration"] as? Double,
              let distance = record["distance"] as? Double,
              let averageSPM = record["averageSPM"] as? Int,
              let averageSpeed = record["averageSpeed"] as? Double,
              let averagePace = record["averagePace"] as? Double else { return nil }

        let isManagerMode = record["isManagerMode"] as? Bool ?? false
        let notes = record["notes"] as? String
        let tags = record["tags"] as? [String]
        let averageWatt = record["averageWatt"] as? Int

        var dataPoints: [WorkoutDataPoint]? = nil
        if let dpData = record["dataPointsJSON"] as? Data {
            dataPoints = try? JSONDecoder().decode([WorkoutDataPoint].self, from: dpData)
        }

        return RowingRecord(
            id: recordId,
            date: date,
            duration: duration,
            distance: distance,
            averageSPM: averageSPM,
            averageSpeed: averageSpeed,
            averagePace: averagePace,
            notes: notes,
            tags: tags,
            isManagerMode: isManagerMode,
            averageWatt: averageWatt,
            dataPoints: dataPoints
        )
    }

    // MARK: - Mock DB Helpers

    private let mockJoinRequestsKey = "RowPilot_MockTeamJoinRequests"

    private func saveMockJoinRequest(_ request: TeamJoinRequest) {
        var all = getAllMockJoinRequests()
        all.append(request)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: mockJoinRequestsKey)
        }
    }

    private func getAllMockJoinRequests() -> [TeamJoinRequest] {
        guard let data = UserDefaults.standard.data(forKey: mockJoinRequestsKey),
              let all = try? JSONDecoder().decode([TeamJoinRequest].self, from: data) else { return [] }
        return all
    }

    private func getMockJoinRequests(ownerID: String) -> [TeamJoinRequest] {
        return getAllMockJoinRequests().filter { $0.ownerID == ownerID }
    }

    private func updateMockJoinRequestStatus(_ id: String, status: TeamJoinRequest.RequestStatus) {
        var all = getAllMockJoinRequests()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx] = TeamJoinRequest(
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
            UserDefaults.standard.set(data, forKey: mockJoinRequestsKey)
        }
    }

    // Mock: サマリーデータ取得
    private func getMockSummaries(ownerID: String) -> [TeamRecordSummary] {
        let memberIDs = teamMembers.map { $0.id }
        guard let data = UserDefaults.standard.data(forKey: mockTeamRecordsKey),
              let allSummaries = try? JSONDecoder().decode([TeamRecordSummary].self, from: data) else { return [] }
        return allSummaries.filter { memberIDs.contains($0.userId) }
            .sorted { $0.date > $1.date }
    }

    // Mock: フルレコード取得
    private func getMockFullRecord(recordId: String, userId: String) -> RowingRecord? {
        let fullRecordsKey = "RowPilot_MockTeamFullRecords"
        guard let data = UserDefaults.standard.data(forKey: fullRecordsKey),
              let allRecords = try? JSONDecoder().decode([String: Data].self, from: data),
              let recordData = allRecords[recordId],
              let record = try? JSONDecoder().decode(RowingRecord.self, from: recordData) else { return nil }
        return record
    }
}
