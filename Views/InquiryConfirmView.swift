import SwiftUI

struct InquiryConfirmView: View {
    let selectedPage: String
    let selectedElement: String
    let message: String
    let email: String
    let includeGPS: Bool
    @Binding var shouldDismissToSettings: Bool
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var app: AppViewModel
    @State private var isSending = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
                                Text(selectedPage.localized)
                                    .foregroundColor(Theme.textMain)
                                    .fontWeight(.semibold)
                            }
                            Divider()
                                .background(Color.white.opacity(0.1))
                            HStack {
                                Text("Element:".localized)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(selectedElement.localized)
                                    .foregroundColor(Theme.textMain)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    InquirySection(title: "Inquiry Content (Required)".localized, icon: "square.and.pencil") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message)
                                .foregroundColor(Theme.textMain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    InquirySection(title: "Email Address (Optional)".localized, icon: "envelope") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Email:".localized)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(email.isEmpty ? "No input".localized : email)
                                    .foregroundColor(Theme.textMain)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    InquirySection(title: "Additional Info".localized, icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("GPS情報を含める".localized)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(includeGPS ? "Yes".localized : "No".localized)
                                    .foregroundColor(Theme.textMain)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    Button(action: sendInquiry) {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send with this content".localized)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Theme.primaryGradient)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isSending)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .navigationTitle("Confirm Inquiry".localized)
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("送信結果".localized, isPresented: $showingAlert) {
            Button("OK") {
                if !isSending && (alertMessage.contains("完了") || alertMessage.contains("success") || alertMessage.contains("ご協力ありがとうございます")) {
                    shouldDismissToSettings = true
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendInquiry() {
        isSending = true
        
        let urlString = "https://script.google.com/macros/s/AKfycbzn6y7wFpoWdxOjTAfBQhpE9TXHtc5RBFXTYDc09G1DaG3BR50yp-eBHxotG3eChqRimA/exec"
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
            "email": email,
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
                
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse else {
                    self.alertMessage = "通信エラーが発生しました。"
                    self.showingAlert = true
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "データなし"
                    self.alertMessage = "サーバーエラーが発生しました (コード: \(httpResponse.statusCode))\n\(responseString.prefix(100))"
                    self.showingAlert = true
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    if status == "success" {
                        self.alertMessage = "お問い合わせの送信が完了しました。ご協力ありがとうございます。"
                    } else {
                        let msg = json["message"] as? String ?? "不明なエラー"
                        self.alertMessage = "送信エラー: \(msg)"
                    }
                } else {
                    self.alertMessage = "レスポンスの解析に失敗しました。"
                }
                self.showingAlert = true
            }
        }.resume()
    }
}
