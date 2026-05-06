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
