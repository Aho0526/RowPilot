import Foundation
import SwiftUI

enum AppLanguage: String, Codable, CaseIterable {
    case japanese = "日本語"
    case english = "English"
    
    var identifier: String {
        switch self {
        case .japanese: return "ja"
        case .english: return "en"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var language: AppLanguage = .japanese
    
    private var translations: [String: [AppLanguage: String]] = [
        // Navigation / Tabs
        "Home": [.japanese: "ホーム", .english: "Home"],
        "Tide": [.japanese: "潮位", .english: "Tide"],
        "Rowing": [.japanese: "乗艇", .english: "Rowing"],
        "Log": [.japanese: "記録", .english: "Log"],
        "Settings": [.japanese: "設定", .english: "Settings"],
        
        // Home View
        "Good Morning": [.japanese: "おはようございます", .english: "Good Morning"],
        "Good Afternoon": [.japanese: "こんにちは", .english: "Good Afternoon"],
        "Good Evening": [.japanese: "こんばんは", .english: "Good Evening"],
        "Start Rowing": [.japanese: "Start", .english: "Start Rowing"],
        "Plan your session": [.japanese: "練習計画を立てる", .english: "Plan your session"],
        
        // Tide View
        "Tide Graph": [.japanese: "潮位グラフ", .english: "Tide Graph"],
        "High": [.japanese: "満潮", .english: "High"],
        "Low": [.japanese: "干潮", .english: "Low"],
        
        // MARK: - Settings View
        "Language": [.japanese: "言語", .english: "Language"],
        "Theme": [.japanese: "テーマ設定", .english: "Theme"],
        "Voice Feedback": [.japanese: "音声フィードバック", .english: "Voice Feedback"],
        "Sound Effects": [.japanese: "効果音", .english: "Sound Effects"],
        "Voice Guide": [.japanese: "音声ガイド", .english: "Voice Guide"],
        "Display": [.japanese: "表示設定", .english: "Display"],
        "Show Battery": [.japanese: "バッテリー状態を表示", .english: "Show Battery"],
        "Show GPS Accuracy": [.japanese: "GPS精度を表示", .english: "Show GPS Accuracy"],
        "Show Help Buttons": [.japanese: "ヘルプボタンを表示", .english: "Show Help Buttons"],
        "Measurement": [.japanese: "計測設定", .english: "Measurement"],
        "Auto Start": [.japanese: "動作検出で自動開始", .english: "Auto Start"],
        "Units": [.japanese: "単位", .english: "Units"],
        "Distance": [.japanese: "距離", .english: "Distance"],
        "Speed": [.japanese: "速度", .english: "Speed"],
        "Data Sync": [.japanese: "データ同期", .english: "Data Sync"],
        "Coming Soon": [.japanese: "今後のアップデートで対応予定です", .english: "Coming soon in future updates"],
        "Reset Settings": [.japanese: "設定をリセット", .english: "Reset Settings"],
        "Practice Help": [.japanese: "練習画面のヘルプ", .english: "Practice Help"],
        "Tide Help": [.japanese: "潮位画面のヘルプ", .english: "Tide Help"],
        "RowMode Help": [.japanese: "乗艇画面のヘルプ", .english: "RowMode Help"],
        "Reset Alert Message": [.japanese: "すべての設定をデフォルト値に戻します。この操作は取り消せません。", .english: "Reset all settings to default. This cannot be undone."],
        "Cancel": [.japanese: "キャンセル", .english: "Cancel"],
        "Reset": [.japanese: "リセット", .english: "Reset"],
        "Terms of Service": [.japanese: "利用規約", .english: "Terms of Service"],
        "Credits": [.japanese: "クレジット", .english: "Credits"],
        "Color Theme": [.japanese: "カラーテーマを選択", .english: "Select Color Theme"],
        "SOS Settings": [.japanese: "緊急連絡先設定", .english: "SOS Settings"],
        "Contact Name": [.japanese: "連絡先氏名", .english: "Contact Name"],
        "Phone Number": [.japanese: "電話番号", .english: "Phone Number"],
        "User Name": [.japanese: "使用者の名前", .english: "User Name"],
        "Emergency Contact": [.japanese: "緊急連絡先", .english: "Emergency Contact"],
        "SOS Message Hint": [.japanese: "緊急時に現在地、時刻、バッテリー残量を指定の連絡先へ送信します。", .english: "Sends location, time, and battery level to your emergency contact in case of an emergency."],
        "Location Info": [.japanese: "位置情報", .english: "Location Info"],
        "Battery": [.japanese: "バッテリー", .english: "Battery"],
        "No response. Please check.": [.japanese: "SOS信号が発信されました。確認してください。", .english: "An SOS signal has been sent. Please check."],
        "Map Type": [.japanese: "マップの種類", .english: "Map Type"],
        "Apple Maps": [.japanese: "Apple Maps", .english: "Apple Maps"],
        "Google Maps": [.japanese: "Google Maps", .english: "Google Maps"],
        "Apple Maps & Google Maps": [.japanese: "両方 (Apple & Google)", .english: "Both (Apple & Google)"],
        
        // MARK: - Subscription / Billing
        "RowPilot Premium": [.japanese: "RowPilot プレミアム", .english: "RowPilot Premium"],
        "Unlock all features and power up your rowing.": [.japanese: "すべての機能を開放して、練習をさらに効率的に。", .english: "Unlock all features and power up your rowing."],
        "Upgrade RowPilot": [.japanese: "RowPilotをアップグレード", .english: "Upgrade RowPilot"],
        "Unlock premium features and reach your potential.": [.japanese: "プレミアム機能を開放して、あなたの可能性を引き出しましょう。\n 全てのプランは1度の購入で永続的に使用できます。", .english: "Unlock premium features and reach your potential. \n All plans are available for lifetime use with a single purchase. "],
        "CURRENT PLAN": [.japanese: "現在のプラン", .english: "CURRENT PLAN"],
        "Individual": [.japanese: "個人向け", .english: "Individual"],
        "For Managers": [.japanese: "マネージャー向け", .english: "For Managers"],
        "For Coaches & Teams": [.japanese: "コーチ・団体向け", .english: "For Coaches & Teams"],
        "Subscriptions": [.japanese: "サブスクリプション", .english: "Subscriptions"],
        "Authentication Error": [.japanese: "認証エラー", .english: "Authentication Error"],
        "Confirm your subscription purchase.": [.japanese: "サブスクリプションの購入を確定します。", .english: "Confirm your subscription purchase."],
        "Please authenticate to complete purchase.": [.japanese: "購入を完了するには認証が必要です。", .english: "Please authenticate to complete purchase."],
        "Plan Details": [.japanese: "プラン詳細", .english: "Plan Details"],
        "Purchase": [.japanese: "購入する", .english: "Purchase"],
        "You are currently subscribed to this plan.": [.japanese: "現在このプランを契約中です。", .english: "You are currently subscribed to this plan."],
        "Included Features": [.japanese: "含まれる機能", .english: "Included Features"],
        "Current Plan": [.japanese: "現在のプラン", .english: "Current Plan"],

        // MARK: - Landscape View / Metrics
        "Distance_M": [.japanese: "距離", .english: "Dist"],
        "Time": [.japanese: "時間", .english: "Time"],
        "Pace": [.japanese: "500m ペース", .english: "500m Pace"],
        "SPM": [.japanese: "SPM", .english: "SPM"],
        "Save Record": [.japanese: "記録を保存", .english: "Save Record"],
        "Save Message": [.japanese: "この練習記録を保存しますか？", .english: "Save this session?"],
        "Save": [.japanese: "保存", .english: "Save"],
        "Discard": [.japanese: "破棄", .english: "Discard"],
        "SOS_Press": [.japanese: "長押しで緊急連絡", .english: "Hold for SOS"],
        "SOS_Hold_2s": [.japanese: "2秒間長押し", .english: "Hold for 2s"],
        "SOS_Hold_1_5s": [.japanese: "長押しで緊急連絡", .english: "Hold for SOS"],
        
        "Count": [.japanese: "回数", .english: "Count"],
        "Stop": [.japanese: "停止", .english: "Stop"],
        
        // MARK: - Portrait View
        "Rowing Mode": [.japanese: "乗艇モード", .english: "Rowing Mode"],
        "Waiting for GPS": [.japanese: "GPS測位中...", .english: "Waiting for GPS..."],
        "Ready": [.japanese: "準備完了", .english: "Ready"],
        
        "Record Detail": [.japanese: "記録詳細", .english: "Record Detail"],
        "Try recording a session": [.japanese: "練習を記録してみましょう", .english: "Try recording a session."],
        "Sort By": [.japanese: "並び替え", .english: "Sort By"],
        "Route": [.japanese: "経路", .english: "Route"],
        "New Tag": [.japanese: "新しいタグ", .english: "New Tag"],
        "No Tags": [.japanese: "タグなし", .english: "No Tags"],
        "No Notes": [.japanese: "メモなし", .english: "No Notes"],
        
        // Record List
        "Records": [.japanese: "練習記録一覧", .english: "History"],
        "History": [.japanese: "履歴", .english: "History"],
        "No Records": [.japanese: "記録がありません", .english: "No Records"],
        "Fetching information...": [.japanese: "情報取得中...", .english: "Fetching info..."],
        
        // MARK: - common
        "Close": [.japanese: "閉じる", .english: "Close"],
        "Edit": [.japanese: "編集", .english: "Edit"],
        "Done": [.japanese: "完了", .english: "Done"],
        "Notes": [.japanese: "メモ", .english: "Notes"],
        "Tags": [.japanese: "タグ", .english: "Tags"],
        "Add Tag": [.japanese: "タグを追加", .english: "Add Tag"],
        
        // Record Detail
        "Performance": [.japanese: "パフォーマンス", .english: "Performance"],
        "Avg Pace": [.japanese: "平均ペース", .english: "Avg Pace"],
        "Avg SPM": [.japanese: "平均SPM", .english: "Avg SPM"],
        "Avg Speed": [.japanese: "平均速度", .english: "Avg Speed"],
        "Duration": [.japanese: "時間", .english: "Duration"],
        
        // MARK: - Terms View
        "Terms_LastUpdated": [.japanese: "最終更新日: 2026年5月10日", .english: "Last Updated: May 10, 2026"],
        "Term_1_Title": [.japanese: "1. はじめに", .english: "1. Introduction"],
        "Term_1_Content": [.japanese: """
        本利用規約（以下「本規約」といいます。）は、RowPilot（以下「本アプリ」といいます。）の利用条件を定めるものです。
        ユーザーは、本アプリを利用することにより、本規約に同意したものとみなされます。
        また、本アプリは個人により開発されたアプリであり、提供内容は予告なく変更される場合があります。
        """, .english: """
        This Terms of Service ("Terms") defines the conditions for using RowPilot ("App").
        By using the App, you are deemed to have agreed to these Terms.
        This App is developed by an individual, and the content provided may change without notice.
        """],
        "Term_2_Title": [.japanese: "2. 本アプリの目的", .english: "2. Purpose of the App"],
        "Term_2_Content": [.japanese: """
        本アプリは、ローイング、またはそれに関わる練習の記録・分析・振り返りを補助することを目的としたアプリです。
        競技成績の保証、健康・安全の保証を行うものではありません。
        """, .english: """
        The App is intended to assist in recording, analyzing, and reviewing rowing and related training.
        It does not guarantee competitive performance, health, or safety.
        """],
        "Term_3_Title": [.japanese: "3. 安全について", .english: "3. About Safety"],
        "Term_3_Content": [.japanese: """
        本アプリは、水上での使用を想定した機能を含んでいます。
        水上で本アプリを操作する際は、周囲の状況および自身の安全に十分配慮し、危険が生じるおそれがある場合には、直ちに使用を中止してください。
        水上での使用に伴い、端末の紛失や故障等が生じた場合においても、当方は一切の責任を負いません。ユーザー自身の責任においてご利用ください。
        """, .english: """
        The App includes functions intended for use on the water.
        When operating the App on the water, pay close attention to your surroundings and safety. If there is any danger, stop using it immediately.
        We are not responsible for any loss or malfunction of devices during use on the water. Please use it at your own risk.
        """],
        "Term_4_Title": [.japanese: "4. 取得する情報", .english: "4. Information Collected"],
        "Term_4_Content": [.japanese: """
        本アプリは、以下の情報を取得する場合があります。
        •  位置情報（GPS）：練習距離、速度、ペース、経路の記録・表示のため
        •  時刻・経過時間
        •  端末情報（OS種別等、動作確認のため）
        取得する情報は、本アプリの機能提供に必要な範囲に限られます。
        また、これらの情報は全て本アプリ内で処理されるため外部に送信されることはありません。
        """, .english: """
        The App may collect the following information:
        • Location (GPS): For recording and displaying distance, speed, pace, and routes.
        • Time and elapsed time.
        • Device info (OS type, etc., for operation verification).
        Information collected is limited to what is necessary for the App's functions.
        In addition, since all of this information is processed within this app, it is never sent to external sources.
        """],
        "Term_5_Title": [.japanese: "5. 位置情報の取り扱い", .english: "5. Handling of Location Information"],
        "Term_5_Content": [.japanese: """
        本アプリは、練習距離・速度・経路の記録を目的として、位置情報（GPS）を利用します。
        位置情報の取得は、ユーザーが端末の設定において許可した場合に限り行われます。
        取得された位置情報は、本アプリの機能提供の範囲内でのみ利用され、当方が当該情報を閲覧、収集、または第三者へ提供することはありません。
        ユーザーは、端末の設定により、いつでも位置情報の利用を停止することができます。
        """, .english: """
        The App use Location (GPS) for recording distance, speed and route.
        Location data is only accessed if you grant permission in your device settings.
        Collected data is used only within the App's functions; we do not view, collect, or provide this data to third parties.
        You can stop location usage at any time through your device settings.
        """],
        "Term_6_Title": [.japanese: "6. データの保存", .english: "6. Data Storage"],
        "Term_6_Content": [.japanese: """
        練習記録データは、ユーザーの端末内に保存されます。
        機種変更、アプリ削除等によりデータが消失する可能性がありますが、iCloudにバックアップすることで情報の保持が可能になります。
        データの消失・破損について、当方は責任を負いません。
        """, .english: """
        Training records are saved on your device.
        Data may be lost during device changes or App deletion, but can be preserved via iCloud backup.
        We are not responsible for data loss or corruption.
        """],
        "Term_7_Title": [.japanese: "7. 禁止事項", .english: "7. Prohibited Matters"],
        "Term_7_Content": [.japanese: """
        ユーザーは、本アプリの利用に際し以下の行為を行ってはなりません。
        •  本アプリの目的とは異なった利用
        •  他者の権利・安全を侵害する行為
        •  法令または公序良俗に反する行為
        •  本アプリの運営を妨害する行為
        •  本アプリの解析、改変、リバースエンジニアリングを目的とした行為
        """, .english: """
        Users must not perform the following:
        • Use for purposes other than intended.
        • Infringing on the rights or safety of others.
        • Actions against laws or public order.
        • Interfering with the App's operation.
        • Analysis, modification, or reverse engineering of the App.
        """],
        "Term_8_Title": [.japanese: "8. 免責事項", .english: "8. Disclaimer"],
        "Term_8_Content": [.japanese: """
        本アプリの利用は、ユーザー自身の責任において行われるものとします。
        本アプリ内容の正確性・完全性・有用性について、当方は保証しません。
        本アプリの利用により生じたいかなる損害についても、当方は責任を負いません。
        SOS機能は、補助的な機能であり、警察・消防等への緊急通報手段を代替するものではありません。
        本機能の作動遅延、未作動、通知未達等により生じたいかなる損害についても、当方は責任を負いません。
        """, .english: """
        Use of the App is at the user's own responsibility.
        We do not guarantee the accuracy, completeness, or usefulness of the App content.
        We are not liable for any damages resulting from using the App.
        The SOS function is supplementary and does not replace emergency reporting (police, fire).
        We are not liable for damages due to delays, failures, or missed notifications of this function.
        """],
        "Term_9_Title": [.japanese: "9. サービス内容の変更・終了", .english: "9. Changes/Termination of Service"],
        "Term_9_Content": [.japanese: """
        開発者はユーザーへの事前通知なく、本アプリの内容を変更または提供を終了することがあります。
        """, .english: """
        The developer may change or terminate App content/provision without prior notice.
        """],
        "Term_10_Title": [.japanese: "10. 規約の変更", .english: "10. Changes to Terms"],
        "Term_10_Content": [.japanese: """
        本規約は、必要に応じて変更されることがあります。
        変更後の規約は、本アプリ内または適切な方法で周知された時点から効力を生じます。
        """, .english: """
        These Terms may be changed as needed.
        Revised Terms take effect once announced within the App or via appropriate methods.
        """],
        "Term_11_Title": [.japanese: "11. 準拠法・裁判管轄", .english: "11. Governing Law/Jurisdiction"],
        "Term_11_Content": [.japanese: """
        本規約の解釈にあたっては、日本法を準拠法とします。本アプリに関して紛争が生じた場合には、当方の所在地を管轄する裁判所を専属的合意管轄とします。
        """, .english: """
        These Terms are governed by Japanese law. Any disputes regarding the App shall fall under the exclusive jurisdiction of the court overseeing the developer's location.
        """],
        
        // MARK: - Splash View
        "Navigate Your Performance": [.japanese: "Navigate Your Performance", .english: "Navigate Your Performance"],
        
        // MARK: - PM5 Manager View
        "Bluetooth ON": [.japanese: "Bluetooth ON", .english: "Bluetooth ON"],
        "Bluetooth OFF": [.japanese: "Bluetooth OFF", .english: "Bluetooth OFF"],
        "Scanning PM5": [.japanese: "PM5をスキャン", .english: "Scan PM5"],
        "Stop Scan": [.japanese: "スキャン停止", .english: "Stop Scan"],
        "Discovered PM5": [.japanese: "検出済みのPM5", .english: "Discovered PM5"],
        "Connecting...": [.japanese: "接続中...", .english: "Connecting..."],
        "Add": [.japanese: "追加", .english: "Add"],
        "Connected PM5": [.japanese: "追加済みPM5", .english: "Registered PM5"],
        "Add PM5 Message": [.japanese: "PM5を追加してください", .english: "Please add PM5"],
        "Connected": [.japanese: "接続済み", .english: "Connected"],
        "Delete": [.japanese: "削除", .english: "Remove"],
        "Next": [.japanese: "次へ", .english: "Next"],
        "PM5 Manager": [.japanese: "マネージャーモード", .english: "Manager Mode"],
        "Sending CSAFE...": [.japanese: "CSAFEコマンド送信中...", .english: "Sending CSAFE Commands..."],
        "Reconnecting": [.japanese: "再接続中...", .english: "Reconnecting..."],
        "Dashboard": [.japanese: "ダッシュボード", .english: "Dashboard"],
        "Race View": [.japanese: "レースビュー", .english: "Race View"],
        "Target Distance": [.japanese: "目標距離", .english: "Target Distance"],
        "Target Time": [.japanese: "目標時間", .english: "Target Time"],
        "Elapsed": [.japanese: "経過時間", .english: "Elapsed"],
        "Active": [.japanese: "接続中", .english: "Active"],
        "Repeat": [.japanese: "もう一度", .english: "Repeat"],
        "Repeat Workout": [.japanese: "ワークアウトを繰り返す", .english: "Repeat Workout"],
        "Save and Repeat": [.japanese: "保存してもう一度", .english: "Save and Repeat"],
        "Discard and Repeat": [.japanese: "破棄してもう一度", .english: "Discard and Repeat"],
        "Would you like to save this workout record?": [.japanese: "このワークアウト記録を保存しますか？", .english: "Would you like to save this workout record?"],
        "Would you like to save all connected erg records?": [.japanese: "接続中のすべてのエルゴ記録を保存しますか？", .english: "Would you like to save all connected erg records?"],
        "Change": [.japanese: "変更", .english: "Change"],
        
        // MARK: - Practice View
        "Connection Status": [.japanese: "接続ステータス", .english: "Connection Status"],
        "Connected: RowErg": [.japanese: "接続中: Concept2 RowErg", .english: "Connected: Concept2 RowErg"],
        "Machine State": [.japanese: "マシン状態:", .english: "Machine State:"],
        "Disconnect": [.japanese: "接続解除", .english: "Disconnect"],
        "NFC Connect": [.japanese: "NFC 接続", .english: "NFC Connect"],
        "Discovered Devices": [.japanese: "検出済みデバイス", .english: "Discovered Devices"],
        "Live Data": [.japanese: "ライブデータ", .english: "Live Data"],
        "Raw Data details": [.japanese: "生データ詳細", .english: "Raw Data details"],
        "Manager Mode": [.japanese: "マネージャーモード", .english: "Manager Mode"],
        "Manager Mode Desc": [.japanese: "複数PM5を接続してワークアウトを一括設定", .english: "Sync workout setup for multiple PM5s"],
        "Research": [.japanese: "リサーチ", .english: "Research"],
        "Practice(Dev)": [.japanese: "練習(開発中)", .english: "Practice(Dev)"],
        
        // MARK: - Workout Setup
        "Select Workout Type": [.japanese: "ワークアウト種目を選択", .english: "Select Workout Type"],
        "Single Distance": [.japanese: "単一距離", .english: "Single Distance"],
        "Single Time": [.japanese: "単一時間", .english: "Single Time"],
        "Workout Setup": [.japanese: "ワークアウト設定", .english: "Workout Setup"],
        "Distance Setup": [.japanese: "距離設定", .english: "Distance Setup"],
        "Time Setup": [.japanese: "時間設定", .english: "Time Setup"],
        "Set Distance": [.japanese: "設定距離 (m)", .english: "Set Distance (m)"],
        "Distance Range": [.japanese: "※ 対応レンジ: 100m 〜 60,000m", .english: "Range: 100m - 60,000m"],
        "Send to PM5": [.japanese: "PM5に送信", .english: "Send to PM5"],
        "Send to all PM5s": [.japanese: "全PM5に送信", .english: "Send to all PM5s"],
        "Min Time Message": [.japanese: "※ 最短設定時間は20秒です", .english: "Min duration is 20s"],
        "Bulk Send Message": [.japanese: "台のPM5に一括送信", .english: "sync to PM5s"],
        "Devices": [.japanese: "台", .english: " devices"],
        "Connected PM5s": [.japanese: "接続中のPM5", .english: "Connected PM5s"],
        
        "Remaining": [.japanese: "残り", .english: "Remaining"],
        "Finish": [.japanese: "終了", .english: "FINISH"],
        "Practice Workout": [.japanese: "練習ワークアウト", .english: "PRACTICE WORKOUT"],
        
        // MARK: - Sort Order
        "Sort_Date_Desc": [.japanese: "日付（新しい順）", .english: "Date (Newest)"],
        "Sort_Date_Asc": [.japanese: "日付（古い順）", .english: "Date (Oldest)"],
        "Sort_Dist_Desc": [.japanese: "距離（短い順）", .english: "Dist (Shortest)"],
        "Sort_Duration_Desc": [.japanese: "時間（短い順）", .english: "Time (Shortest)"],
        
        // MARK: - Credits
        "Special Thanks": [.japanese: "協力者", .english: "Special Thanks"],
        "Development Environment": [.japanese: "開発環境", .english: "Dev Environment"],
        "General Assistant": [.japanese: "メインアシスタント", .english: "Main Assistant"],
        "Code Assistant": [.japanese: "開発", .english: "Coding"],
        "Drawing Assistant": [.japanese: "画像生成", .english: "Design"],
        "Mechanical": [.japanese: "機械", .english: "Mechanical"],
        "Information": [.japanese: "情報", .english: "Information"],
        "Civil Engineering": [.japanese: "都市", .english: "Civil"],
        "Architecture": [.japanese: "建築", .english: "Architecture"],
        "Design": [.japanese: "デザイン", .english: "Design"],
        "Advisor": [.japanese: "顧問・外部コーチ", .english: "Advisor"],
    ]
    
    /// Get localized string
    func string(_ key: String) -> String {
        return translations[key]?[language] ?? key
    }
    
    func setLanguage(_ displayLanguage: AppLanguage) {
        self.language = displayLanguage
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.string(self)
    }
}
