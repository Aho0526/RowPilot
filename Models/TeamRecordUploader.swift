import Foundation
// CloudKit依存を削除済み（Cloudflare移行中）

/// メンバー側：練習記録のアップロードは現在無効化（Cloudflare移行中）
class TeamRecordUploader {
    static let shared = TeamRecordUploader()

    private init() {}

    // MARK: - ワークアウトのアップロード

    func uploadIfNeeded(record: RowingRecord) {
        if !SettingsManager.shared.settings.autoUploadToTeam { return }
        uploadToTeam(record: record)
    }
    
    // 手動でアップロードを実行する
    func uploadManual(record: RowingRecord) {
        uploadToTeam(record: record)
    }

    private func uploadToTeam(record: RowingRecord) {
        Task {
            let userID = SubscriptionManager.shared.myUserRecordId
            guard !userID.isEmpty else { return }
            
            // 1. 所属チームを取得
            let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/\(userID)/team"
            guard let url = URL(string: urlString) else { return }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    if responseString == "null" { return }
                    
                    let decodedTeam = try JSONDecoder().decode(Team.self, from: data)
                    
                    // 2. 所属チームがあれば CloudflareWorkoutRecord を作成してアップロード
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    let isOutdoor = record.startLocation != nil || (record.routePoints != nil && !record.routePoints!.isEmpty)
                    let workoutType = isOutdoor ? "outdoor" : "indoor"
                    
                    var crewInfoJsonString: String? = nil
                    if let crewInfo = record.crewInfo {
                        if let jsonData = try? JSONEncoder().encode(crewInfo) {
                            crewInfoJsonString = String(data: jsonData, encoding: .utf8)
                        }
                    }
                    
                    let workout = CloudflareWorkoutRecord(
                        id: record.id.uuidString,
                        athlete_id: userID,
                        recorded_by_id: userID,
                        team_id: decodedTeam.id,
                        type: workoutType,
                        format: "time",
                        distance_m: Int(record.distance),
                        duration_sec: Int(record.duration),
                        split_500m_sec: Int(record.averagePace),
                        stroke_rate: record.averageSPM,
                        boat_type: record.crewInfo?.boatType.rawValue ?? "1x",
                        recorded_on: formatter.string(from: record.date),
                        created_at: formatter.string(from: Date()),
                        athlete_name: nil,
                        crew_info: crewInfoJsonString
                    )
                    
                    let saveUrlString = "https://rowpilot-api.rowpilot-jp.workers.dev/workouts"
                    guard let saveUrl = URL(string: saveUrlString) else { return }
                    
                    var request = URLRequest(url: saveUrl)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(workout)
                    
                    let (saveData, saveResponse) = try await URLSession.shared.data(for: request)
                    if let saveHttpResponse = saveResponse as? HTTPURLResponse, (200...299).contains(saveHttpResponse.statusCode) {
                        print("TeamRecordUploader: Uploaded workout successfully to Cloudflare D1.")
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TeamWorkoutUploadSuccess"),
                                object: nil,
                                userInfo: ["message": "記録が正常に共有されました"]
                            )
                        }
                    } else {
                        let responseString = String(data: saveData, encoding: .utf8) ?? ""
                        print("TeamRecordUploader: Failed to upload workout. Response: \(responseString)")
                        
                        var errorMsg = "記録の共有に失敗しました"
                        if let dict = try? JSONSerialization.jsonObject(with: saveData, options: []) as? [String: Any],
                           let serverError = dict["error"] as? String {
                            errorMsg = "記録の共有に失敗しました: \(serverError)"
                        }
                        
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TeamWorkoutUploadFailed"),
                                object: nil,
                                userInfo: ["error": errorMsg]
                            )
                        }
                    }
                }
            } catch {
                print("TeamRecordUploader: Error \(error)")
            }
        }
    }

    // D1からワークアウトを削除する
    func deleteFromTeam(recordID: UUID) {
        Task {
            let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/workouts/\(recordID.uuidString)"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    print("TeamRecordUploader: Deleted workout successfully from Cloudflare D1.")
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    print("TeamRecordUploader: Failed to delete workout. Response: \(responseString)")
                }
            } catch {
                print("TeamRecordUploader: Error deleting workout: \(error)")
            }
        }
    }
}
