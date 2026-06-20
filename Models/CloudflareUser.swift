import Foundation

struct CloudflareUser: Codable, Identifiable, Hashable {
    let id: String
    let display_name: String
    let email: String?
    let is_ghost: Int
    let role: String // admin, manager, athlete
    let entitlement: String // free, pro, manager
    let created_at: String
}
