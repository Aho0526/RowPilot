import SwiftUI

/// メンバー（Free/Manager等）がオーナーの招待コードを入力してManagerPlan共有を申請するView
struct InviteCodeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var requestManager = ShareRequestManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    @State private var inputCode: String = ""
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var codeParts: [String] = ["", ""]

    // フォーカスフィールド
    @FocusState private var focusedField: Int?

    private let managerColor = Color(hex: "7B2FBE")
    private let managerGradient = LinearGradient(colors: [Color(hex: "7B2FBE"), Color(hex: "C77DFF")], startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                // Manager Plan特有のパープルのグラデーション光
                RadialGradient(
                    colors: [managerColor.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // ヘッダー
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(managerGradient)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: managerColor.opacity(0.5), radius: 16)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 32)

                            Text("招待コードを入力".localized)
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.white)

                            Text("チームのTeam / MAXユーザーから発行された\n招待コードを入力してください".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // 共有名の確認
                        // 共有名の入力・確認
                        VStack(alignment: .leading, spacing: 10) {
                            Text("申請時の表示名".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(managerColor)
                                
                                TextField("表示名を入力してください".localized, text: $settingsManager.settings.sharingName)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            
                            if settingsManager.settings.sharingName.isEmpty {
                                Text("⚠️ 申請する前に、上のフィールドに表示名を入力してください。この名前がオーナーに表示されます。".localized)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                Text("この名前がオーナーに表示されます。".localized)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // コード入力フィールド
                        VStack(spacing: 16) {
                            Text("招待コード")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // xxxx-xxxx形式の入力フィールド
                            HStack(spacing: 12) {
                                // 前半4文字
                                codeTextField(index: 0, placeholder: "XXXX")

                                Text("-")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.4))

                                // 後半4文字
                                codeTextField(index: 1, placeholder: "XXXX")
                            }

                            Text("Team / MAXユーザーから共有された8文字のコード")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 申請ボタン
                        Button(action: submitRequest) {
                            HStack(spacing: 10) {
                                if requestManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("共有を申請する".localized)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                isFormValid
                                    ? managerGradient
                                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: isFormValid ? managerColor.opacity(0.4) : .clear, radius: 8)
                        }
                        .disabled(!isFormValid || requestManager.isLoading)
                        .padding(.horizontal)

                        // 説明カード
                        VStack(alignment: .leading, spacing: 12) {
                            Label("申請の流れ".localized, systemImage: "info.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(managerColor)

                            VStack(alignment: .leading, spacing: 8) {
                                flowStep(num: "1", text: "Team/MAXユーザーから招待コードをもらう".localized)
                                flowStep(num: "2", text: "コードを入力して「共有を申請する」をタップ".localized)
                                flowStep(num: "3", text: "オーナーが承認すると自動でManagerプランが適用される".localized)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Manager Plan 共有申請".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる".localized) { dismiss() }
                        .foregroundColor(managerColor)
                }
            }
            .alert(resultSuccess ? "申請完了".localized : "エラー".localized, isPresented: $showingResult) {
                Button("OK".localized) {
                    if resultSuccess { dismiss() }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }

    // MARK: - Subviews

    private func codeTextField(index: Int, placeholder: String) -> some View {
        TextField(placeholder, text: $codeParts[index])
            .textFieldStyle(.plain)
            .font(.system(.title2, design: .monospaced))
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .tracking(4)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == index ? managerColor.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .focused($focusedField, equals: index)
            .onChange(of: codeParts[index]) { _, newValue in
                // 4文字に制限し大文字化
                let filtered = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                if codeParts[index] != filtered {
                    codeParts[index] = filtered
                }
                // 前半が4文字になったら後半へフォーカス移動
                if index == 0 && filtered.count == 4 {
                    focusedField = 1
                }
            }
    }

    private func flowStep(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(managerColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text(num)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(managerColor)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Logic

    private var fullCode: String {
        "\(codeParts[0])-\(codeParts[1])"
    }

    private var isFormValid: Bool {
        codeParts[0].count == 4 && codeParts[1].count == 4
            && !settingsManager.settings.sharingName.isEmpty
    }

    private func submitRequest() {
        let myID = SubscriptionManager.shared.myUserRecordId
        let name = settingsManager.settings.sharingName

        requestManager.sendRequest(
            code: fullCode,
            requestorName: name,
            requestorID: myID
        ) { success, error in
            resultSuccess = success
            resultMessage = success
                ? "「\(name)」として共有を申請しました。\nオーナーが承認するとManagerプランが適用されます。"
                : (error ?? "申請に失敗しました。")
            showingResult = true
        }
    }
}

#Preview {
    InviteCodeInputView()
        .environmentObject(AppViewModel())
}
