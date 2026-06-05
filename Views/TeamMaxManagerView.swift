import SwiftUI

/// TeamおよびMAXプランユーザー向けのManagerPlan共有管理ビュー（招待コード方式）
struct TeamMaxManagerView: View {
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject var codeManager = InviteCodeManager.shared
    @ObservedObject var requestManager = ShareRequestManager.shared

    @AppStorage("userSubscriptionPlan") private var currentPlanRaw: String = "free"

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingResetConfirm = false
    @State private var showingApproveConfirm: ShareRequest? = nil
    @State private var showingRejectConfirm: ShareRequest? = nil

    var currentPlan: SubscriptionPlan {
        SubscriptionPlan(rawValue: currentPlanRaw) ?? .free
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    inviteCodeSection
                    pendingRequestsSection
                    sharedMembersSection
                    helpSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Manager Sharing".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            codeManager.ensureCodeExists()
            requestManager.fetchPendingRequests(ownerID: subManager.myUserRecordId)
        }
        // リセット確認
        .alert("招待コードのリセット", isPresented: $showingResetConfirm) {
            Button("リセット", role: .destructive) {
                codeManager.resetCode { success, error in
                    alertTitle = success ? "リセット完了" : "エラー"
                    alertMessage = success
                        ? "新しい招待コードが発行されました。\n共有中のメンバーは全員削除され、共有が停止されました。"
                        : (error ?? "リセットに失敗しました。")
                    showingAlert = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("招待コードをリセットすると、現在共有中の全メンバーが削除され、共有が停止されます。\nこの操作は取り消せません。\n\n※ リセットは1週間に1回のみ可能です。")
        }
        // 承認確認
        .alert("共有申請の承認", isPresented: Binding(
            get: { showingApproveConfirm != nil },
            set: { if !$0 { showingApproveConfirm = nil } }
        )) {
            Button("承認する") {
                guard let req = showingApproveConfirm else { return }
                requestManager.approveRequest(req) { success, error in
                    alertTitle = success ? "承認しました" : "エラー"
                    alertMessage = success
                        ? "「\(req.requestorName)」がチームに追加されました。"
                        : (error ?? "承認に失敗しました。")
                    showingAlert = true
                }
                showingApproveConfirm = nil
            }
            Button("キャンセル", role: .cancel) { showingApproveConfirm = nil }
        } message: {
            if let req = showingApproveConfirm {
                Text("「\(req.requestorName)」のManagerプラン共有を承認しますか？\n\n残り共有枠: \(subManager.shareLimit - subManager.sharedMembers.count)名")
            }
        }
        // 拒否確認
        .alert("申請の拒否", isPresented: Binding(
            get: { showingRejectConfirm != nil },
            set: { if !$0 { showingRejectConfirm = nil } }
        )) {
            Button("拒否する", role: .destructive) {
                guard let req = showingRejectConfirm else { return }
                requestManager.rejectRequest(req) { _, _ in }
                showingRejectConfirm = nil
            }
            Button("キャンセル", role: .cancel) { showingRejectConfirm = nil }
        } message: {
            if let req = showingRejectConfirm {
                Text("「\(req.requestorName)」からの申請を拒否しますか？")
            }
        }
        // 汎用アラート
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primaryGradient)
                .padding(.top, 24)

            Text("Team & MAX Management".localized)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)

            Text("Teammates can share RowPilot Manager features.".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // プラン・共有枠情報
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT PLAN".localized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text(currentPlan.displayName)
                        .font(.headline)
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("SHARING SLOTS".localized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(subManager.sharedMembers.count) / \(subManager.shareLimit)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
    }

    // MARK: - Invite Code

    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(Theme.accent)
                Text("招待コード")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // コード表示
            VStack(spacing: 8) {
                HStack {
                    Text(codeManager.inviteCode.isEmpty ? "------" : codeManager.inviteCode)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(codeManager.inviteCode.isEmpty ? .white.opacity(0.3) : .white)
                        .tracking(4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Button(action: copyCode) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(Theme.accent)
                            .font(.body)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)

                Text("このコードをチームメンバーに共有してください。\nメンバーが入力すると共有申請が届きます。")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }

            // リセットボタン
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(codeManager.canReset ? "コードをリセット可能" : "リセットまであと\(codeManager.daysUntilReset)日")
                        .font(.caption)
                        .foregroundColor(codeManager.canReset ? Theme.accent : .white.opacity(0.4))
                    Text("リセット時は全メンバーが削除されます • 1週間に1回のみ")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Button(action: { showingResetConfirm = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("リセット")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(codeManager.canReset ? Color.red.opacity(0.2) : Color.white.opacity(0.05))
                    .foregroundColor(codeManager.canReset ? .red : .white.opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(!codeManager.canReset)
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 16)
    }

    // MARK: - Pending Requests

    @ViewBuilder
    private var pendingRequestsSection: some View {
        if !requestManager.pendingRequests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text("承認待ちの申請")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(requestManager.pendingRequests.count)件")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }

                VStack(spacing: 0) {
                    ForEach(requestManager.pendingRequests) { request in
                        pendingRequestRow(request)

                        if request.id != requestManager.pendingRequests.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private func pendingRequestRow(_ request: ShareRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(String(request.requestorName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.requestorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Managerプランの共有を要求しています")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                    Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: { showingRejectConfirm = request }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("拒否")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }

                Button(action: { showingApproveConfirm = request }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("はい、許可する")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.2))
                    .foregroundColor(Theme.accent)
                    .cornerRadius(8)
                }
                .disabled(subManager.sharedMembers.count >= subManager.shareLimit)
            }
        }
        .padding()
    }

    // MARK: - Shared Members

    private var sharedMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Theme.accent)
                Text("Shared Members".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            if subManager.sharedMembers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("共有中のメンバーはいません")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    Text("招待コードをメンバーに共有して\n申請を承認するとここに表示されます")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(subManager.sharedMembers, id: \.self) { memberID in
                        let name = subManager.sharedMemberNames[memberID] ?? memberID
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(name.prefix(1)))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(memberID)
                                    .foregroundColor(.white.opacity(0.35))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: { removeMember(memberID) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)

                        if memberID != subManager.sharedMembers.last {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }

    // MARK: - Help

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.accent)
                Text("Manager Plan Sharing Help".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 12) {
                HelpQAItem(
                    question: "どうすればメンバーにManagerPlanを共有できますか？",
                    answer: "「招待コード」をチームメンバーに送り、メンバーが設定画面の「コードを入力して申請」から入力して送信します。承認通知が届いたら「はい、許可する」を押すと自動でManagerPlanが適用されます。"
                )

                HelpQAItem(
                    question: "招待コードは何回使えますか？",
                    answer: "招待コードは何人でも使用できます（共有枠の上限まで）。ただし、コードが流出した場合はリセット（週1回）することで新しいコードに変更できます。リセット時は全共有メンバーが削除されます。"
                )

                HelpQAItem(
                    question: "個人で既にManagerPlan等に加入しているメンバーを追加できますか？",
                    answer: "いいえ。個人で既に有料プランに加入しているユーザーには共有できません。そのメンバーが個人サブスクリプションを解約して有効期限が切れた後に申請してください。"
                )

                HelpQAItem(
                    question: "共有元のサブスクリプションを解約した場合はどうなりますか？",
                    answer: "共有元のTeamまたはMAXユーザーがサブスクリプションを解約（自動更新の停止）した場合、翌月の有効期限が切れたタイミングで共有先メンバーも自動的にFreeプランに移行されます。"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = codeManager.inviteCode
        alertTitle = "コピー完了"
        alertMessage = "招待コードをクリップボードにコピーしました。"
        showingAlert = true
    }

    private func removeMember(_ memberID: String) {
        if let index = subManager.sharedMembers.firstIndex(of: memberID) {
            subManager.sharedMemberNames.removeValue(forKey: memberID)
            subManager.removeMember(at: IndexSet(integer: index))
            alertTitle = "削除完了"
            alertMessage = "メンバーを共有リストから削除しました。"
            showingAlert = true
        }
    }
}

/// ヘルプQAアイテム用アコーディオンビュー
struct HelpQAItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Q: \(question)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text("A: \(answer)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                    .padding(.leading, 8)
                    .transition(.opacity)
            }

            Divider().background(Color.white.opacity(0.1))
        }
    }
}

#Preview {
    NavigationStack {
        TeamMaxManagerView()
    }
}
