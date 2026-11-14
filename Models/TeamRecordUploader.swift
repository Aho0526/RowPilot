import Foundation

struct TeamWorkoutSummaryPayload: Codable {
    var averageWatt: Double?
    var averageSPM: Int?
    var calories: Double?
    var notes: String?
    var intervalDetails: String?
    var isManagerMode: Bool?
}

private struct PendingTeamUploadItem: Codable, Equatable {
    let record: RowingRecord
    let targetAthleteId: String?
}

/// チーム向けワークアウト記録のD1アップロード／削除とオフライン再送キューを管理する
class TeamRecordUploader {
    static let shared = TeamRecordUploader()

    private let pendingUploadsKey = "RowPilot_PendingTeamUploads"
    private let pendingDeletesKey = "RowPilot_PendingTeamDeletes"
    private let queueLock = NSLock()
    private var isFlushing = false

    private init() {}

    // MARK: - Public Entry Points

    func uploadIfNeeded(record: RowingRecord) {
        if !SettingsManager.shared.settings.autoUploadToTeam { return }
        // マネージャーの複数台セッション記録は選手を割り当てる前に個人成績として自動送信しない (C1)
        if record.managerSessionId != nil { return }
        uploadToTeam(record: record, targetAthleteId: nil, notifyUser: false)
    }

    // 手動または代理でアップロードを実行する
    func uploadManual(record: RowingRecord, targetAthleteId: String? = nil) {
        uploadToTeam(record: record, targetAthleteId: targetAthleteId, notifyUser: true)
    }

    /// オフライン時に保留されたアップロード・削除を再送する
    func flushPendingOperations() {
        queueLock.lock()
        if isFlushing {
            queueLock.unlock()
            return
        }
        isFlushing = true
        queueLock.unlock()

        Task {
            defer {
                self.queueLock.lock()
                self.isFlushing = false
                self.queueLock.unlock()
            }

            let uploads = loadPendingUploads()
            for item in uploads {
                let outcome = await performUpload(record: item.record, targetAthleteId: item.targetAthleteId, notifyUser: false)
                if outcome == .succeeded || outcome == .permanentFailure {
                    removePendingUpload(recordID: item.record.id, targetAthleteId: item.targetAthleteId)
                }
            }

            let deletes = loadPendingDeletes()
            for idStr in deletes {
                let outcome = await performDelete(recordIDString: idStr)
                if outcome == .succeeded || outcome == .permanentFailure {
                    removePendingDelete(recordIDString: idStr)
                }
            }
        }
    }

    // MARK: - Upload Implementation

    private enum SyncOutcome {
        case succeeded
        case retryableFailure
        case permanentFailure
    }

    private func authorizedData(for originalRequest: URLRequest) async throws -> (Data, URLResponse) {
        await SubscriptionManager.shared.ensureValidApiToken()
        var request = originalRequest
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let refreshed = await SubscriptionManager.shared.refreshApiToken()
            if refreshed {
                var retryRequest = originalRequest
                let newToken = SubscriptionManager.shared.apiToken
                if !newToken.isEmpty {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                return try await URLSession.shared.data(for: retryRequest)
            }
        }
        return (data, response)
    }

    private func uploadToTeam(record: RowingRecord, targetAthleteId: String?, notifyUser: Bool) {
        Task {
            let outcome = await performUpload(record: record, targetAthleteId: targetAthleteId, notifyUser: notifyUser)
            if outcome == .retryableFailure {
                enqueuePendingUpload(record: record, targetAthleteId: targetAthleteId)
            } else if outcome == .succeeded {
                removePendingUpload(recordID: record.id, targetAthleteId: targetAthleteId)
            }
        }
    }

    private func performUpload(record: RowingRecord, targetAthleteId: String?, notifyUser: Bool) async -> SyncOutcome {
        let userID = SubscriptionManager.shared.myUserRecordId
        guard !userID.isEmpty else { return .retryableFailure }

        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/\(userID)/team"
        guard let url = URL(string: urlString) else { return .permanentFailure }

        do {
            let (data, response) = try await authorizedData(for: URLRequest(url: url))
            guard let httpResponse = response as? HTTPURLResponse else {
                return .retryableFailure
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                return (400...499).contains(httpResponse.statusCode) ? .permanentFailure : .retryableFailure
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            if responseString == "null" {
                return .permanentFailure
            }

            let decodedTeam = try JSONDecoder().decode(Team.self, from: data)

            // 承認待ち・アーカイブ時はアップロードをスキップ
            if decodedTeam.my_role == "pending" {
                print("TeamRecordUploader: Membership is pending. Skipping upload.")
                return .permanentFailure
            }
            if decodedTeam.isSuspended {
                print("TeamRecordUploader: Team is suspended (archived). Skipping upload.")
                return .permanentFailure
            }

            // 表示名がローカルに設定されている場合は事前にusersテーブルへ同期
            let sharingName = SettingsManager.shared.settings.sharingName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sharingName.isEmpty,
               let userUrl = URL(string: "https://rowpilot-api.rowpilot-jp.workers.dev/users") {
                var userReq = URLRequest(url: userUrl)
                userReq.httpMethod = "POST"
                userReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let userBody: [String: Any] = [
                    "id": userID,
                    "display_name": sharingName,
                    "is_ghost": 0,
                    "entitlement": SubscriptionManager.shared.ownPlan.rawValue,
                    "created_at": Int(Date().timeIntervalSince1970)
                ]
                if let userData = try? JSONSerialization.data(withJSONObject: userBody, options: []) {
                    userReq.httpBody = userData
                    _ = try? await authorizedData(for: userReq)
                }
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let isIndoor = (record.tags?.contains("Indoor") == true) || record.isManagerMode || (record.pm5SerialNumber != nil)
            let workoutType = isIndoor ? "indoor" : "outdoor"

            let workoutFormat: String = {
                if record.notes?.localizedCaseInsensitiveContains("interval") == true || record.tags?.contains("interval") == true {
                    return "interval"
                }
                return record.isDistanceWorkout ? "distance" : "time"
            }()

            var crewInfoJsonString: String? = nil
            if let crewInfo = record.crewInfo,
               let jsonData = try? JSONEncoder().encode(crewInfo) {
                crewInfoJsonString = String(data: jsonData, encoding: .utf8)
            }

            let avgWattValue = record.averageWatt.map { Double($0) }
            let summaryPayload = TeamWorkoutSummaryPayload(
                averageWatt: avgWattValue,
                averageSPM: record.averageSPM > 0 ? record.averageSPM : nil,
                calories: nil,
                notes: record.notes,
                intervalDetails: nil,
                isManagerMode: record.isManagerMode
            )
            let summaryJsonString = (try? JSONEncoder().encode(summaryPayload)).flatMap { String(data: $0, encoding: .utf8) }

            let safeDistance = record.distance.isFinite && record.distance >= 0 ? record.distance : 0
            let safeDuration = record.duration.isFinite && record.duration >= 0 ? record.duration : 0
            let safePace = record.averagePace.isFinite && record.averagePace >= 0 ? record.averagePace : 0
            let athleteIdToSave = targetAthleteId ?? userID
            let recordIdToSave: String = {
                if let target = targetAthleteId, target != userID {
                    return "\(record.id.uuidString)_\(target)"
                }
                return record.id.uuidString
            }()

            let workout = CloudflareWorkoutRecord(
                id: recordIdToSave,
                athlete_id: athleteIdToSave,
                recorded_by_id: userID,
                team_id: decodedTeam.id,
                type: workoutType,
                format: workoutFormat,
                distance_m: safeDistance,
                duration_sec: safeDuration,
                split_500m_sec: safePace,
                stroke_rate: record.averageSPM > 0 ? Double(record.averageSPM) : nil,
                boat_type: record.crewInfo?.boatType.rawValue ?? "1x",
                recorded_on: formatter.string(from: record.date),
                created_at: formatter.string(from: Date()),
                athlete_name: nil,
                crew_info: crewInfoJsonString,
                average_watt: avgWattValue,
                notes: record.notes,
                calories: nil,
                is_manager_mode: record.isManagerMode ? 1 : 0,
                summary_json: summaryJsonString
            )

            guard let saveUrl = URL(string: "https://rowpilot-api.rowpilot-jp.workers.dev/workouts") else {
                return .permanentFailure
            }

            var request = URLRequest(url: saveUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(workout)

            let (saveData, saveResponse) = try await authorizedData(for: request)
            if let saveHttp = saveResponse as? HTTPURLResponse {
                if (200...299).contains(saveHttp.statusCode) {
                    print("TeamRecordUploader: Uploaded workout successfully to Cloudflare D1.")
                    if notifyUser {
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TeamWorkoutUploadSuccess"),
                                object: nil,
                                userInfo: ["message": "記録が正常に共有されました"]
                            )
                        }
                    }
                    return .succeeded
                } else {
                    let responseString = String(data: saveData, encoding: .utf8) ?? ""
                    print("TeamRecordUploader: Failed to upload workout (\(saveHttp.statusCode)). Response: \(responseString)")

                    let finalErrorMsg: String
                    if let dict = try? JSONSerialization.jsonObject(with: saveData, options: []) as? [String: Any],
                       let serverError = dict["error"] as? String {
                        finalErrorMsg = "記録の共有に失敗しました: \(serverError)"
                    } else {
                        finalErrorMsg = "記録の共有に失敗しました"
                    }
                    if notifyUser {
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TeamWorkoutUploadFailed"),
                                object: nil,
                                userInfo: ["error": finalErrorMsg]
                            )
                        }
                    }
                    return (400...499).contains(saveHttp.statusCode) ? .permanentFailure : .retryableFailure
                }
            }
            return .retryableFailure
        } catch {
            print("TeamRecordUploader: Error \(error)")
            if notifyUser {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TeamWorkoutUploadFailed"),
                        object: nil,
                        userInfo: ["error": "通信エラーのため送信待ちキューに保存しました。オンライン時に自動再送されます。"]
                    )
                }
            }
            return .retryableFailure
        }
    }

    // D1からワークアウトを削除する
    func deleteFromTeam(recordID: UUID) {
        let idString = recordID.uuidString
        Task {
            let outcome = await performDelete(recordIDString: idString)
            if outcome == .retryableFailure {
                enqueuePendingDelete(recordIDString: idString)
            } else if outcome == .succeeded {
                removePendingDelete(recordIDString: idString)
            }
        }
    }

    private func performDelete(recordIDString: String) async -> SyncOutcome {
        let requesterId = SubscriptionManager.shared.myUserRecordId
        guard !requesterId.isEmpty else { return .retryableFailure }
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/workouts/\(recordIDString)?requester_id=\(requesterId)"
        guard let url = URL(string: urlString) else { return .permanentFailure }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (data, response) = try await authorizedData(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("TeamRecordUploader: Deleted workout successfully from Cloudflare D1.")
                    return .succeeded
                }
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("TeamRecordUploader: Failed to delete workout (\(httpResponse.statusCode)). Response: \(responseString)")
                return (400...499).contains(httpResponse.statusCode) ? .permanentFailure : .retryableFailure
            }
            return .retryableFailure
        } catch {
            print("TeamRecordUploader: Error deleting workout: \(error)")
            return .retryableFailure
        }
    }

    // MARK: - Pending Queue Persistence

    private func loadPendingUploads() -> [PendingTeamUploadItem] {
        queueLock.lock()
        defer { queueLock.unlock() }
        guard let data = UserDefaults.standard.data(forKey: pendingUploadsKey),
              let items = try? JSONDecoder().decode([PendingTeamUploadItem].self, from: data) else {
            return []
        }
        return items
    }

    private func savePendingUploads(_ items: [PendingTeamUploadItem]) {
        queueLock.lock()
        defer { queueLock.unlock() }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: pendingUploadsKey)
        }
    }

    private func enqueuePendingUpload(record: RowingRecord, targetAthleteId: String?) {
        var items = loadPendingUploads()
        items.removeAll { $0.record.id == record.id && $0.targetAthleteId == targetAthleteId }
        items.append(PendingTeamUploadItem(record: record, targetAthleteId: targetAthleteId))
        savePendingUploads(items)
    }

    private func removePendingUpload(recordID: UUID, targetAthleteId: String?) {
        var items = loadPendingUploads()
        let before = items.count
        items.removeAll { $0.record.id == recordID && $0.targetAthleteId == targetAthleteId }
        if items.count != before {
            savePendingUploads(items)
        }
    }

    private func loadPendingDeletes() -> [String] {
        queueLock.lock()
        defer { queueLock.unlock() }
        return UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? []
    }

    private func savePendingDeletes(_ ids: [String]) {
        queueLock.lock()
        defer { queueLock.unlock() }
        UserDefaults.standard.set(ids, forKey: pendingDeletesKey)
    }

    private func enqueuePendingDelete(recordIDString: String) {
        var ids = loadPendingDeletes()
        if !ids.contains(recordIDString) {
            ids.append(recordIDString)
            savePendingDeletes(ids)
        }
    }

    private func removePendingDelete(recordIDString: String) {
        var ids = loadPendingDeletes()
        let before = ids.count
        ids.removeAll { $0 == recordIDString }
        if ids.count != before {
            savePendingDeletes(ids)
        }
    }
}
