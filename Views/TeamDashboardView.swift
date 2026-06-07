import SwiftUI

/// 管理者（顧問）用のチームダッシュボード
/// メンバー管理・記録サマリーの閲覧を行う
struct TeamDashboardView: View {
    @ObservedObject var teamManager = TeamManager.shared
    @ObservedObject var codeManager = TeamInviteCodeManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingResetConfirm = false
    @State private var showingApproveConfirm: TeamJoinRequest? = nil
    @State private var showingRejectConfirm: TeamJoinRequest? = nil
    @State private var showingRemoveMember: TeamMember? = nil
    @State private var selectedSummary: TeamRecordSummary? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    teamCodeSection
                    pendingRequestsSection
                    membersSection
                    recordFeedSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("チーム管理".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            codeManager.ensureCodeExists()
            teamManager.fetchPendingRequests(ownerID: subManager.myUserRecordId)
            teamManager.startPolling()
        }
        .onDisappear {
            teamManager.stopPolling()
        }
        .navigationDestination(item: $selectedSummary) { selected in
            TeamRecordDetailView(summary: selected)
        }
        // リセット確認
        .alert("チーム招待コードのリセット", isPresented: $showingResetConfirm) {
            Button("リセット".localized, role: .destructive) {
                codeManager.resetCode { success, error in
                    alertTitle = success ? "リセット完了" : "エラー"
                    alertMessage = success
                        ? "新しいチーム招待コードが発行されました。\n全メンバーがチームから削除されました。"
                        : (error ?? "リセットに失敗しました。")
                    showingAlert = true
                }
            }
            Button("キャンセル".localized, role: .cancel) {}
        } message: {
            Text("チーム招待コードをリセットすると、現在の全チームメンバーが削除されます。\nこの操作は取り消せません。\n\n※ リセットは1週間に1回のみ可能です。".localized)
        }
        // 承認確認
        .alert("チーム参加の承認", isPresented: Binding(
            get: { showingApproveConfirm != nil },
            set: { if !$0 { showingApproveConfirm = nil } }
        )) {
            Button("承認する".localized) {
                guard let req = showingApproveConfirm else { return }
                teamManager.approveRequest(req) { success, error in
                    alertTitle = success ? "承認しました" : "エラー"
                    alertMessage = success
                        ? "「\(req.requestorName)」がチームに追加されました。"
                        : (error ?? "承認に失敗しました。")
                    showingAlert = true
                }
                showingApproveConfirm = nil
            }
            Button("キャンセル".localized, role: .cancel) { showingApproveConfirm = nil }
        } message: {
            if let req = showingApproveConfirm {
                Text("「\(req.requestorName)」のチーム参加を承認しますか？\n\n残り枠: \(teamManager.teamLimit - teamManager.teamMembers.count)名")
            }
        }
        // 拒否確認
        .alert("参加申請の拒否", isPresented: Binding(
            get: { showingRejectConfirm != nil },
            set: { if !$0 { showingRejectConfirm = nil } }
        )) {
            Button("拒否する".localized, role: .destructive) {
                guard let req = showingRejectConfirm else { return }
                teamManager.rejectRequest(req) { _, _ in }
                showingRejectConfirm = nil
            }
            Button("キャンセル".localized, role: .cancel) { showingRejectConfirm = nil }
        } message: {
            if let req = showingRejectConfirm {
                Text("「\(req.requestorName)」からの参加申請を拒否しますか？")
            }
        }
        // メンバー削除確認
        .alert("メンバーの削除", isPresented: Binding(
            get: { showingRemoveMember != nil },
            set: { if !$0 { showingRemoveMember = nil } }
        )) {
            Button("削除する".localized, role: .destructive) {
                if let member = showingRemoveMember {
                    teamManager.removeMember(member.id)
                    alertTitle = "削除完了"
                    alertMessage = "「\(member.name)」をチームから削除しました。"
                    showingAlert = true
                }
                showingRemoveMember = nil
            }
            Button("キャンセル".localized, role: .cancel) { showingRemoveMember = nil }
        } message: {
            if let member = showingRemoveMember {
                Text("「\(member.name)」をチームから削除しますか？\nこのメンバーの記録はダッシュボードから表示されなくなります。")
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
            Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primaryGradient)
                .padding(.top, 24)

            Text("チーム管理".localized)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)

            Text("メンバーの練習記録をリアルタイムで管理".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            // プラン・チーム枠情報
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAN")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text(subManager.currentPlan.displayName)
                        .font(.headline)
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TEAM MEMBERS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(teamManager.teamMembers.count) / \(teamManager.teamLimit)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
    }

    // MARK: - Team Invite Code

    private var teamCodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.green)
                Text("チーム招待コード".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(codeManager.teamInviteCode.isEmpty ? "------" : codeManager.teamInviteCode)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(codeManager.teamInviteCode.isEmpty ? .white.opacity(0.3) : .white)
                        .tracking(4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Button(action: copyCode) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.green)
                            .font(.body)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)

                Text("このコードをチームメンバーに共有してください。\nメンバーが入力するとチーム参加申請が届きます。".localized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)

                Text("※ Manager Plan共有コードとは別のコードです".localized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange.opacity(0.8))
            }

            // リセットボタン
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(codeManager.canReset ? "コードをリセット可能" : "リセットまであと\(codeManager.daysUntilReset)日")
                        .font(.caption)
                        .foregroundColor(codeManager.canReset ? .green : .white.opacity(0.4))
                    Text("リセット時は全メンバーが削除されます • 1週間に1回のみ".localized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Button(action: { showingResetConfirm = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("リセット".localized)
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
        .glassCardStyle(glowColor: .green, opacity: 0.08, cornerRadius: 16)
    }

    // MARK: - Pending Requests

    @ViewBuilder
    private var pendingRequestsSection: some View {
        if !teamManager.pendingTeamRequests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text("承認待ちの申請".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(teamManager.pendingTeamRequests.count)件")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }

                VStack(spacing: 0) {
                    ForEach(teamManager.pendingTeamRequests) { request in
                        pendingRequestRow(request)
                        if request.id != teamManager.pendingTeamRequests.last?.id {
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

    private func pendingRequestRow(_ request: TeamJoinRequest) -> some View {
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
                    Text("チームへの参加を申請しています".localized)
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
                        Text("拒否".localized)
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
                        Text("承認する".localized)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.2))
                    .foregroundColor(Theme.accent)
                    .cornerRadius(8)
                }
                .disabled(teamManager.teamMembers.count >= teamManager.teamLimit)
            }
        }
        .padding()
    }

    // MARK: - Members List

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Theme.accent)
                Text("チームメンバー".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            if teamManager.teamMembers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("チームメンバーはまだいません".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    Text("招待コードをメンバーに共有して\n申請を承認するとここに表示されます".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(teamManager.teamMembers) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(member.name.prefix(1)))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("参加: \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .foregroundColor(.white.opacity(0.35))
                                    .font(.caption2)
                            }

                            Spacer()

                            Button(action: { showingRemoveMember = member }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)

                        if member.id != teamManager.teamMembers.last?.id {
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

    // MARK: - Record Feed

    private var recordFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundColor(Theme.secondaryAccent)
                Text("メンバーの記録".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                // 自動更新インジケーター
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("1分おきに更新".localized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            if teamManager.memberRecordSummaries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("メンバーの記録はまだありません".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    Text("メンバーが練習を記録すると\n自動的にここに表示されます".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(teamManager.memberRecordSummaries) { summary in
                        Button(action: {
                            selectedSummary = summary
                        }) {
                            summaryRow(summary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.secondaryAccent, opacity: 0.08, cornerRadius: 16)
    }

    private func summaryRow(_ summary: TeamRecordSummary) -> some View {
        HStack(spacing: 12) {
            // アバター
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(summary.userName.prefix(1)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text(summary.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

                HStack(spacing: 16) {
                    Label(summary.formattedDistance, systemImage: "ruler")
                    Label(summary.formattedDuration, systemImage: "clock")
                    Label("\(summary.averageSPM) SPM", systemImage: "metronome")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

                if let tags = summary.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.15))
                                .foregroundColor(Theme.accent)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = codeManager.teamInviteCode
        alertTitle = "コピー完了"
        alertMessage = "チーム招待コードをクリップボードにコピーしました。"
        showingAlert = true
    }
}

// MARK: - TeamRecordSummary Hashable extension for navigationDestination
extension TeamRecordSummary: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    NavigationStack {
        TeamDashboardView()
    }
}
