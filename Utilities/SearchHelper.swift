import Foundation
import SwiftUI

/// アプリ機能の遷移先
enum AppDestination: Hashable {
    case riggingManager
    case subscription
    case terms
    case about
    case credits
    case sosSettings
    case teamMaxManager
}

/// アプリ機能のアクション
enum AppFunctionAction: Hashable {
    case changeTab(Int)
    case navigateToView(AppDestination)
}

/// 検索可能なアプリ機能アイテム
struct AppFunctionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: String
    let tags: [String]
    let iconName: String
    let action: AppFunctionAction
}

class SearchHelper {
    static let shared = SearchHelper()
    
    private init() {}
    
    /// アプリの全機能アイテムを取得する（ローカライズ対応）
    func getFunctionItems(isJA: Bool) -> [AppFunctionItem] {
        return [
            AppFunctionItem(
                id: "start_rowing",
                title: isJA ? "計測開始" : "Start Rowing",
                description: isJA ? "水上でのローイング計測を開始します" : "Start tracking your rowing sessions on the water.",
                category: isJA ? "計測" : "Tracking",
                tags: ["rowing", "start", "water", "水上", "計測", "開始", "練習", "row", "漕ぐ", "アクティビティ"],
                iconName: "figure.outdoor.rowing",
                action: .changeTab(2)
            ),
            AppFunctionItem(
                id: "erg_practice",
                title: isJA ? "エルゴ計測" : "Erg Practice",
                description: isJA ? "Concept2 PM5エルゴと接続して練習を開始します" : "Connect with PM5 monitor to start erg workouts.",
                category: isJA ? "計測" : "Tracking",
                tags: ["erg", "pm5", "concept2", "practice", "エルゴ", "屋内", "接続", "練習", "インドア", "モニター"],
                iconName: "figure.rower",
                action: .changeTab(3)
            ),
            AppFunctionItem(
                id: "tide",
                title: isJA ? "潮位情報" : "Tide Info",
                description: isJA ? "最寄りの潮汐情報・グラフを確認します" : "Check tide tables and graph for your nearest station.",
                category: isJA ? "ツール" : "Tools",
                tags: ["tide", "station", "water", "潮位", "潮汐", "海", "川", "グラフ", "潮", "満ち引き"],
                iconName: "water.waves",
                action: .changeTab(1)
            ),
            AppFunctionItem(
                id: "rigging",
                title: isJA ? "リギング設定" : "Rigging & Oars",
                description: isJA ? "艇の仕様やオールのスパン、ピッチを設定します" : "Configure boat parameters and oar dimensions.",
                category: isJA ? "設定" : "Settings",
                tags: ["rigging", "oar", "span", "boat", "リギング", "オール", "艇", "設定", "ボート", "スパン", "ピッチ"],
                iconName: "pencil.and.ruler.fill",
                action: .navigateToView(.riggingManager)
            ),
            AppFunctionItem(
                id: "subscription",
                title: isJA ? "プレミアムプラン" : "RowPilot Premium",
                description: isJA ? "RowPilot Premiumの機能を確認・アップグレードします" : "Unlock all premium features including teammate sharing.",
                category: isJA ? "アカウント" : "Account",
                tags: ["subscription", "premium", "plan", "upgrade", "サブスク", "有料", "プラン", "アップグレード", "チーム", "支払い", "購入"],
                iconName: "crown.fill",
                action: .navigateToView(.subscription)
            ),
            AppFunctionItem(
                id: "terms",
                title: isJA ? "利用規約" : "Terms of Service",
                description: isJA ? "RowPilotの利用規約を表示します" : "Read the RowPilot terms of service agreements.",
                category: isJA ? "情報" : "Information",
                tags: ["terms", "service", "rule", "law", "規約", "利用規約", "ルール", "ポリシー", "法律", "合意"],
                iconName: "doc.text.fill",
                action: .navigateToView(.terms)
            ),
            AppFunctionItem(
                id: "credits",
                title: isJA ? "クレジット" : "Credits",
                description: isJA ? "開発者やオープンソースライブラリのクレジットを表示します" : "View credits for libraries and development team.",
                category: isJA ? "情報" : "Information",
                tags: ["credit", "thank", "developer", "oss", "ライブラリ", "開発", "クレジット", "感謝", "謝辞", "オープンソース"],
                iconName: "person.2.fill",
                action: .navigateToView(.credits)
            ),
            AppFunctionItem(
                id: "about",
                title: isJA ? "アプリについて" : "About RowPilot",
                description: isJA ? "アプリのバージョン情報や開発元を表示します" : "View application version and developer info.",
                category: isJA ? "情報" : "Information",
                tags: ["about", "version", "app", "アプリ", "バージョン", "情報", "概要", "ビルド"],
                iconName: "info.circle.fill",
                action: .navigateToView(.about)
            ),
            AppFunctionItem(
                id: "sos",
                title: isJA ? "緊急連絡先 (SOS)" : "SOS Settings",
                description: isJA ? "緊急時のSOS送信先や連絡先を設定します" : "Configure contacts for emergency SOS trigger alerts.",
                category: isJA ? "設定" : "Settings",
                tags: ["sos", "contact", "emergency", "help", "緊急", "連絡先", "遭難", "救助", "安全"],
                iconName: "sos",
                action: .navigateToView(.sosSettings)
            ),
            AppFunctionItem(
                id: "teammates",
                title: isJA ? "メンバー管理" : "Manage Teammates",
                description: isJA ? "チーム共有用のメンバーリストを編集・管理します" : "Manage and edit names in your teammates database.",
                category: isJA ? "設定" : "Settings",
                tags: ["teammate", "member", "share", "team", "メンバー", "チーム", "管理", "共有", "共有名", "名前リスト"],
                iconName: "person.3.sequence.fill",
                action: .navigateToView(.teamMaxManager)
            )
        ]
    }
}
