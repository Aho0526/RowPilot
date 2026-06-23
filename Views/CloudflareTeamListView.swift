import SwiftUI

struct CloudflareTeamListView: View {
    @StateObject private var viewModel = CloudflareTeamViewModel()
    @ObservedObject private var subManager = SubscriptionManager.shared
    @State private var teamToDelete: Team?
    @State private var showDeleteConfirm = false
    @State private var showCreateAlert = false
    @State private var newTeamName = ""
    
    // Member Options
    @State private var selectedMember: CloudflareUser?
    @State private var showMemberOptions = false
    @State private var showMembersSheet = false
    
    // Approve/Reject
    @State private var memberToApprove: CloudflareUser?
    @State private var showApproveConfirm = false
    @State private var memberToReject: CloudflareUser?
    @State private var showRejectConfirm = false
    
    // Polling
    @State private var pollingTimer: Timer?
    @State private var previousRole: String? = nil
    @State private var showApprovedBanner = false
    
    // Error
    @State private var showErrorAlert = false
    
    // Accordion State
    @State private var isInviteCodeExpanded = false
    @State private var isMembersExpanded = false
    
    // UI states for new features
    @State private var showFullRecordsList = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showCopiedBanner = false
    
    var body: some View {
        alertsContent
    }
    
    private var alertsContent: some View {
        mainContent
            .navigationTitle("チーム管理".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if let team = viewModel.myTeam {
                            Menu {
                                Text("招待コード: \(team.invite_code)")
                                Button("コピーする", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = team.invite_code
                                    withAnimation {
                                        showCopiedBanner = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation {
                                            showCopiedBanner = false
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "key.fill").foregroundColor(Theme.accent)
                            }
                            
                            Button(action: { showMembersSheet = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "person.2.fill").foregroundColor(Theme.secondaryAccent)
                                    let pendingCount = viewModel.members.filter { $0.role == "pending" }.count
                                    if pendingCount > 0 {
                                        Text("\(pendingCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -6)
                                    }
                                }
                            }
                        }
                        Button(action: { Task { await viewModel.refreshMyTeamStatus() } }) {
                            Image(systemName: "arrow.clockwise").foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            .task { await initialLoad() }
            .onDisappear { stopApprovalPolling() }
            .onChange(of: viewModel.myRole) { _, newRole in handleRoleChange(newRole: newRole) }
            .onChange(of: viewModel.errorMessage) { _, error in if error != nil { showErrorAlert = true } }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
            }
            .alert("チームの解散", isPresented: $showDeleteConfirm, presenting: teamToDelete) { team in
                Button("解散する", role: .destructive) {
                    Task {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            viewModel.myTeam = nil
                        }
                        await viewModel.deleteTeam(teamID: team.id)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: { team in
                Text("チーム「\(team.name)」を本当に解散しますか？\nこの操作は取り消せません。")
            }
            .alert("チーム作成", isPresented: $showCreateAlert) {
                TextField("チーム名を入力", text: $newTeamName)
                Button("作成") { handleCreateTeam() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("作成するチームの名前を入力してください。")
            }
            .alert("チーム名の変更", isPresented: $showRenameAlert) {
                TextField("新しいチーム名を入力", text: $renameText)
                Button("保存") {
                    if let team = viewModel.myTeam {
                        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newName.isEmpty {
                            Task {
                                _ = await viewModel.updateTeamName(teamID: team.id, newName: newName)
                            }
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("チームの新しい名前を入力してください。")
            }
            .memberApprovalAlerts(
                showApproveConfirm: $showApproveConfirm,
                memberToApprove: $memberToApprove,
                showRejectConfirm: $showRejectConfirm,
                memberToReject: $memberToReject,
                showMemberOptions: $showMemberOptions,
                selectedMember: $selectedMember,
                onApprove: approveRequest,
                onReject: rejectRequest,
                menuContent: memberMenuContentAsAnyView
            )
            .sheet(isPresented: $showMembersSheet) {
                NavigationStack {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        ScrollView {
                            if let team = viewModel.myTeam {
                                VStack(spacing: 20) {
                                    pendingSection(team: team)
                                    activeMembersList(team: team)
                                }
                                .padding()
                            }
                        }
                    }
                    .navigationTitle("メンバー管理")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showMembersSheet = false }
                        }
                    }
                }
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.myTeam == nil {
                        headerSection
                    }
                    teamStateContent
                    if showApprovedBanner {
                        approvedBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .refreshable { await viewModel.refreshMyTeamStatus() }
            .animation(.spring(response: 0.4), value: viewModel.myRole)
            
            // コピートーストバナー
            if showCopiedBanner {
                VStack {
                    Spacer()
                    Text("クリップボードにコピーしました")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(radius: 10)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
            }
        }
    }
    
    @ViewBuilder
    private var teamStateContent: some View {
        if viewModel.isLoading && viewModel.myTeam == nil {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.accent)
                .padding(.top, 50)
        } else if let team = viewModel.myTeam {
            if viewModel.myRole == "pending" {
                pendingDashboard(team: team)
            } else {
                myTeamDashboard(team: team)
                    .onAppear {
                        Task {
                            await viewModel.fetchMembers(teamID: team.id)
                            await viewModel.fetchTeamWorkouts(teamID: team.id)
                        }
                    }
            }
        } else {
            createTeamSection
        }
    }
    
    // MARK: - Confirmation Dialog Content
    
    @ViewBuilder
    private func memberMenuContent(member: CloudflareUser) -> some View {
        if let teamID = viewModel.myTeam?.id {
            if member.role == "pending" {
                Button("参加を承認する") {
                    memberToApprove = member
                    showApproveConfirm = true
                }
                Button("参加を拒否する", role: .destructive) {
                    memberToReject = member
                    showRejectConfirm = true
                }
            } else if member.role != "owner" {
                memberNonOwnerMenuContent(member: member, teamID: teamID)
            }
        }
        Button("キャンセル", role: .cancel) {}
    }
    
    private func memberMenuContentAsAnyView(member: CloudflareUser) -> AnyView {
        AnyView(memberMenuContent(member: member))
    }
    
    @ViewBuilder
    private func memberNonOwnerMenuContent(member: CloudflareUser, teamID: String) -> some View {
        if member.role == "manager" {
            Button("Manager権限を解除") {
                Task { _ = await viewModel.updateMemberRole(userID: member.id, role: "athlete", teamID: teamID) }
            }
        } else if !hasPersonalManagerPlan(entitlement: member.entitlement) {
            let teamPlan = viewModel.myTeam?.plan ?? ""
            if usedManagerSlots() < managerLimit(for: teamPlan) {
                Button("Manager権限を付与") {
                    Task { _ = await viewModel.updateMemberRole(userID: member.id, role: "manager", teamID: teamID) }
                }
            }
        }
        
        if member.role != "admin" {
            Button("管理者に任命") {
                Task { _ = await viewModel.updateMemberRole(userID: member.id, role: "admin", teamID: teamID) }
            }
        } else {
            Button("管理者権限を解除") {
                Task { _ = await viewModel.updateMemberRole(userID: member.id, role: "athlete", teamID: teamID) }
            }
        }
        
        Button("チームから追放する", role: .destructive) {
            Task { _ = await viewModel.deleteMember(userID: member.id, teamID: teamID) }
        }
    }

    
    // MARK: - Action Handlers
    
    private func handleCreateTeam() {
        let name = newTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            await viewModel.createTeam(name: name)
            await viewModel.fetchMyTeam()
        }
    }
    
    private func approveRequest(member: CloudflareUser) {
        guard let teamID = viewModel.myTeam?.id else { return }
        Task {
            _ = await viewModel.updateMemberRole(userID: member.id, role: "athlete", teamID: teamID)
            await viewModel.fetchMembers(teamID: teamID)
        }
    }
    
    private func rejectRequest(member: CloudflareUser) {
        guard let teamID = viewModel.myTeam?.id else { return }
        Task {
            _ = await viewModel.deleteMember(userID: member.id, teamID: teamID)
        }
    }
    
    private func handleRoleChange(newRole: String?) {
        if previousRole == "pending" && newRole != nil && newRole != "pending" {
            withAnimation(.spring(response: 0.5)) { showApprovedBanner = true }
            stopApprovalPolling()
            Task {
                if let team = viewModel.myTeam {
                    await viewModel.fetchMembers(teamID: team.id)
                    await viewModel.fetchTeamWorkouts(teamID: team.id)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { showApprovedBanner = false }
            }
        }
        previousRole = newRole
    }
    
    // MARK: - Polling
    
    private func initialLoad() async {
        await viewModel.fetchMyTeam()
        previousRole = viewModel.myRole
        if viewModel.myRole == "pending" {
            startApprovalPolling()
        } else if let team = viewModel.myTeam {
            await viewModel.fetchMembers(teamID: team.id)
            await viewModel.fetchTeamWorkouts(teamID: team.id)
        }
    }
    
    private func startApprovalPolling() {
        stopApprovalPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                await viewModel.fetchMyTeam()
            }
        }
    }
    
    private func stopApprovalPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Approved Banner
    
    private var approvedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("チーム参加が承認されました！")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("チームダッシュボードが利用できます")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primaryGradient)
                .padding(.top, 24)
            
            Text("チームダッシュボード")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)
            
            Text("あなたのチームとメンバーを管理します")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Create Team Section
    
    private var createTeamSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "shield.righthalf.filled")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 10)
                
                Text("チームが見つかりません")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMain)
                
                Text("D1データベースにあなたのチームが登録されていません。\n新しいチームを作成してメンバーを招待しましょう！")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            Button(action: { newTeamName = ""; showCreateAlert = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("チームを新規作成").fontWeight(.bold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primaryGradient)
                .cornerRadius(16)
                .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
        }
        .padding(24)
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.1, cornerRadius: 24)
    }
    
    // MARK: - My Team Dashboard
    
    private func myTeamDashboard(team: Team) -> some View {
        VStack(spacing: 24) {
            teamSummaryCard(team: team)
            recordFeedSection
            if viewModel.myRole == "owner" {
                disbandButton(team: team)
            }
        }
    }
    
    private func disbandButton(team: Team) -> some View {
        Button(role: .destructive) {
            teamToDelete = team
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("チームを解散する").fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Team Info Card
    
    private func teamSummaryCard(team: Team) -> some View {
        let activeCount = viewModel.members.filter { $0.role != "pending" }.count
        let limit = memberLimit(for: team.plan)
        let isEditable = viewModel.myRole == "owner" || viewModel.myRole == "admin"
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("チーム名")
                        .font(.caption2).fontWeight(.bold).foregroundColor(Theme.accent)
                    HStack(spacing: 8) {
                        Text(team.name)
                            .font(.title2).fontWeight(.black).foregroundColor(.white)
                        if isEditable {
                            Button(action: {
                                renameText = team.name
                                showRenameAlert = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                }
                Spacer()
                Text(team.plan.uppercased())
                    .font(.caption).fontWeight(.bold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(planColor(for: team.plan).opacity(0.2))
                    .foregroundColor(planColor(for: team.plan))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 16) {
                statBadge(value: "\(activeCount) / \(limit)", label: "メンバー", icon: "person.2.fill", color: Theme.accent)
                if hasManagerShareFeature(for: team.plan) {
                    statBadge(value: "\(usedManagerSlots()) / \(managerLimit(for: team.plan))", label: "Manager", icon: "star.fill", color: .blue)
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
    }
    
    // MARK: - Invite Code Section (Removed, moved to Toolbar)
    
    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
    
    // MARK: - Pending Section（承認待ち専用・目立つデザイン）
    
    @ViewBuilder
    private func pendingSection(team: Team) -> some View {
        let pendingMembers = viewModel.members.filter { $0.role == "pending" }
        if !pendingMembers.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge.fill").foregroundColor(.orange)
                        Text("参加承認待ち")
                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(pendingMembers.count)件")
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.25))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
                
                VStack(spacing: 10) {
                    ForEach(pendingMembers, id: \.id) { member in
                        pendingMemberRow(member: member)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }
    
    private func pendingMemberRow(member: CloudflareUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 44, height: 44)
                Text(String(member.display_name.prefix(1)))
                    .font(.headline).fontWeight(.bold).foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.display_name)
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                Text("チームへの参加を申請しています")
                    .font(.caption2).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: { memberToReject = member; showRejectConfirm = true }) {
                    Image(systemName: "xmark").font(.caption).fontWeight(.bold)
                        .foregroundColor(.red).padding(8)
                        .background(Color.red.opacity(0.15)).clipShape(Circle())
                }
                Button(action: { memberToApprove = member; showApproveConfirm = true }) {
                    Image(systemName: "checkmark").font(.caption).fontWeight(.bold)
                        .foregroundColor(.green).padding(8)
                        .background(Color.green.opacity(0.2)).clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }
    
    // MARK: - Active Members Section (Moved to Sheet)
    
    private func activeMembersList(team: Team) -> some View {
        let activeMembers = viewModel.members.filter { $0.role != "pending" }
        return VStack(alignment: .leading, spacing: 16) {
            if activeMembers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32)).foregroundColor(.white.opacity(0.2))
                    Text("まだメンバーがいません")
                        .font(.subheadline).foregroundColor(.white.opacity(0.5))
                    Text("招待コードをメンバーに共有して\n申請を承認するとここに表示されます")
                        .font(.caption).foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(activeMembers, id: \.id) { member in
                        memberRow(member: member)
                        if member.id != activeMembers.last?.id {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(16)
            }
        }
    }
    
    private func memberRow(member: CloudflareUser) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor(for: member.role).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(member.display_name.prefix(1)))
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(roleColor(for: member.role))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.display_name)
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    if hasPersonalManagerPlan(entitlement: member.entitlement) {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                    }
                }
                HStack(spacing: 8) {
                    Text(displayRole(for: member.role))
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(roleColor(for: member.role).opacity(0.2))
                        .foregroundColor(roleColor(for: member.role))
                        .cornerRadius(5)
                    if member.role != "manager" && hasPersonalManagerPlan(entitlement: member.entitlement) {
                        Text("Personal Manager").font(.caption2).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            Spacer()
            if member.id != subManager.myUserRecordId {
                Button(action: { selectedMember = member; showMemberOptions = true }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white.opacity(0.4))
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
            } else {
                Text("自分").font(.caption2).foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.06)).cornerRadius(6)
            }
        }
        .padding(.vertical, 12).padding(.horizontal)
    }
    
    // MARK: - Pending Dashboard（申請者側）
    
    private func pendingDashboard(team: Team) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.15)).frame(width: 88, height: 88)
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 44)).foregroundColor(.orange)
                        .shadow(color: Color.orange.opacity(0.5), radius: 10)
                }
                .padding(.top, 20)
                
                Text("参加承認待ち").font(.title3).fontWeight(.bold).foregroundColor(Theme.textMain)
                
                VStack(spacing: 6) {
                    Text("「\(team.name)」への参加をリクエスト中です。")
                        .font(.subheadline).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                    Text("チームの管理者が承認するまでお待ちください。")
                        .font(.subheadline).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 8) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .orange)).scaleEffect(0.7)
                Text("15秒ごとに自動確認中...").font(.caption).foregroundColor(.orange.opacity(0.8))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.orange.opacity(0.08)).cornerRadius(10)
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("申請先チーム").font(.caption).foregroundColor(.white.opacity(0.5))
                    Text(team.name).font(.headline).fontWeight(.bold).foregroundColor(.white)
                }
                Spacer()
                Text(team.plan.uppercased())
                    .font(.caption).fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(planColor(for: team.plan).opacity(0.2))
                    .foregroundColor(planColor(for: team.plan))
                    .clipShape(Capsule())
            }
            .padding().background(Color.white.opacity(0.05)).cornerRadius(12)
            
            Button(role: .destructive, action: {
                Task {
                    _ = await viewModel.deleteMember(userID: subManager.myUserRecordId, teamID: team.id)
                    await viewModel.fetchMyTeam()
                    stopApprovalPolling()
                }
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("参加リクエストをキャンセル").fontWeight(.semibold)
                }
                .foregroundColor(.red.opacity(0.9))
                .frame(maxWidth: .infinity).padding()
                .background(Color.red.opacity(0.1)).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(24)
        .glassCardStyle(glowColor: Color.orange, opacity: 0.1, cornerRadius: 24)
    }
    
    // MARK: - Record Feed
    
    private var recordFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: "list.clipboard.fill").foregroundColor(Theme.accent)
                Text("トレーニング記録")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                if viewModel.teamWorkouts.count > 20 {
                    NavigationLink(destination:
                        ZStack {
                            Theme.background.ignoresSafeArea()
                            TeamWorkoutRecordListView(workouts: viewModel.teamWorkouts)
                        }
                        .navigationTitle("すべての記録")
                        .navigationBarTitleDisplayMode(.inline)
                    ) {
                        HStack(spacing: 4) {
                            Text("すべて見る")
                                .font(.caption).foregroundColor(Theme.accent)
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundColor(Theme.accent)
                        }
                    }
                }
            }

            // 最新20件を展開表示
            if viewModel.teamWorkouts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.2))
                    Text("まだトレーニング記録がありません")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let recentWorkouts = Array(viewModel.teamWorkouts.prefix(20))
                VStack(spacing: 0) {
                    ForEach(recentWorkouts) { record in
                        NavigationLink(destination: TeamWorkoutRecordDetailView(record: record)) {
                            inlineWorkoutRow(record: record)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if record.id != recentWorkouts.last?.id {
                            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 12)
                        }
                    }
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06, cornerRadius: 20)
    }

    private func inlineWorkoutRow(record: CloudflareWorkoutRecord) -> some View {
        HStack(spacing: 12) {
            // アバター（選手名頭文字）
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                Text(String((record.athlete_name ?? "?").prefix(1)))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.athlete_name ?? "不明")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    Spacer()
                    if let date = record.recordedDate {
                        Text(date, style: .date)
                            .font(.caption2).foregroundColor(.white.opacity(0.4))
                    }
                }
                HStack(spacing: 10) {
                    Label(record.formattedDistance, systemImage: "ruler")
                    Label(record.formattedDurationShort, systemImage: "clock")
                    Label(record.formattedSplit, systemImage: "speedometer")
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.55))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Helpers
    
    private func usedManagerSlots() -> Int {
        viewModel.members.filter { $0.role == "manager" && !hasPersonalManagerPlan(entitlement: $0.entitlement) }.count
    }
    
    private func hasPersonalManagerPlan(entitlement: String) -> Bool {
        let plan = SubscriptionPlan(rawValue: entitlement) ?? .free
        return plan.isAtLeast(.manager)
    }
    
    private func hasManagerShareFeature(for plan: String) -> Bool {
        let p = SubscriptionPlan(rawValue: plan) ?? .free
        return p.isAtLeast(.team)
    }
    
    private func managerLimit(for plan: String) -> Int {
        switch plan.lowercased() {
        case "team": return 3
        case "max": return 5
        case "organization": return 10
        default: return 0
        }
    }
    
    private func memberLimit(for plan: String) -> Int {
        switch plan.lowercased() {
        case "team": return 30
        case "max": return 50
        case "organization": return 200
        default: return 30
        }
    }
    
    private func displayRole(for role: String) -> String {
        switch role.lowercased() {
        case "owner": return "最高管理者"
        case "admin": return "管理者"
        case "manager": return "Manager"
        case "athlete": return "選手"
        default: return role.capitalized
        }
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "owner": return .red
        case "admin": return .orange
        case "manager": return .blue
        case "athlete": return .green
        default: return .gray
        }
    }
    
    private func planColor(for plan: String) -> Color {
        switch plan.lowercased() {
        case "max": return .purple
        case "organization": return .cyan
        case "team": return .orange
        case "manager": return .blue
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        CloudflareTeamListView()
    }
}

// MARK: - Member Approval Alerts Extension

private struct MemberApprovalAlertsModifier: ViewModifier {
    @Binding var showApproveConfirm: Bool
    @Binding var memberToApprove: CloudflareUser?
    @Binding var showRejectConfirm: Bool
    @Binding var memberToReject: CloudflareUser?
    @Binding var showMemberOptions: Bool
    @Binding var selectedMember: CloudflareUser?
    let onApprove: (CloudflareUser) -> Void
    let onReject: (CloudflareUser) -> Void
    let menuContent: (CloudflareUser) -> AnyView
    
    func body(content: Content) -> some View {
        content
            .alert("参加を承認", isPresented: $showApproveConfirm, presenting: memberToApprove) { member in
                Button("承認する") { onApprove(member) }
                Button("キャンセル", role: .cancel) {}
            } message: { member in
                Text("「\(member.display_name)」のチーム参加を承認しますか？")
            }
            .alert("参加を拒否", isPresented: $showRejectConfirm, presenting: memberToReject) { member in
                Button("拒否する", role: .destructive) { onReject(member) }
                Button("キャンセル", role: .cancel) {}
            } message: { member in
                Text("「\(member.display_name)」の参加申請を拒否しますか？")
            }
            .confirmationDialog("メンバー設定", isPresented: $showMemberOptions, titleVisibility: .visible, presenting: selectedMember) { member in
                menuContent(member)
            } message: { member in
                Text("\(member.display_name) の設定を変更します。")
            }
    }
}

extension View {
    func memberApprovalAlerts(
        showApproveConfirm: Binding<Bool>,
        memberToApprove: Binding<CloudflareUser?>,
        showRejectConfirm: Binding<Bool>,
        memberToReject: Binding<CloudflareUser?>,
        showMemberOptions: Binding<Bool>,
        selectedMember: Binding<CloudflareUser?>,
        onApprove: @escaping (CloudflareUser) -> Void,
        onReject: @escaping (CloudflareUser) -> Void,
        menuContent: @escaping (CloudflareUser) -> AnyView
    ) -> some View {
        modifier(MemberApprovalAlertsModifier(
            showApproveConfirm: showApproveConfirm,
            memberToApprove: memberToApprove,
            showRejectConfirm: showRejectConfirm,
            memberToReject: memberToReject,
            showMemberOptions: showMemberOptions,
            selectedMember: selectedMember,
            onApprove: onApprove,
            onReject: onReject,
            menuContent: menuContent
        ))
    }
}
