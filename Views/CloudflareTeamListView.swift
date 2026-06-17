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
    
    // Error handling
    @State private var showErrorAlert = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if viewModel.isLoading && viewModel.teams.isEmpty {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Theme.accent)
                            .padding(.top, 50)
                    } else if let team = viewModel.myTeam {
                        myTeamDashboard(team: team)
                            .onAppear {
                                Task {
                                    await viewModel.fetchMembers(teamID: team.id)
                                }
                            }
                    } else {
                        createTeamSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.fetchTeams()
                if let team = viewModel.myTeam {
                    await viewModel.fetchMembers(teamID: team.id)
                }
            }
        }
        .navigationTitle("チーム管理".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { 
                        await viewModel.fetchTeams()
                        if let team = viewModel.myTeam {
                            await viewModel.fetchMembers(teamID: team.id)
                        }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .task {
            await viewModel.fetchTeams()
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if error != nil {
                showErrorAlert = true
            }
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
        }
        .alert("チームの削除", isPresented: $showDeleteConfirm, presenting: teamToDelete) { team in
            Button("削除", role: .destructive) {
                Task {
                    await viewModel.deleteTeam(teamID: team.id)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { team in
            Text("チーム「\(team.name)」を本当に削除しますか？\nこの操作は取り消せません。")
        }
        .alert("チーム作成", isPresented: $showCreateAlert) {
            TextField("チーム名を入力", text: $newTeamName)
            Button("作成") {
                let name = newTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    Task {
                        await viewModel.createTeam(name: name)
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("作成するチームの名前を入力してください。")
        }
        .confirmationDialog("メンバー設定", isPresented: $showMemberOptions, titleVisibility: .visible, presenting: selectedMember) { member in
            if member.role != "owner" {
                if member.role == "manager" {
                    Button("Manager権限を解除") {
                        Task { await viewModel.updateMemberRole(userID: member.id, role: "athlete", teamID: member.team_id) }
                    }
                } else if !hasPersonalManagerPlan(entitlement: member.entitlement) {
                    let teamPlan = viewModel.myTeam?.plan ?? ""
                    if usedManagerSlots() < managerLimit(for: teamPlan) {
                        Button("Manager権限を付与") {
                            Task { await viewModel.updateMemberRole(userID: member.id, role: "manager", teamID: member.team_id) }
                        }
                    }
                }
                
                if member.role != "admin" {
                    Button("管理者に任命") {
                        Task { await viewModel.updateMemberRole(userID: member.id, role: "admin", teamID: member.team_id) }
                    }
                } else {
                    Button("管理者権限を解除") {
                        Task { await viewModel.updateMemberRole(userID: member.id, role: "athlete", teamID: member.team_id) }
                    }
                }
                
                Button("チームから追放する", role: .destructive) {
                    Task { await viewModel.deleteMember(userID: member.id, teamID: member.team_id) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { member in
            Text("\(member.display_name) の設定を変更します。")
        }
    }
    
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
            
            Button(action: {
                newTeamName = ""
                showCreateAlert = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("チームを新規作成")
                        .fontWeight(.bold)
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
    
    private func myTeamDashboard(team: Team) -> some View {
        VStack(spacing: 24) {
            // Team Info Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEAM NAME")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.accent)
                        Text(team.name)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    Text(team.plan.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(planColor(for: team.plan).opacity(0.2))
                        .foregroundColor(planColor(for: team.plan))
                        .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("招待コード")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Text(team.invite_code)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .tracking(2)
                    }
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = team.invite_code
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(Theme.accent)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
            }
            .padding()
            .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 20)
            
            // Members Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Theme.secondaryAccent)
                    Text("メンバー管理")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("メンバー: \(viewModel.members.count) / \(memberLimit(for: team.plan))")
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        if hasManagerShareFeature(for: team.plan) {
                            Text("Manager共有: \(usedManagerSlots()) / \(managerLimit(for: team.plan))")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                if viewModel.members.isEmpty {
                    VStack {
                        Text("まだメンバーがいません")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.members, id: \.id) { member in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.secondaryAccent.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Text(String(member.display_name.prefix(1)))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.secondaryAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(member.display_name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        if hasPersonalManagerPlan(entitlement: member.entitlement) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(displayRole(for: member.role))
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(roleColor(for: member.role).opacity(0.2))
                                            .foregroundColor(roleColor(for: member.role))
                                            .cornerRadius(4)
                                        
                                        if member.role != "manager" && hasPersonalManagerPlan(entitlement: member.entitlement) {
                                            Text("Personal Manager")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if member.id != subManager.myUserRecordId { // 自身は編集不可
                                    Button(action: {
                                        selectedMember = member
                                        showMemberOptions = true
                                    }) {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(8)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            
                            if member.id != viewModel.members.last?.id {
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                }
            }
            .padding()
            .glassCardStyle(glowColor: Theme.secondaryAccent, opacity: 0.05, cornerRadius: 20)
            
            // Delete Team Button
            Button(role: .destructive) {
                teamToDelete = team
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("チームを解散する")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func usedManagerSlots() -> Int {
        return viewModel.members.filter { member in
            member.role == "manager" && !hasPersonalManagerPlan(entitlement: member.entitlement)
        }.count
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
