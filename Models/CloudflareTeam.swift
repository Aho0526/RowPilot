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

extension Team {
    /// 猶予期間（30日間）が終了し、チームがアーカイブ（閲覧のみ）されているか
    var isSuspended: Bool {
        guard let scheduledDeletion = scheduled_for_deletion_at else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // サーバーが返す日付フォーマットに対応するため、複数のフォーマットでトライ
        var deletionDate = formatter.date(from: scheduledDeletion)
        if deletionDate == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            deletionDate = fallbackFormatter.date(from: scheduledDeletion)
        }
        
        guard let date = deletionDate else { return false }
        
        // 猶予期間は30日間（サーバー側で設定されたscheduled_for_deletion_atの日時そのものがアーカイブ開始日となる）
        return Date() > date
    }
    
    /// 猶予期間（制限なしで利用可能）が終了し、アーカイブ（機能制限開始）される日
    var gracePeriodEndDate: Date? {
        guard let scheduledDeletion = scheduled_for_deletion_at else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var deletionDate = formatter.date(from: scheduledDeletion)
        if deletionDate == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            deletionDate = fallbackFormatter.date(from: scheduledDeletion)
        }
        
        return deletionDate
    }
}

