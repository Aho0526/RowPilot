import Foundation

struct Team: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let plan: String
    let invite_code: String
    let owner_id: String
    let created_at: String
    var my_role: String? // Added to support GET /users/:id/team response
    
    let scheduled_for_deletion_at: String?
    let members_scheduled_for_deletion_at: String?
}

