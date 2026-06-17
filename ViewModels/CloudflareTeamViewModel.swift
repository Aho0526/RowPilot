import Foundation
import Combine

@MainActor
class CloudflareTeamViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var members: [CloudflareUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    init() {
        print("▶ init Cloudflare VM")
    }
    
    var myTeam: Team? {
        let myId = SubscriptionManager.shared.myUserRecordId
        return teams.first { $0.owner_id == myId }
    }
    
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
                let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
                errorMessage = "Delete Error \(httpResponse.statusCode): \(errStr)"
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
        
        // チーム作成用の各種パラメータを生成
        let teamID = "team_" + UUID().uuidString.prefix(8).lowercased()
        
        // 6桁の招待コード（英大文字 + 数字）をランダム生成
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let inviteCode = String((0..<6).map { _ in alphabet.randomElement()! })
        
        let ownerID = SubscriptionManager.shared.myUserRecordId
        let createdAt = Int(Date().timeIntervalSince1970)
        let plan = "team" // デフォルトプラン
        
        let body: [String: Any] = [
            "id": teamID,
            "name": name,
            "plan": plan,
            "invite_code": inviteCode,
            "owner_id": ownerID,
            "created_at": createdAt
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print("▶ createTeam raw response:", String(data: data, encoding: .utf8) ?? "")
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "HTTP Error: \(httpResponse.statusCode)"
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
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users?team_id=\(teamID)"
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
    
    func createMember(userID: String, displayName: String, teamID: String, role: String, entitlement: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/create"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": userID,
            "display_name": displayName,
            "team_id": teamID,
            "role": role,
            "entitlement": entitlement,
            "created_at": Int(Date().timeIntervalSince1970)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMembers(teamID: teamID)
                return true
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
                self.errorMessage = "Create User Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func deleteMember(userID: String, teamID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users?id=\(userID)"
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
                let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
                self.errorMessage = "Delete Member Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func updateMemberRole(userID: String, role: String, teamID: String) async -> Bool {
        let urlString = "https://rowpilot-api.rowpilot-jp.workers.dev/users/role"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": userID,
            "role": role
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await fetchMembers(teamID: teamID)
                return true
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
                self.errorMessage = "Update Role Error: \(errStr)"
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
