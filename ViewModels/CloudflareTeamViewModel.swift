import Foundation
import Combine

@MainActor
class CloudflareTeamViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var members: [CloudflareUser] = []
    @Published var teamWorkouts: [CloudflareWorkoutRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("▶ init Cloudflare VM")
        NotificationCenter.default.publisher(for: NSNotification.Name("D1TeamPlanSynced"))
            .sink { [weak self] _ in
                Task {
                    await self?.fetchMyTeam()
                }
            }
            .store(in: &cancellables)
    }
    
    @Published var myTeam: Team? = nil
    @Published var myRole: String? = nil
    
    private func ensureValidToken() async -> String {
        let userID = SubscriptionManager.shared.myUserRecordId
        if SubscriptionManager.shared.apiToken.isEmpty && !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await SubscriptionManager.shared.syncTeamPlanWithCloudflare(
                ownerId: userID,
                jws: SubscriptionManager.shared.lastVerifiedJWS
            )
        }
        return SubscriptionManager.shared.apiToken
    }
    
    /// 旧 `GET /teams`（全チーム公開）はサーバー側で廃止済み(H2)。
    /// 互換のため残し、自分のチームの再取得に委譲する。
    func fetchTeams() async {
        await fetchMyTeam()
    }
    
    func fetchMyTeam() async {
        let userID = SubscriptionManager.shared.myUserRecordId
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/\(userID)/team"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        let token = await ensureValidToken()
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    // 返り値が null (所属チームなし) の場合を考慮
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    if responseString == "null" {
                        self.myTeam = nil
                        self.myRole = nil
                        SubscriptionManager.shared.setCloudflareManager(false)
                        return
                    }
                    
                    let decodedTeam = try JSONDecoder().decode(Team.self, from: data)
                    self.myTeam = decodedTeam
                    self.myRole = decodedTeam.my_role
                    print("▶ fetchMyTeam Success: \(decodedTeam.name), role: \(self.myRole ?? "unknown")")
                    
                    // アーカイブ猶予期間（30日間）が終了した場合のみ Manager 権限を停止する
                    let isSuspended = decodedTeam.isSuspended
                    let isManager = (self.myRole?.lowercased() == "manager") && !isSuspended
                    SubscriptionManager.shared.setCloudflareManager(isManager)
                } else if httpResponse.statusCode == 404 {
                    self.myTeam = nil
                    self.myRole = nil
                    SubscriptionManager.shared.setCloudflareManager(false)
                }
            } else {
                // HTTPレスポンスがない場合はネットワークエラーとみなし、状態を維持する
            }
        } catch {
            print("Fetch My Team Error:", error)
            // ネットワークエラー等の場合はキャッシュ状態を維持するため、上書きしない
        }
    }
    
    func deleteTeam(teamID: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        
        // 削除エンドポイント。/teams/delete に変更してみるか、元のままか。
        // エラー詳細を取得して errorMessage に入れる。
        let ownerID = SubscriptionManager.shared.myUserRecordId
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams?id=\(teamID)&requester_id=\(ownerID)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "DELETE"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                errorMessage = "Delete Error (\(httpResponse.statusCode)): \(errStr)"
                return
            }
            
            self.myTeam = nil
            self.myRole = nil
            self.members = []
            self.teamWorkouts = []
            SubscriptionManager.shared.setCloudflareManager(false)
            // Re-fetch after delete
            await fetchTeams()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func updateTeamName(teamID: String, newName: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return false
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "name": newName,
            "requester_id": SubscriptionManager.shared.myUserRecordId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMyTeam()
                isLoading = false
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                errorMessage = "Update Team Name Error: \(errStr)"
                isLoading = false
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func createTeam(name: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/create"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let ownerID = SubscriptionManager.shared.myUserRecordId
        guard !ownerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "ユーザー情報の取得中です。少し待ってから再度お試しください。"
            return
        }
        var plan = SubscriptionManager.shared.currentPlan.rawValue
        if let stored = UserDefaults.standard.string(forKey: "userSubscriptionPlan"),
           let p1 = SubscriptionPlan(rawValue: plan),
           let p2 = SubscriptionPlan(rawValue: stored),
           p2.level > p1.level {
            plan = stored
        }
        
        let displayName = SettingsManager.shared.settings.sharingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayName.isEmpty {
            _ = await createUser(
                userID: ownerID,
                displayName: displayName,
                email: nil,
                isGhost: 0,
                entitlement: plan
            )
            errorMessage = nil
        }
        
        let body: [String: Any] = [
            "name": name,
            "plan": plan,
            "owner_id": ownerID
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
            
            print("=== createTeam Request ===")
            print("URL: \(urlString)")
            print("Method: \(request.httpMethod ?? "UNKNOWN")")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Body:\n\(jsonString)")
            }
            print("==========================")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("=== createTeam Response ===")
            if let httpResponse = response as? HTTPURLResponse {
                print("Status: \(httpResponse.statusCode)")
            }
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("Response Body:\n\(responseString)")
            print("===========================")
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errStr = cleanErrorMessage(from: data, fallback: responseString)
                errorMessage = errStr
                return
            }
            
            // 作成成功後に再フェッチ
            await fetchTeams()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Users Management
    
    func fetchMembers(teamID: String) async {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decoded = try JSONDecoder().decode([CloudflareUser].self, from: data)
                self.members = decoded
            }
        } catch {
            print("Fetch Members Error:", error)
        }
    }
    
    func createUser(userID: String, displayName: String, email: String?, isGhost: Int, entitlement: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        let token = await ensureValidToken()
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "id": userID,
            "display_name": displayName,
            "is_ghost": isGhost,
            "entitlement": entitlement,
            "created_at": Int(Date().timeIntervalSince1970)
        ]
        if let email = email {
            body["email"] = email
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
            
            print("=== createUser Request ===")
            print("Method: \(request.httpMethod ?? "UNKNOWN")")
            print("Sending userID: \(userID)")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Body:\n\(jsonString)")
            }
            print("==========================")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("=== createUser Response ===")
            if let httpResponse = response as? HTTPURLResponse {
                print("Status: \(httpResponse.statusCode)")
            }
            print("Response Body:\n\(responseString)")
            print("===========================")
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: responseString)
                self.errorMessage = "Create User Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func joinTeam(inviteCode: String, userID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/join"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        let token = await ensureValidToken()
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "invite_code": inviteCode,
            "user_id": userID
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                // ★ fetchMyTeam()を先に呼び、myTeam/myRoleを正しく更新する
                await fetchMyTeam()
                if let team = self.myTeam, self.myRole != "pending" {
                    await fetchMembers(teamID: team.id)
                }
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                self.errorMessage = "Join Team Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// チームの最新状態をポーリング（承認待ちユーザーが承認されたかを確認するために使用）
    func refreshMyTeamStatus() async {
        await fetchMyTeam()
        if let team = self.myTeam, myRole != "pending" {
            await fetchMembers(teamID: team.id)
            await fetchTeamWorkouts(teamID: team.id)
        }
    }
    
    func deleteMember(userID: String, teamID: String, deleteRecords: Bool = false) async -> Bool {
        let requesterId = SubscriptionManager.shared.myUserRecordId
        var urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members/\(userID)?requester_id=\(requesterId)"
        if deleteRecords {
            urlString += "&delete_records=1"
        }
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "DELETE"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMembers(teamID: teamID)
                if deleteRecords {
                    await fetchTeamWorkouts(teamID: teamID)
                }
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                self.errorMessage = "Delete Member Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func leaveTeam(teamID: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let myID = SubscriptionManager.shared.myUserRecordId
        let success = await deleteMember(userID: myID, teamID: teamID, deleteRecords: false)
        if success {
            self.myTeam = nil
            self.myRole = nil
            self.members = []
            self.teamWorkouts = []
            SubscriptionManager.shared.setCloudflareManager(false)
            NotificationCenter.default.post(name: NSNotification.Name("TeamJoinStatusChanged"), object: nil)
        }
        return success
    }
    
    func updateMemberRole(userID: String, role: String, teamID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members/\(userID)/role"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "role": role,
            "requester_id": SubscriptionManager.shared.myUserRecordId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMembers(teamID: teamID)
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                self.errorMessage = "Update Role Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Workouts
    
    func fetchTeamWorkouts(teamID: String) async {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/workouts"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decoded = try JSONDecoder().decode([CloudflareWorkoutRecord].self, from: data)
                self.teamWorkouts = decoded
                print("▶ fetchTeamWorkouts Success: loaded \(decoded.count) workouts")
            } else {
                print("▶ fetchTeamWorkouts Error: HTTP Status mismatch")
            }
        } catch {
            print("Fetch Workouts Error:", error)
        }
    }
    
    func saveWorkout(_ record: CloudflareWorkoutRecord) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/workouts"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(record)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("▶ saveWorkout Success")
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                self.errorMessage = "Save Workout Error: \(errStr)"
                print("▶ saveWorkout Error: \(errStr)")
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("▶ saveWorkout Error: \(error)")
            return false
        }
    }

    func deleteWorkout(recordID: String, teamID: String) async -> Bool {
        let requesterId = SubscriptionManager.shared.myUserRecordId
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/workouts/\(recordID)?requester_id=\(requesterId)"
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        let token = SubscriptionManager.shared.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = "DELETE"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("▶ deleteWorkout Success")
                // 再取得して一覧を更新
                await fetchTeamWorkouts(teamID: teamID)
                return true
            } else {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                self.errorMessage = "Delete Workout Error: \(errStr)"
                print("▶ deleteWorkout Error: \(errStr)")
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("▶ deleteWorkout Error: \(error)")
            return false
        }
    }
    
    private func cleanErrorMessage(from data: Data, fallback: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
        }
        guard let errStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return fallback
        }
        if errStr.lowercased().contains("<!doctype html") || errStr.lowercased().contains("<html") {
            return "不明なエラーが発生しました。しばらく経ってから再度お試しください。"
        }
        if errStr.count > 300 {
            return "不明なエラーが発生しました。(エラーコードまたはメッセージが長すぎます)"
        }
        return errStr
    }
}
