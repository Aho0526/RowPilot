import Foundation

/// サブスクリプションプラン（free < pro < team < max の順に権限上位）
enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free, pro, manager, team, max, organization, enterprise

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .free: return "RowPilot Free"
        case .pro:  return "RowPilot Pro"
        case .manager: return "RowPilot Manager"
        case .team: return "RowPilot Team"
        case .max:  return "RowPilot MAX"
        case .organization: return "RowPilot Organization"
        case .enterprise: return "RowPilot Enterprise"
        }
    }

    var priceString: String {
        switch self {
        case .free: return "無料 (Free)"
        case .pro:  return "¥980 / 月"
        case .manager: return "¥2,980 / 月"
        case .team: return "¥4,980 / 月"
        case .max:  return "¥7,500 / 月"
        case .organization: return "¥15,000 / 月"
        case .enterprise: return "要問い合わせ"
        }
    }

    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro:  return "ForceCurveやStrava同期などプロ向けの機能を開放"
        case .manager: return "個人向け上位機能(Pro機能に加えてマネージャー機能を開放)"
        case .team: return "PM5複数台接続＋最大3人のメンバーにプランを共有可能"
        case .max:  return "最大5人のメンバーにプラン共有可能。CSV出力、レースビュー等を開放"
        case .organization: return "最大10人のメンバーにプラン共有可能。チーム共有最大200名、CSV出力、レースビュー等を開放"
        case .enterprise: return "大規模導入・独自カスタマイズなど、チームに最適化されたカスタムプラン"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return ["潮汐情報の確認", "GPSレート計", "PM5との1:1接続"]
        case .pro:
            return ["ForceCurveの表示", "Stravaとの同期", "ゴーストレース機能"]
        case .manager:
            return ["Proプランの全機能", "PM5複数台接続機能", "マネージャー機能"]
        case .team:
            return ["PM5と複数台接続機能", "リアルタイム一斉トレーニング", "最大3名のメンバーとプランを共有"]
        case .max:
            return ["CSV形式出力", "レースビュー開放", "高度なアナリティクス", "最大5名のメンバーとプランを共有"]
        case .organization:
            return ["CSV形式出力", "レースビュー開放", "高度なアナリティクス", "最大10名のメンバーとプランを共有", "最大200名のメンバーとチーム共有"]
        case .enterprise:
            return ["エンタープライズサポート", "チーム人数無制限", "独自カスタマイズ", "専用クラウド・SLA保証"]
        }
    }

    // MARK: - 権限レベル（上位は下位をすべて含む）

    var level: Int {
        switch self {
        case .free: return 0
        case .pro:  return 1
        case .manager: return 2
        case .team: return 3
        case .max:  return 4
        case .organization: return 5
        case .enterprise: return 6
        }
    }

    /// 指定プラン以上かどうか
    func isAtLeast(_ plan: SubscriptionPlan) -> Bool {
        return self.level >= plan.level
    }

    // MARK: - Feature Flags

    /// Pro以上でForce Curveを解放
    var hasForceCurve: Bool {
        return isAtLeast(.pro)
    }

    /// Manager以上でマネージャーモード（PM5複数台接続）を解放
    var hasManagerMode: Bool {
        return isAtLeast(.manager)
    }

    /// MAXプラン以上でレースビューを解放
    var hasRaceView: Bool {
        return isAtLeast(.max)
    }

    /// MAXプラン以上でCSV形式出力を解放
    var hasCSVExport: Bool {
        return isAtLeast(.max)
    }

    /// チーム機能が利用可能か（Team/MAX/Enterpriseのみ）
    var hasTeamFeature: Bool {
        return isAtLeast(.team)
    }

    /// チームメンバーの上限数
    var teamMemberLimit: Int {
        switch self {
        case .team: return 30
        case .max: return 80
        case .organization: return 200
        case .enterprise: return 9999
        default: return 0
        }
    }

    /// 対応するApp StoreのプロダクトID
    var productId: String? {
        switch self {
        case .free: return nil
        case .pro: return "rowpilot_pro"
        case .manager: return "rowpilot_manager"
        case .team: return "rowpilot_team"
        case .max: return "rowpilot_max"
        case .organization: return "rowpilot_org"
        case .enterprise: return nil
        }
    }
}
