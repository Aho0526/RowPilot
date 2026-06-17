import Foundation

struct Team: Codable, Identifiable {
    let id: String
    let name: String
    let plan: String
    let invite_code: String
    let owner_id: String
    let created_at: Int
}
