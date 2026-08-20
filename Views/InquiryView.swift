import SwiftUI

struct InquiryView: View {
    @State private var selectedPage: String = "Please select"
    @State private var selectedElement: String = "Please select"
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var includeGPS: Bool = false
    @State private var shouldDismissToSettings: Bool = false
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let pages = ["Please select", "ホーム", "潮位", "RowMode", "練習", "設定", "その他"]
    
    var elements: [String] {
        switch selectedPage {
        case "Please select":
            return ["Please select"]
        case "ホーム":
            return ["Please select", "検索", "表示", "進捗", "リギング", "最近の記録", "その他"]
        case "潮位":
            return ["Please select", "データ表示", "現在地", "その他"]
        case "RowMode":
            return ["Please select", "リギング", "Bluetooth接続", "記録", "画面表示", "その他"]
        case "練習":
            return ["Please select", "PM5との接続", "NFC接続", "アクティビティの共有", "チーム管理機能", "その他"]
        case "設定":
            return ["Please select", "アカウント", "言語設定", "表示設定", "天気予報", "ワークアウト共有", "データ同期", "利用規約", "サブスクリプション", "その他"]
        default:
            return ["Please select", "該当なし"]
        }
    }
    
    var isEmailValid: Bool {
        if email.isEmpty { return true }
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    var isFormValid: Bool {
        selectedPage != "Please select" &&
        selectedElement != "Please select" &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isEmailValid
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    InquirySection(title: "Location of Issue (Required)".localized, icon: "mappin.and.ellipse") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Page:".localized)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Picker("Page:".localized, selection: $selectedPage) {
                                    ForEach(pages, id: \.self) { page in
                                        Text(page.localized).tag(page)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.accent)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            HStack {
                                Text("Element:".localized)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Picker("Element:".localized, selection: $selectedElement) {
                                    ForEach(elements, id: \.self) { element in
                                        Text(element.localized).tag(element)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.accent)
                            }
                        }
                    }
                    .onChange(of: selectedPage) { _, _ in
                        selectedElement = elements.first ?? "Please select"
                    }
                    
                    InquirySection(title: "Inquiry Content (Required)".localized, icon: "square.and.pencil") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $message)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                .foregroundColor(Theme.textMain)
                                .tint(Theme.accent)
                        }
                    }
                    
                    InquirySection(title: "Email Address (Optional)".localized, icon: "envelope") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("example@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                .foregroundColor(Theme.textMain)
                                .tint(Theme.accent)
                            
                            Text("Email Description".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            if !email.isEmpty && !isEmailValid {
                                Text("Invalid email address format".localized)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    InquirySection(title: "Additional Info".localized, icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("GPS情報を含める".localized, isOn: $includeGPS)
                                .foregroundColor(Theme.textMain)
                                .tint(Theme.accent)
                            
                            Text("潮位やRowModeの問題の場合はオンにしていただくと解決がスムーズです。".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    NavigationLink(destination: InquiryConfirmView(
                        selectedPage: selectedPage,
                        selectedElement: selectedElement,
                        message: message,
                        email: email,
                        includeGPS: includeGPS,
                        shouldDismissToSettings: $shouldDismissToSettings
                    )) {
                        HStack {
                            Spacer()
                            Text("Proceed to Confirm".localized)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding()
                        .background(isFormValid ? Theme.primaryGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .shadow(color: isFormValid ? Theme.accent.opacity(0.4) : .clear, radius: 10, x: 0, y: 4)
                    }
                    .disabled(!isFormValid)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .navigationTitle("Contact".localized)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: shouldDismissToSettings) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}

struct InquirySection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(spacing: 16) {
                content
            }
            .padding()
            .glassCardStyle()
        }
    }
}
