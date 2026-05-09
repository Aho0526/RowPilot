import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free, pro, manager, team, max
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .free: return "RowPilot Free"
        case .pro: return "RowPilot Pro"
        case .manager: return "RowPilot Manager"
        case .team: return "RowPilot Team"
        case .max: return "RowPilot MAX"
        }
    }
    
    var priceString: String {
        switch self {
        case .free: return "無料 (Free)"
        case .pro: return "¥980"
        case .manager: return "¥1,480"
        case .team: return "¥4,980"
        case .max: return "¥7,500"
        }
    }
    
    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro: return "ForceCurveやStrava同期などプロ向けの機能を開放"
        case .manager: return "PM5と複数台接続出来る世界初の機能を開放。1人のマネ向け"
        case .team: return "複数人にマネージャーの機能を提供"
        case .max: return "Team機能に加え、記録のCSV形式出力、レースビュー等を開放"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["潮汐情報の確認", "GPSレート計", "PM5との1:1接続"]
        case .pro:
            return ["ForceCurveの表示", "Stravaとの同期", "記録の拡張保存"]
        case .manager:
            return ["PM5と複数台接続機能",]
        case .team:
            return ["チーム管理", "複数人にマネージャーモードを共有", "チーム間でのデータ共有"]
        case .max:
            return ["CSV形式出力", "レースビュー開放", "高度なアナリティクス", "団体向けサポート"]
        }
    }
}
