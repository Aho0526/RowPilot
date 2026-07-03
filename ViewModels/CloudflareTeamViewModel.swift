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
    
    func fetchTeams() async {
        print("▶ fetchTeams ENTER")
        isLoading = true
        errorMessage = nil
        
        print("▶ fetchTeams called")
        
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            print("Error: Invalid URL")
            isLoading = false
            return
        }
        print("▶ url:", url)
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            print("▶ raw response:", String(data: data, encoding: .utf8) ?? "")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                print("Error: Invalid response")
                isLoading = false
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                print("HTTP Error: \(httpResponse.statusCode)")
                isLoading = false
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decodedTeams = try decoder.decode([Team].self, from: data)
                self.teams = decodedTeams
                print("▶ JSON Decode Success: Teams loaded:", decodedTeams.count)
            } catch {
                print("▶ JSON Decode Failure:", error)
                self.errorMessage = "Decode Error: \(error.localizedDescription)"
            }
            
        } catch {
            print("Network Error:", error)
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchMyTeam() async {
        let userID = SubscriptionManager.shared.myUserRecordId
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/\(userID)/team"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
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
                
                // Cloudflare D1側でmanagerロールであり、且つチームが停止中でない場合にのみManager権限を有効化
                let isSuspended = decodedTeam.scheduled_for_deletion_at != nil
                let isManager = (self.myRole?.lowercased() == "manager") && !isSuspended
                SubscriptionManager.shared.setCloudflareManager(isManager)
            } else {
                self.myTeam = nil
                self.myRole = nil
                SubscriptionManager.shared.setCloudflareManager(false)
            }
        } catch {
            print("Fetch My Team Error:", error)
            self.myTeam = nil
            self.myRole = nil
            // ネットワークエラー等の場合はキャッシュ状態を維持するため、上書きしない
        }
    }
    
    func deleteTeam(teamID: String) async {
        isLoading = true
        errorMessage = nil
        
        // 削除エンドポイント。/teams/delete に変更してみるか、元のままか。
        // エラー詳細を取得して errorMessage に入れる。
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams?id=\(teamID)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errStr = cleanErrorMessage(from: data, fallback: "Unknown Error")
                errorMessage = "Delete Error (\(httpResponse.statusCode)): \(errStr)"
                isLoading = false
                return
            }
            
            // Re-fetch after delete
            await fetchTeams()
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
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
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": newName]
        
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
        errorMessage = nil
        
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/create"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let ownerID = SubscriptionManager.shared.myUserRecordId
        let plan = SubscriptionManager.shared.currentPlan.rawValue
        
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
                errorMessage = "HTTP Error: \(httpResponse.statusCode)\n\(errStr)"
                isLoading = false
                return
            }
            
            // 作成成功後に再フェッチ
            await fetchTeams()
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Users Management
    
    func fetchMembers(teamID: String) async {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
                if let team = self.myTeam {
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
    
    func deleteMember(userID: String, teamID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members/\(userID)"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMembers(teamID: teamID)
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
    
    func updateMemberRole(userID: String, role: String, teamID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/teams/\(teamID)/members/\(userID)/role"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "role": role
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
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
    
    private func cleanErrorMessage(from data: Data, fallback: String) -> String {
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
