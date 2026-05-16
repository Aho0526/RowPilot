import SwiftUI

struct CreditsView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    CreditSection(title: "Tools") {
                        NavigationLink(destination: AIAssistantView()) {
                            HStack {
                                Text("AI Assistant")
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    CreditSection(title: "Same Age Rowing Team") {
                        NavigationLink(destination: RowingTeamView()) {
                            HStack {
                                Text("KTHS Rowing Team")
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    CreditSection(title: "Special Thanks".localized) {
                        NavigationLink(destination: SpecialThanksView()) {
                            HStack {
                                Text("RowPilot Supporter")
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                     CreditSection(title: "バージョン履歴") {
                        NavigationLink(destination: VersionHistoryView()) {
                            HStack {
                                Text("アップデート情報")
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    CreditSection(title: "Development Environment".localized) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Xcode 26.2")
                            Text("Swift 6.2")
                            Text("Editor: Antigravity with Visual Studio Code")
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Components
struct CreditSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.accent)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
}

//MARK: - AI Assistant
struct AIAssistantView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "General Assistant".localized) {
                        Text("OpenAI GPT-5")
                            .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "Code Assistant".localized) {
                        Text("Google Gemini 3 Pro")
                        Text("OpenAI GPT-4o,5")
                        Text("Anthropic Claude Sonnet 4.5")
                    }
                    .foregroundColor(Theme.textMain)
                    
                    CreditSection(title: "Drawing Assistant".localized) {
                        Text("Google DeepMind ImageFX Imagen4")
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("AI Assistant")
    }
}

//MARK: - Version View
struct VersionHistoryView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "5/16") {
                        Text("不変・可変インタビュー機能を追加")
                        Text("Comminucation Architecture v4の適用")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "5/13") {
                        Text("レースビューにおけるレーン固定やペースメーカーの追加")
                        Text("Comminucation Architecture v4の適用")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "5/11") {
                        Text("SOS機能の大幅追加")
                        Text("SplitMeterの指定が可能に")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "5/10") {
                        Text("レースビューの変更")
                        Text("Comminucation Architecture v3.1の適用")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "5/9") {
                        Text("マネージャーモードにおける通信アーキテクチャを規定化し刷新")
                        Text("Comminucation Architecture v2の適用")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "5/6") {
                        Text("マネージャーモードにおける通信の不安定さを低減")
                        Text("Comminucation Architecture v1の作成")
                    .foregroundColor(Theme.textMain)
                    }

                    CreditSection(title: "4/30") {
                        Text("Pro,Manager,Team,MAXの課金プランを追加")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "4/29") {
                        Text("レースビューの追加。")
                        Text("PM5の名前/順番の変更が可能に。")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "4/26") {
                        Text("潮汐データ取得地点を9地点から239地点へ。")
                        Text("気象庁の提供する地点全てを取得可能に。")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "4/25") {
                        Text("バックアップから復元。")
                        Text("ForceCurveの実装。")
                        .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "3/5") {
                        Text("マネージャーモードのUI追加")
                        Text("業界初('26/3/5時点)となるBLEで複数台のライブデータ取得に成功")
                    .foregroundColor(Theme.textMain)
                    }
                     CreditSection(title: "3/3") {
                        Text("マネージャーモード(複数台通信機能)の追加")
                        Text("複数台のPM5にデータの送信ができるように")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "2/14") {
                        Text("任意の距離・時間を指定して送信できるように")
                        Text("データ送信中のUIを変更")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "2/12") {
                        Text("PM5にデータ送信成功")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "2/9") {
                        Text("RowModeの横向き制御機構を更新")
                        Text("TideViewの横向き対応")
                    .foregroundColor(Theme.textMain)
                    }
                    CreditSection(title: "2/8") {
                        Text("RowPilot内の文字を英語に変更できるように")
                        Text("SOS機能の追加・利用規約の作成")
                    .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("バージョン履歴")
    }
}

//MARK: - Rowing Team
struct RowingTeamView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        CreditSection(title: "Mechanical".localized) {
                            Text("E.E.").padding(.bottom, 2)
                            Text("O.N.").padding(.bottom, 2)
                            Text("M.T.")
                        }
                        CreditSection(title: "Information".localized) {
                            Text("U.D.").padding(.bottom, 2)
                            Text("O.Y.").padding(.bottom, 2)
                            Text("N.Y.").padding(.bottom, 2)
                            Text("Y.H.")
                        }
                        CreditSection(title: "Civil Engineering".localized) {
                            Text("H.K.")
                            Text("K.S.")
                        }
                        CreditSection(title: "Architecture".localized) {
                            Text("H.R.")
                            Text("Y.Y.")
                        }
                    }
                    .foregroundColor(Theme.textMain)
                    
                    Group {
                        CreditSection(title: "Design".localized) {
                            Text("O.F.")
                            Text("K.R.")
                            Text("S.A.")
                            Text("S.C.")
                            Text("T.M.")
                            Text("T.E.")
                            Text("N.R.")
                        }
                        CreditSection(title: "Manager") {
                            Text("N.K.")
                            Text("K.Y.")
                            Text("C.S.")
                            Text("M.M.")
                        }
                        CreditSection(title: "Advisor".localized) {
                            Text("S先生")
                            Text("H先生")
                            Text("O先生")
                            Text("Iコーチ")
                        }
                    }
                     .foregroundColor(Theme.textMain)
                }
                .padding()
            }
        }
        .navigationTitle("KTHS Rowing Team")
    }
}

//MARK: - Special Thanks
struct SpecialThanksView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack {
                    CreditSection(title: "Concept2 Technical Supporter") {
                        let supporterNames = ["Ryan Farrell - General Technical Supporter", "Nathan Paulin - Tech/Customer Support","Scott Hamilton - Electoral Product Supporter"]
                        ForEach(supporterNames, id: \.self) { name in
                            Text(name)
                                .foregroundColor(Theme.textMain)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Special Thanks")
    }
}

#Preview {
    NavigationStack {
        CreditsView()
    }
}
