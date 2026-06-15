import SwiftUI

struct InquiryView: View {
    @State private var selectedPage: String = "ホーム"
    @State private var selectedElement: String = ""
    @State private var message: String = ""
    @State private var includeGPS: Bool = false
    @State private var isSending: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var app: AppViewModel
    
    let pages = ["ホーム", "潮位", "RowMode","練習","設定", "その他"]
    
    var elements: [String] {
        switch selectedPage {
        case "ホーム": return ["検索","表示","進捗","リギング","最近の記録", "その他"]
        case "潮位": return ["日付変更", "データ表示","現在地","その他"]
        case "RowMode": return ["リギング", "Bluetooth接続", "記録", "画面表示", "その他"]
        case "練習": return ["PM5との接続", "NFC接続","アクティビティの共有", "チーム管理機能","その他"]
        case "設定": return ["アカウント", "言語設定", "表示設定", "天気予報", "ワークアウト共有", "データ同期", "利用規約", "サブスクリプション", "その他"]
        default: return ["該当なし"]
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("問題の発生箇所")) {
                Picker("ページ", selection: $selectedPage) {
                    ForEach(pages, id: \.self) { page in
                        Text(page).tag(page)
                    }
                }
                .onChange(of: selectedPage) { _, _ in
                    selectedElement = elements.first ?? ""
                }
                
                Picker("要素", selection: $selectedElement) {
                    ForEach(elements, id: \.self) { element in
                        Text(element).tag(element)
                    }
                }
            }
            .onAppear {
                if selectedElement.isEmpty {
                    selectedElement = elements.first ?? ""
                }
            }
            
            Section(header: Text("お問い合わせ内容")) {
                TextEditor(text: $message)
                    .frame(minHeight: 150)
            }
            
            Section(header: Text("追加情報"), footer: Text("潮位やRowModeの問題の場合はオンにしていただくと解決がスムーズです。")) {
                Toggle("GPS情報を含める", isOn: $includeGPS)
            }
            
            Section {
                Button(action: sendInquiry) {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("送信する")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
        }
        .navigationTitle("お問い合わせ")
        .alert("送信結果", isPresented: $showingAlert) {
            Button("OK") {
                if !isSending && alertMessage.contains("完了") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendInquiry() {
        isSending = true
        
        let urlString = "https://script.google.com/macros/s/AKfycby02tHfmAG-qRjI2ZhOA7BTLQi9S_Oqaaf3pI6o_PSSa233L8w5IcAodjFtAKLiiXo9/exec"
        guard let url = URL(string: urlString) else {
            alertMessage = "送信先URLが設定されていません。"
            showingAlert = true
            isSending = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var locationInfo = "なし"
        if includeGPS {
            if let location = app.locationManager.previousLocation {
                locationInfo = "緯度: \(location.coordinate.latitude), 経度: \(location.coordinate.longitude)"
            } else {
                locationInfo = "取得不可（GPS権限がない、または取得待ちです）"
            }
        }
        
        let payload: [String: Any] = [
            "page": selectedPage,
            "element": selectedElement,
            "message": message,
            "includeGPS": locationInfo,
            "plan": currentPlan.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            alertMessage = "データの作成に失敗しました。"
            showingAlert = true
            isSending = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSending = false
                
                if let error = error {
                    self.alertMessage = "送信に失敗しました: \(error.localizedDescription)"
                    self.showingAlert = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, 
                   (200...299).contains(httpResponse.statusCode) {
                    self.alertMessage = "お問い合わせの送信が完了しました。ご協力ありがとうございます。"
                    self.showingAlert = true
                } else {
                    self.alertMessage = "サーバーエラーが発生しました。時間をおいて再度お試しください。"
                    self.showingAlert = true
                }
            }
        }.resume()
    }
}

#Preview {
    InquiryView()
}
