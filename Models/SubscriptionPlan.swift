import Foundation

/// サブスクリプションプラン（free < pro < team < max の順に権限上位）
enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free, pro, team, max

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .free: return "RowPilot Free"
        case .pro:  return "RowPilot Pro"
        case .team: return "RowPilot Team"
        case .max:  return "RowPilot MAX"
        }
    }

    var priceString: String {
        switch self {
        case .free: return "無料 (Free)"
        case .pro:  return "¥980 / 月"
        case .team: return "¥4,980 / 月"
        case .max:  return "¥7,500 / 月"
        }
    }

    var description: String {
        switch self {
        case .free: return "基本機能(潮汐確認、GPSレート計、PM5と1:1接続など)"
        case .pro:  return "ForceCurveやStrava同期などプロ向けの機能を開放"
        case .team: return "PM5複数台接続＋最大3人のメンバーにプランを共有可能"
        case .max:  return "最大5人のメンバーにプラン共有可能。CSV出力、レースビュー等を開放"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return ["潮汐情報の確認", "GPSレート計", "PM5との1:1接続"]
        case .pro:
            return ["ForceCurveの表示", "Stravaとの同期", "ゴーストレース機能"]
        case .team:
            return ["PM5と複数台接続機能", "リアルタイム一斉トレーニング", "最大3名のメンバーとプランを共有"]
        case .max:
            return ["CSV形式出力", "レースビュー開放", "高度なアナリティクス", "最大5名のメンバーとプランを共有"]
        }
    }

    // MARK: - 権限レベル（上位は下位をすべて含む）

    var level: Int {
        switch self {
        case .free: return 0
        case .pro:  return 1
        case .team: return 2
        case .max:  return 3
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

    /// Team以上でマネージャーモード（PM5複数台接続）を解放
    var hasManagerMode: Bool {
        return isAtLeast(.team)
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
