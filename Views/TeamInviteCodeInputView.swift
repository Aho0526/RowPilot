import SwiftUI

/// メンバー側：チーム招待コードを入力してチーム参加を申請するView
struct TeamInviteCodeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var teamManager = TeamManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var codeParts: [String] = ["", ""]

    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // ヘッダー
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .green.opacity(0.4), radius: 16)
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 32)

                            Text("チーム招待コードを入力")
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.white)

                            Text("顧問やチームリーダーから発行された\nチーム招待コードを入力してください")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // 共有名の確認
                        if settingsManager.settings.sharingName.isEmpty {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("共有時の名前が未設定です")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                                Text("設定画面の「共有時の名前」を入力してから申請してください。\nこの名前が顧問に表示されます。")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("申請時の表示名")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(settingsManager.settings.sharingName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // コード入力フィールド
                        VStack(spacing: 16) {
                            Text("チーム招待コード")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                codeTextField(index: 0, placeholder: "XXXX")

                                Text("-")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.4))

                                codeTextField(index: 1, placeholder: "XXXX")
                            }

                            Text("顧問から共有された8文字のチーム招待コード")
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
                                if teamManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("チーム参加を申請する")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                isFormValid
                                    ? LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: isFormValid ? .green.opacity(0.3) : .clear, radius: 8)
                        }
                        .disabled(!isFormValid || teamManager.isLoading)
                        .padding(.horizontal)

                        // 説明カード
                        VStack(alignment: .leading, spacing: 12) {
                            Label("参加の流れ", systemImage: "info.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 8) {
                                flowStep(num: "1", text: "顧問からチーム招待コードをもらう")
                                flowStep(num: "2", text: "コードを入力して「チーム参加を申請する」をタップ")
                                flowStep(num: "3", text: "顧問が承認するとチームに追加される")
                                flowStep(num: "4", text: "練習を記録すると顧問の端末に自動配信される")
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Manager Plan共有との違い
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ℹ️ Manager Plan共有との違い")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                            Text("チーム参加はManagerプランの共有とは異なります。チーム参加では、あなたの練習記録が顧問の端末に配信されます。Managerプランの機能が共有されるわけではありません。")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                                .lineSpacing(3)
                        }
                        .padding()
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("チーム参加申請")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
            .alert(resultSuccess ? "申請完了" : "エラー", isPresented: $showingResult) {
                Button("OK") {
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
                    .stroke(focusedField == index ? Color.green.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .focused($focusedField, equals: index)
            .onChange(of: codeParts[index]) { _, newValue in
                let filtered = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                if codeParts[index] != filtered {
                    codeParts[index] = filtered
                }
                if index == 0 && filtered.count == 4 {
                    focusedField = 1
                }
            }
    }

    private func flowStep(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text(num)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
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
        let myID = subManager.myUserRecordId
        let name = settingsManager.settings.sharingName

        teamManager.sendJoinRequest(
            code: fullCode,
            requestorName: name,
            requestorID: myID
        ) { success, error in
            resultSuccess = success
            resultMessage = success
                ? "「\(name)」としてチーム参加を申請しました。\n顧問が承認するとチームに追加されます。"
                : (error ?? "申請に失敗しました。")
            showingResult = true
        }
    }
}

#Preview {
    TeamInviteCodeInputView()
}
