import SwiftUI

/// 管理者（顧問）用のチームダッシュボード（CloudKit Shared Database版）
struct TeamDashboardView: View {
    @ObservedObject var ckTeam = CloudKitTeamManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared

    @State private var showingCreateTeam = false
    @State private var newTeamName = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingApproveConfirm: CKJoinRequest? = nil
    @State private var showingRejectConfirm: CKJoinRequest? = nil
    @State private var showingRemoveMember: CKMembership? = nil
    @State private var showingPermanentDelete: CKMembership? = nil
    @State private var selectedSummary: CKTeamWorkoutSummary? = nil
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if let team = ckTeam.myTeam {
                        teamCodeSection(team: team)
                        pendingRequestsSection
                        membersSection
                        recordFeedSection
                    } else {
                        createTeamSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationTitle("チーム管理".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await refreshData() }
                }) {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: isRefreshing)
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .onAppear {
            loadTeamData()
        }
        .navigationDestination(item: $selectedSummary) { summary in
            TeamWorkoutDetailView(summary: summary)
        }
        // チーム作成
        .alert("チームを作成", isPresented: $showingCreateTeam) {
            TextField("チーム名を入力", text: $newTeamName)
            Button("作成") {
                createTeam()
            }
            Button("キャンセル", role: .cancel) { newTeamName = "" }
        } message: {
            Text("新しいチームを作成します。チーム名を入力してください。")
        }
        // 承認確認
        .alert("チーム参加の承認", isPresented: Binding(
            get: { showingApproveConfirm != nil },
            set: { if !$0 { showingApproveConfirm = nil } }
        )) {
            Button("承認する".localized) {
                guard let req = showingApproveConfirm else { return }
                ckTeam.approveJoinRequest(req) { success, error in
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
                let activeCount = ckTeam.memberships.filter { $0.isActive }.count
                let limit = subManager.currentPlan.teamMemberLimit
                Text("「\(req.requestorName)」のチーム参加を承認しますか？\n\n残り枠: \(limit - activeCount)名")
            }
        }
        // 拒否確認
        .alert("参加申請の拒否", isPresented: Binding(
            get: { showingRejectConfirm != nil },
            set: { if !$0 { showingRejectConfirm = nil } }
        )) {
            Button("拒否する".localized, role: .destructive) {
                guard let req = showingRejectConfirm else { return }
                ckTeam.rejectJoinRequest(req) { _, _ in }
                showingRejectConfirm = nil
            }
            Button("キャンセル".localized, role: .cancel) { showingRejectConfirm = nil }
        } message: {
            if let req = showingRejectConfirm {
                Text("「\(req.requestorName)」からの参加申請を拒否しますか？")
            }
        }
        // メンバー削除確認（status=removed・30日保持）
        .alert("メンバーの削除", isPresented: Binding(
            get: { showingRemoveMember != nil },
            set: { if !$0 { showingRemoveMember = nil } }
        )) {
            Button("削除する".localized, role: .destructive) {
                if let member = showingRemoveMember {
                    ckTeam.removeMember(member) { success, error in
                        alertTitle = success ? "削除完了" : "エラー"
                        alertMessage = success
                            ? "「\(member.userName)」をチームから削除しました。\n（30日間データを保持します）"
                            : (error ?? "削除に失敗しました。")
                        showingAlert = true
                    }
                }
                showingRemoveMember = nil
            }
            Button("キャンセル".localized, role: .cancel) { showingRemoveMember = nil }
        } message: {
            if let member = showingRemoveMember {
                Text("「\(member.userName)」をチームから削除しますか？\n\nデータは30日間保持されます。完全削除はメンバー詳細から行えます。")
            }
        }
        // 完全削除確認
        .alert("完全削除", isPresented: Binding(
            get: { showingPermanentDelete != nil },
            set: { if !$0 { showingPermanentDelete = nil } }
        )) {
            Button("完全削除する", role: .destructive) {
                if let member = showingPermanentDelete {
                    ckTeam.permanentlyDeleteMember(member) { success in
                        alertTitle = success ? "完全削除完了" : "エラー"
                        alertMessage = success
                            ? "「\(member.userName)」のすべてのデータを削除しました。"
                            : "削除に失敗しました。"
                        showingAlert = true
                    }
                }
                showingPermanentDelete = nil
            }
            Button("キャンセル", role: .cancel) { showingPermanentDelete = nil }
        } message: {
            if let member = showingPermanentDelete {
                Text("「\(member.userName)」のMembership・ワークアウト記録をすべて完全削除します。\nこの操作は取り消せません。")
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
            if let team = ckTeam.myTeam {
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
                        Text("TEAM")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                        Text(team.teamName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MEMBERS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                        let activeCount = ckTeam.memberships.filter { $0.isActive }.count
                        Text("\(activeCount) / \(subManager.currentPlan.teamMemberLimit)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - チーム作成セクション（チームがない場合）

    private var createTeamSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("チームを作成する")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("チームを作成すると、メンバーの練習記録を\nリアルタイムで管理できます。")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            Button(action: { showingCreateTeam = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("チームを作成")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(colors: [.green, Color(hex: "065F46")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color.green.opacity(0.4), radius: 8)
            }

            Text("※ チームはプランの上限内で1つ作成できます。\n招待コードはチーム単位で管理されます。")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassCardStyle(glowColor: .green, opacity: 0.1, cornerRadius: 16)
    }

    // MARK: - チーム招待コードセクション

    private func teamCodeSection(team: CKTeam) -> some View {
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
                    Text(team.inviteCode.isEmpty ? "------" : team.inviteCode)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(team.inviteCode.isEmpty ? .white.opacity(0.3) : .white)
                        .tracking(4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Button(action: { copyCode(team.inviteCode) }) {
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

                Text("※ 招待コードはチームに属します（管理者全員が同じコードを利用）".localized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
        .padding()
        .glassCardStyle(glowColor: .green, opacity: 0.08, cornerRadius: 16)
    }

    // MARK: - 承認待ちリクエスト

    @ViewBuilder
    private var pendingRequestsSection: some View {
        if !ckTeam.pendingJoinRequests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text("承認待ちの申請".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(ckTeam.pendingJoinRequests.count)件")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }

                VStack(spacing: 0) {
                    ForEach(ckTeam.pendingJoinRequests) { request in
                        pendingRequestRow(request)
                        if request.id != ckTeam.pendingJoinRequests.last?.id {
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

    private func pendingRequestRow(_ request: CKJoinRequest) -> some View {
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
                .disabled(ckTeam.memberships.filter { $0.isActive }.count >= subManager.currentPlan.teamMemberLimit)
            }
        }
        .padding()
    }

    // MARK: - メンバー一覧

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Theme.accent)
                Text("チームメンバー".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            let activeMembers = ckTeam.memberships.filter { $0.isActive && $0.role != .owner }

            if activeMembers.isEmpty {
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
                    ForEach(activeMembers) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(member.userName.prefix(1)))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(member.userName)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if member.role == .admin {
                                        Text("管理者")
                                            .font(.system(size: 10))
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Theme.accent.opacity(0.2))
                                            .foregroundColor(Theme.accent)
                                            .cornerRadius(4)
                                    }
                                }
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

                        if member.id != activeMembers.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }

            // 脱退・削除済みメンバー（30日保持期間内）
            let retainedMembers = ckTeam.memberships.filter { !$0.isActive && $0.isWithinRetentionPeriod }
            if !retainedMembers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("保持期間中のメンバー（退部/削除済み）")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.4))

                    ForEach(retainedMembers) { member in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text(String(member.userName.prefix(1)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.userName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(member.status == .left ? "脱退" : "削除")
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.5))
                            }

                            Spacer()

                            Button("完全削除") {
                                showingPermanentDelete = member
                            }
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }

    // MARK: - ワークアウト記録フィード（一覧・軽量）

    private var recordFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundColor(Theme.secondaryAccent)
                Text("メンバーの記録".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("自動更新")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            if ckTeam.workoutSummaries.isEmpty {
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
                    ForEach(ckTeam.workoutSummaries) { summary in
                        Button(action: { selectedSummary = summary }) {
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

    private func summaryRow(_ summary: CKTeamWorkoutSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(summary.athleteName.prefix(1)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.athleteName)
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
                    Label(summary.formattedSplit, systemImage: "metronome")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
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

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        alertTitle = "コピー完了"
        alertMessage = "チーム招待コードをクリップボードにコピーしました。"
        showingAlert = true
    }

    private func createTeam() {
        guard !newTeamName.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "エラー"
            alertMessage = "チーム名を入力してください。"
            showingAlert = true
            return
        }
        ckTeam.createTeam(teamName: newTeamName.trimmingCharacters(in: .whitespaces)) { success, error in
            alertTitle = success ? "チーム作成完了" : "エラー"
            alertMessage = success
                ? "チーム「\(newTeamName)」を作成しました。"
                : (error ?? "チームの作成に失敗しました。")
            newTeamName = ""
            showingAlert = true
        }
    }

    private func loadTeamData() {
        ckTeam.fetchMyTeam { team in
            guard let team = team else { return }
            self.ckTeam.fetchMemberships(teamID: team.id)
            self.ckTeam.fetchPendingJoinRequests(teamID: team.id)
            self.ckTeam.fetchWorkoutSummaries(teamID: team.id)
            self.ckTeam.cleanupExpiredMembers()
        }
    }

    @MainActor
    private func refreshData() async {
        isRefreshing = true
        await withCheckedContinuation { continuation in
            ckTeam.fetchMyTeam { team in
                guard let team = team else {
                    continuation.resume()
                    return
                }
                self.ckTeam.fetchMemberships(teamID: team.id)
                self.ckTeam.fetchPendingJoinRequests(teamID: team.id)
                self.ckTeam.fetchWorkoutSummaries(teamID: team.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    continuation.resume()
                }
            }
        }
        isRefreshing = false
    }
}

// MARK: - CKTeamWorkoutSummary Hashable extension

extension CKTeamWorkoutSummary: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - TeamWorkoutDetailView（詳細画面）

struct TeamWorkoutDetailView: View {
    let summary: CKTeamWorkoutSummary
    @ObservedObject var ckTeam = CloudKitTeamManager.shared
    @State private var detail: CKTeamWorkoutDetail? = nil
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                ProgressView("読み込み中...")
                    .foregroundColor(.white)
            } else if let detail = detail {
                detailContent(detail)
            } else {
                summaryFallback
            }
        }
        .navigationTitle(summary.athleteName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDetail()
        }
    }

    private func detailContent(_ detail: CKTeamWorkoutDetail) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Text(String(detail.athleteName.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.accent)
                    }
                    Text(detail.athleteName)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(detail.date.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)

                // 主要スタッツ
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "距離", value: detail.formattedDistance, icon: "ruler.fill", color: .blue)
                    statCard(title: "時間", value: detail.formattedDuration, icon: "clock.fill", color: .green)
                    statCard(title: "ペース", value: detail.formattedSplit, icon: "speedometer", color: .orange)
                    statCard(title: "SPM", value: "\(detail.avgRate) SPM", icon: "metronome.fill", color: .purple)
                    if let watt = detail.avgWatt {
                        statCard(title: "平均出力", value: "\(watt) W", icon: "bolt.fill", color: .yellow)
                    }
                }
                .padding(.horizontal)

                // メモ
                if let notes = detail.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("メモ", systemImage: "note.text")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.5))
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // タグ
                if let tags = detail.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("タグ", systemImage: "tag.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.5))
                        TeamTagFlowLayout(tags: tags)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var summaryFallback: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Text(String(summary.athleteName.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.accent)
                    }
                    Text(summary.athleteName)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(summary.date.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(title: "距離", value: summary.formattedDistance, icon: "ruler.fill", color: .blue)
                    statCard(title: "時間", value: summary.formattedDuration, icon: "clock.fill", color: .green)
                    statCard(title: "ペース", value: summary.formattedSplit, icon: "speedometer", color: .orange)
                    statCard(title: "SPM", value: "\(summary.avgRate) SPM", icon: "metronome.fill", color: .purple)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
    }

    private func loadDetail() {
        ckTeam.fetchWorkoutDetail(workoutID: summary.id, teamID: summary.teamID) { detail in
            self.detail = detail
            self.isLoading = false
        }
    }
}

// MARK: - CKTeamWorkoutDetail computed

extension CKTeamWorkoutDetail {
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedSplit: String {
        let totalSeconds = Int(avgSplit)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /500m", minutes, seconds)
    }
}

// MARK: - TeamTagFlowLayout（タグ表示用）

struct TeamTagFlowLayout: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 60))
        ], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundColor(Theme.accent)
                    .cornerRadius(6)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TeamDashboardView()
    }
}
