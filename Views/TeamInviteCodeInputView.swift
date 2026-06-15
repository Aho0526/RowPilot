import SwiftUI

/// メンバー側：チーム招待コードを入力してチーム参加を申請するView
struct TeamInviteCodeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ckTeam = CloudKitTeamManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    @State private var codeParts: [String] = ["", ""]

    @FocusState private var focusedField: Int?

    private let teamColor = Color(hex: "10B981")
    private let teamGradient = LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "065F46")], startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                // チーム特有のグリーンのグラデーション光
                RadialGradient(
                    colors: [teamColor.opacity(0.18), .clear],
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
                                    .fill(teamGradient)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: teamColor.opacity(0.5), radius: 16)
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 32)

                            Text("チーム招待コードを入力".localized)
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.white)

                            Text("顧問やチームリーダーから発行された\nチーム招待コードを入力してください".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            // すでにチーム参加中の場合は注意表示
                            if ckTeam.isTeamMember {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("現在すでにチームに参加しています。\n脱退してから別のチームに参加できます。")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.08))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }

                        // 共有名の入力・確認
                        VStack(alignment: .leading, spacing: 10) {
                            Text("申請時の表示名".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))

                            HStack(spacing: 12) {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(teamColor)

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
                                Text("⚠️ 申請する前に、上のフィールドに表示名を入力してください。この名前が顧問に表示されます。".localized)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                Text("この名前が顧問に表示されます。".localized)
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
                            Text("チーム招待コード".localized)
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

                            Text("顧問から共有された8文字のチーム招待コード".localized)
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
                                if ckTeam.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("チーム参加を申請する".localized)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                isFormValid
                                    ? teamGradient
                                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: isFormValid ? teamColor.opacity(0.4) : .clear, radius: 8)
                        }
                        .disabled(!isFormValid || ckTeam.isLoading || ckTeam.isTeamMember)
                        .padding(.horizontal)

                        // 参加の流れ説明
                        VStack(alignment: .leading, spacing: 12) {
                            Label("参加の流れ".localized, systemImage: "info.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(teamColor)

                            VStack(alignment: .leading, spacing: 8) {
                                flowStep(num: "1", text: "顧問からチーム招待コードをもらう".localized)
                                flowStep(num: "2", text: "コードを入力して「チーム参加を申請する」をタップ".localized)
                                flowStep(num: "3", text: "顧問が承認するとチームに追加される".localized)
                                flowStep(num: "4", text: "練習を記録すると顧問の端末に自動配信される".localized)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 仕組みの説明
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ℹ️ チーム参加の仕組み".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                            Text("あなたの個人データ（練習記録）はあなた自身のiCloudに保存されます。チーム参加により、記録のサマリーと詳細が顧問の端末へ共有されます。個人データの所有権はあなた自身に残ります。")
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
            .navigationTitle("チーム参加申請".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる".localized) { dismiss() }
                        .foregroundColor(teamColor)
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
                    .stroke(focusedField == index ? teamColor.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
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
                    .fill(teamColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text(num)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(teamColor)
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
            && !settingsManager.settings.sharingName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitRequest() {
        let name = settingsManager.settings.sharingName.trimmingCharacters(in: .whitespaces)

        ckTeam.sendJoinRequest(
            inviteCode: fullCode,
            requesterName: name
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
