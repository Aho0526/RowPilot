import Foundation

/// サブスクリプションプラン（free < pro < manager < team < max < organization の順に権限上位）
enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free, pro, manager, team, max, organization

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .free: return "RowPilot Free"
        case .pro:  return "RowPilot Pro"
        case .manager: return "RowPilot Manager"
        case .team: return "RowPilot Team"
        case .max:  return "RowPilot MAX"
        case .organization: return "RowPilot Organization"
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
        }
    }

    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro:  return "ForceCurveやStrava同期などプロ向けの機能を開放"
        case .manager: return "個人向け上位機能(Pro機能に加えてマネージャー機能を開放)"
        case .team: return "1人に「マネージャープラン」を共有、30人のメンバーをまとめて管理、AIとテンプレート型の分析機能(準備中)"
        case .max:  return "3人に「マネージャープラン」を共有、3人を管理者に指定、最大50人をメンバー化、AIと対話型の分析機能(準備中)"
        case .organization: return "最大5人に「マネージャープラン」を共有、7人を管理者として指定、最大200人をメンバーとして追加、AIと対話型の分析機能"
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
            return ["「マネージャープラン」を1人に共有", "30人のメンバーをまとめて管理", "AIとテンプレート型の分析機能 (準備中)"]
        case .max:
            return ["「マネージャープラン」を3人に共有", "3人を管理者に指定", "最大50人をメンバー化", "AIと対話型の分析機能 (準備中)"]
        case .organization:
            return ["「マネージャープラン」を最大5人に共有", "7人を管理者として指定", "最大200人をメンバーとして追加", "AIと対話型の分析機能"]
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

    /// チーム機能が利用可能か（Team以上）
    var hasTeamFeature: Bool {
        return isAtLeast(.team)
    }

    /// チームメンバーの上限数
    var teamMemberLimit: Int {
        switch self {
        case .team: return 30
        case .max: return 50
        case .organization: return 200
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
        }
    }
}
