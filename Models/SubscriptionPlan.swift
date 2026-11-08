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
        case .pro:  return "¥200 / 月"
        case .manager: return "¥500 / 月"
        case .team: return "¥1,000 / 月"
        case .max:  return "¥3,000 / 月"
        case .organization: return "廃止"
        }
    }

    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro:  return "ForceCurveやPM5最大4台同時制御、全国潮位任意選択など本格的な機能を開放"
        case .manager: return "指導者向け機能。Pro機能に加えてPM5最大10台接続や記録共有を開放"
        case .team: return "高校部活やサークル向け。最大30名の部員を一元管理し、マネージャー1名に権限共有"
        case .max:  return "顧問・監督・強豪校向け最上位。最大100名管理、複数指導者体制（管理3名/共有3名）、レースビュー、CSV出力"
        case .organization: return "最大5人に「マネージャープラン」を共有、7人を管理者として指定、最大200人をメンバーとして追加、AIと対話型の分析機能"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return ["潮汐情報の確認", "GPSレート計", "PM5との1:1接続"]
        case .pro:
            return ["ForceCurveの表示", "全国潮位の任意選択", "PM5最大4台同時制御", "ゴーストレース機能"]
        case .manager:
            return ["Proプランの全機能", "PM5最大10台同時接続", "記録共有機能"]
        case .team:
            return ["メンバー管理 (最大30名)", "「マネージャープラン」を1名に共有", "チーム内データ集約"]
        case .max:
            return ["【顧問・管理者向け最上位】", "メンバー管理 (最大100名)", "「マネージャープラン」を3名に共有", "管理者を最大3名指定", "レースビュー (エルゴ競走モード)", "練習ログのCSVエクスポート"]
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

    /// Pro以上で複数PM5制御（最大4台、Manager以上は最大10台）を解放
    var hasMultiPM5Control: Bool {
        return isAtLeast(.pro)
    }

    /// プランに応じたPM5最大同時接続台数
    var maxPM5Connections: Int {
        switch self {
        case .free:
            return 1
        case .pro:
            return 4
        default:
            return 10
        }
    }

    /// Manager以上でマネージャーモード（記録共有等）を解放
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
        case .max: return 100
        case .organization: return 200
        default: return 0
        }
    }

    /// マネージャープラン共有可能枠
    var managerShareLimit: Int {
        switch self {
        case .team: return 1
        case .max: return 3
        case .organization: return 5
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
