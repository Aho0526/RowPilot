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
        case .pro: return "¥980 / 月"
        case .manager: return "¥1,480 / 月"
        case .team: return "¥4,980 / 月"
        case .max: return "¥7,500 / 月"
        }
    }
    
    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro: return "ForceCurveやStrava同期などプロ向けの機能を開放"
        case .manager: return "PM5と複数台接続出来る世界初の機能を開放。1人のマネ向け"
        case .team: return "最大3人のメンバーにManagerプランを共有可能。チーム単位で記録を保存"
        case .max: return "最大5人のメンバーにManagerプランを共有可能。CSV出力、レースビュー等を開放"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["潮汐情報の確認", "GPSレート計", "PM5との1:1接続"]
        case .pro:
            return ["ForceCurveの表示", "Stravaとの同期", "記録の拡張保存"]
        case .manager:
            return ["PM5と複数台接続機能"]
        case .team:
            return ["チーム管理", "最大3名のメンバーとManagerPlanを共有", "チーム間でのデータ共有"]
        case .max:
            return ["CSV形式出力", "レースビュー開放", "高度なアナリティクス", "最大5名のメンバーとManagerPlanを共有"]
        }
    }
    
    // MARK: - Feature Flags
    
    /// Pro以上のプラン（Pro, Manager, Team, MAX）でForce Curveを解放
    var hasForceCurve: Bool {
        return self != .free
    }
    
    /// Manager以上のプラン（Manager, Team, MAX）でマネージャーモードを解放
    var hasManagerMode: Bool {
        return self == .manager || self == .team || self == .max
    }
    
    /// MAXプランのみでレースビューを解放
    var hasRaceView: Bool {
        return self == .max
    }
    
    /// MAXプランのみでCSV形式出力を解放
    var hasCSVExport: Bool {
        return self == .max
    }
}

