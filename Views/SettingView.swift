import SwiftUI

struct SettingView: View {
    @EnvironmentObject var app: AppViewModel
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var devMode = DeveloperModeManager.shared
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingResetAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingTargetEditAlert = false
    @State private var targetDistanceInput = ""
    @State private var showingICloudDeleteAlert = false
    @State private var showingICloudSyncAllAlert = false
    @ObservedObject private var iCloudSync = ICloudSyncManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    @ObservedObject private var teamViewModel = CloudflareTeamViewModel.shared
    @State private var showingProfileSaveResult = false
    @State private var profileSaveMessage = ""
    @AppStorage("isCloudflareProfileRegistered") private var isProfileRegistered = false
    
    @State private var showingApprovalAlert = false
    @State private var showingPendingAlert = false
    @State private var isCheckingApproval = false
    @AppStorage("lastKnownTeamRole") private var lastKnownTeamRole: String = ""
    @State private var profileSyncTask: Task<Void, Never>? = nil
    @State private var approvalTimer: Timer? = nil
    
    // Developer Mode Toast
    @State private var devModeToastMessage: String = ""
    @State private var showDevModeToast: Bool = false
    @State private var devModeToastTask: Task<Void, Never>? = nil
    
    private var isJA: Bool {
        localizationManager.language == .japanese
    }

    var body: some View {
        NavigationStack(path: $app.settingsNavigationPath) {
            mainScrollArea
                .navigationTitle("Settings".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .alert("Reset Settings".localized, isPresented: $showingResetAlert) {
                    Button("Reset".localized, role: .destructive) {
                        settingsManager.resetToDefaults()
                    }
                    Button("Cancel".localized, role: .cancel) {}
                } message: {
                    Text("Reset Alert Message".localized)
                }
                .alert(isJA ? "月間目標距離の変更" : "Change Monthly Goal", isPresented: $showingTargetEditAlert) {
                    TextField(isJA ? "目標距離 (km)" : "Target Distance (km)", text: $targetDistanceInput)
                        .keyboardType(.decimalPad)
                    Button(isJA ? "保存" : "Save") {
                        if let km = Double(targetDistanceInput), km > 0 {
                            settingsManager.settings.monthlyTargetDistance = km * 1000.0
                        }
                    }
                    Button(isJA ? "キャンセル" : "Cancel", role: .cancel) {}
                } message: {
                    Text(isJA ? "新しい月間目標距離をキロメートル(km)単位で入力してください。" : "Please enter the new monthly target distance in kilometers (km).")
                }
                .alert("Delete All Workouts".localized, isPresented: $showingDeleteAllAlert) {
                    Button("Delete".localized, role: .destructive) {
                        app.recordManager.deleteAllRecords()
                    }
                    Button("Cancel".localized, role: .cancel) {}
                } message: {
                    Text("Delete All Alert Message".localized)
                }
                .alert("iCloudのデータを削除", isPresented: $showingICloudDeleteAlert) {
                    Button("すべて削除", role: .destructive) {
                        ICloudSyncManager.shared.deleteAllFromICloud { _ in }
                    }
                    Button("キャンセル", role: .cancel) {
                        settingsManager.settings.iCloudSyncEnabled = true
                    }
                } message: {
                    Text("iCloud上のRowPilotのデータをすべて削除しますか？\nこの操作は取り消せません。ローカルのデータには影響しません。")
                }
        }
        .alert("iCloud同期", isPresented: $showingICloudSyncAllAlert) {
            Button("今すぐ同期", role: .none) {
                ICloudSyncManager.shared.syncAll(records: app.recordManager.records)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ローカルのすべての記録（\(app.recordManager.records.count)件）をiCloudにアップロードします。")
        }
        .alert(isJA ? "プロフィール保存" : "Profile Save", isPresented: $showingProfileSaveResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profileSaveMessage)
        }
        .alert(isJA ? "参加承認" : "Join Approved", isPresented: $showingApprovalAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isJA ? "チームへの参加が承認されました！" : "Your request to join the team has been approved!")
        }
        .alert(isJA ? "承認待ち" : "Pending Approval", isPresented: $showingPendingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isJA ? "まだ申請が通っていません。管理者の承認をお待ちください。" : "Your request is still pending. Please wait for the admin's approval.")
        }
        .task {
            await teamViewModel.fetchMyTeam()
            checkTeamApprovalStatus()
            if teamViewModel.myRole == "pending" {
                startApprovalPolling()
            }
        }
        .onDisappear {
            stopApprovalPolling()
        }
        .onChange(of: teamViewModel.myRole) { _, newRole in
            if newRole == "pending" {
                startApprovalPolling()
            } else {
                stopApprovalPolling()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamJoinStatusChanged"))) { _ in
            Task {
                await teamViewModel.fetchMyTeam()
                checkTeamApprovalStatus()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await teamViewModel.fetchMyTeam()
                    checkTeamApprovalStatus()
                }
            }
        }
        .onChange(of: settingsManager.settings.sharingName) { _, newName in
            profileSyncTask?.cancel()
            profileSyncTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    await MainActor.run {
                        isProfileRegistered = false
                    }
                    return
                }
                
                let success = await teamViewModel.createUser(
                    userID: SubscriptionManager.shared.myUserRecordId,
                    displayName: trimmed,
                    email: nil,
                    isGhost: 0,
                    entitlement: SubscriptionManager.shared.currentPlan.rawValue
                )
                
                await MainActor.run {
                    if success {
                        isProfileRegistered = true
                    }
                }
            }
        }
    }

    private var mainScrollArea: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                settingsContent.padding()
            }

            if showDevModeToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: devMode.isEnabled ? "hammer.fill" : "hammer")
                            .foregroundColor(devMode.isEnabled ? Theme.accent : Theme.textSecondary)
                        Text(devModeToastMessage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textMain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showDevModeToast)
            }
        }
    }
    
    private func checkTeamApprovalStatus() {
        if let role = teamViewModel.myRole {
            if lastKnownTeamRole == "pending" && (role == "athlete" || role == "manager" || role == "admin") {
                showingApprovalAlert = true
            }
            lastKnownTeamRole = role
        } else {
            lastKnownTeamRole = ""
        }
    }
    
    private func startApprovalPolling() {
        approvalTimer?.invalidate()
        approvalTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await teamViewModel.fetchMyTeam()
                await MainActor.run {
                    checkTeamApprovalStatus()
                }
            }
        }
    }
    
    private func stopApprovalPolling() {
        approvalTimer?.invalidate()
        approvalTimer = nil
    }
    
    private func checkApprovalManually() {
        isCheckingApproval = true
        Task {
            await teamViewModel.fetchMyTeam()
            await MainActor.run {
                isCheckingApproval = false
                if let role = teamViewModel.myRole, role != "pending" {
                    showingApprovalAlert = true
                    lastKnownTeamRole = role
                } else {
                    showingPendingAlert = true
                }
            }
        }
    }
    
    private var settingsContent: some View {
        VStack(spacing: 24) {
            // Subscription Upgrade Card
            NavigationLink(destination: SubscriptionView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RowPilot Premium".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Unlock all features and power up your rowing.".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color(hex: "00d2ff"), Color(hex: "3a7bd5")]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(16)
                .shadow(color: Color(hex: "00d2ff").opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.bottom, 8)
            
            // 言語設定 (Language)
             SettingsSection(title: "Language".localized, icon: "globe") {
                 HStack {
                     Text("Language".localized)
                         .foregroundColor(Theme.textMain)
                     Spacer()
                     Picker("Language".localized, selection: $settingsManager.settings.language) {
                         ForEach(AppLanguage.allCases, id: \.self) { lang in
                             Text(lang.rawValue).tag(lang)
                         }
                     }
                     .tint(Theme.accent)
                     .onChange(of: settingsManager.settings.language) { oldValue, newValue in
                         localizationManager.setLanguage(newValue)
                     }
                 }
             }

            // テーマ設定
            SettingsSection(title: "Theme".localized, icon: "paintbrush.fill") {
                 VStack(alignment: .leading, spacing: 12) {
                     Text("Color Theme".localized)
                         .foregroundColor(Theme.textMain)
                         .font(.caption)
                     
                     ScrollView(.horizontal, showsIndicators: false) {
                         HStack(spacing: 12) {
                             ForEach(ThemePreset.allCases) { preset in
                                 ThemePreviewButton(preset: preset, isSelected: themeManager.currentPreset == preset) {
                                     themeManager.setTheme(preset)
                                 }
                             }
                         }
                     }
                 }
            }
            
            // SOS設定
            if UIDevice.current.userInterfaceIdiom != .pad {
                SettingsSection(title: "Emergency Contact".localized, icon: "sos") {
                    NavigationLink(value: "SOSSettings") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SOS Settings".localized)
                                    .foregroundColor(Theme.textMain)
                                if !settingsManager.settings.sosContactName.isEmpty {
                                    Text(settingsManager.settings.sosContactName)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // ユーザープロフィール
            SettingsSection(title: localizationManager.language == .japanese ? "ユーザープロフィール" : "User Profile", icon: "person.crop.circle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizationManager.language == .japanese ? "表示名" : "Display Name")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    HStack {
                        TextField(localizationManager.language == .japanese ? "表示名を入力" : "Enter display name", text: $settingsManager.settings.sharingName)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .foregroundColor(Theme.textMain)
                        
                        Spacer()
                        
                        if teamViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        } else if isProfileRegistered && !settingsManager.settings.sharingName.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(localizationManager.language == .japanese ? "同期完了" : "Synced")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Theme.textSecondary.opacity(0.3))
                    
                    Text("Sharing Name Hint".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if let authErr = subManager.authErrorMessage, !authErr.isEmpty {
                        Divider().background(Theme.textSecondary.opacity(0.3))
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authErr)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("機種変更などで端末認証がロックされた場合は、チームの管理者またはオーナーに「端末認証ロックを解除」を依頼してから再度お試しください。")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            

            // 表示設定
            SettingsSection(title: "Display".localized, icon: "display") {
                SettingsToggleRow(title: "Show Battery".localized, isOn: $settingsManager.settings.showBatteryStatus)
                SettingsToggleRow(title: "Show GPS Accuracy".localized, isOn: $settingsManager.settings.showGPSAccuracy)
                SettingsToggleRow(title: "Show Help Buttons".localized, isOn: $settingsManager.settings.showHelpButtons)
                
                if UIDevice.current.userInterfaceIdiom != .pad {
                    Divider().background(Theme.textSecondary.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        SettingsToggleRow(title: "Prevent Screen Dimming".localized, isOn: $settingsManager.settings.preventScreenDimming)
                        Text("Screen Dimming Warning Hint".localized)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Divider().background(Theme.textSecondary.opacity(0.3))
                
                // 天気表示モード
                HStack {
                    Label("Weather Display".localized, systemImage: "cloud.sun.fill")
                        .foregroundColor(Theme.textMain)
                    Spacer()
                    Picker("", selection: $settingsManager.settings.weatherDisplayMode) {
                        ForEach(WeatherDisplayMode.allCases) { mode in
                            Text(mode.rawValue.localized).tag(mode)
                        }
                    }
                    .tint(Theme.accent)
                }
            }
            
            // 計測設定
            SettingsSection(title: "Measurement".localized, icon: "stopwatch.fill") {
                SettingsToggleRow(title: "Auto Start".localized, isOn: $settingsManager.settings.autoStartOnMotion)
                
                Divider().background(Theme.textSecondary.opacity(0.3))
                
                HStack {
                    Text(localizationManager.language == .japanese ? "月間目標距離" : "Monthly Target Distance")
                        .foregroundColor(Theme.textMain)
                    Spacer()
                    Button(action: {
                        targetDistanceInput = String(Int(settingsManager.settings.monthlyTargetDistance / 1000))
                        showingTargetEditAlert = true
                    }) {
                        Text("\(Int(settingsManager.settings.monthlyTargetDistance / 1000)) km")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            
            // 複数PM5制御 / マネージャーモード設定（Pro以上で表示）
            if currentPlan.hasMultiPM5Control {
                SettingsSection(title: currentPlan.pm5FeatureTitle, icon: "person.3.sequence.fill") {
                    SettingsToggleRow(title: "Save 0-Record PM5s".localized, isOn: $settingsManager.settings.saveZeroRecordPM5s)
                }
            }
            
            // チーム管理リンク（個人プランでTeam以上を契約している場合）
            if subManager.ownPlan.hasTeamFeature {
                SettingsSection(title: "Team Management".localized, icon: "person.3.fill") {
                    Divider().background(Theme.textSecondary.opacity(0.3))
                    NavigationLink(destination: CloudflareTeamListView()) {
                        HStack {
                            Text("Manage Teammates".localized)
                                .foregroundColor(Theme.textMain)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // チーム参加申請中（pending時）のステータス表示
            if teamViewModel.myRole == "pending" {
                SettingsSection(title: localizationManager.language == .japanese ? "チーム参加申請中" : "Team Request Pending", icon: "clock.badge.checkmark.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let teamName = teamViewModel.myTeam?.name {
                                    Text(teamName)
                                        .font(.headline)
                                        .foregroundColor(Theme.textMain)
                                }
                                Text(localizationManager.language == .japanese ? "承認待ち" : "Pending Approval")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Button(action: {
                                checkApprovalManually()
                            }) {
                                HStack(spacing: 6) {
                                    if isCheckingApproval {
                                        ProgressView()
                                            .tint(Theme.accent)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(localizationManager.language == .japanese ? "更新を確認" : "Check Status")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.accent.opacity(0.15))
                                .foregroundColor(Theme.accent)
                                .cornerRadius(8)
                            }
                            .disabled(isCheckingApproval)
                        }
                        
                        Divider().background(Theme.textSecondary.opacity(0.2))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.language == .japanese ? "1分おきにチームの承認が通ったか確認します。" : "Checking for team approval periodically.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Text(localizationManager.language == .japanese ? "チームに承認された場合、自動で参加します。" : "You will automatically join the team once approved.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // ─── チーム機能セクション ───
            if teamViewModel.myTeam != nil && teamViewModel.myRole != "pending" {
                SettingsSection(title: "チーム管理".localized, icon: "person.3.fill") {
                    if !subManager.ownPlan.hasTeamFeature {
                        NavigationLink(destination: CloudflareTeamListView()) {
                            HStack {
                                Text("チームを見る".localized)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Divider().background(Theme.textSecondary.opacity(0.3))
                    }
                    SettingsToggleRow(
                        title: "チームへ自動で記録をアップロードする",
                        isOn: $settingsManager.settings.autoUploadToTeam
                    )
                    Text("オンにすると、ワークアウト保存時に所属しているチームに自動で記録が共有されます。".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            

            // 共有設定
            SettingsSection(title: "Sharing".localized, icon: "square.and.arrow.up") {
                // マネージャーモード保存後の共有提案
                if currentPlan.hasManagerMode {
                    SettingsToggleRow(
                        title: "Auto Share After Save".localized,
                        isOn: $settingsManager.settings.autoShareAfterManagerSave
                    )
                    
                    Text("Auto Share Desc".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider().background(Theme.textSecondary.opacity(0.3))
                
                // 受信時のインポート挙動
                HStack {
                    Text("Import Behavior".localized)
                        .foregroundColor(Theme.textMain)
                    Spacer()
                    Picker("", selection: $settingsManager.settings.importBehavior) {
                        ForEach(ImportBehavior.allCases) { behavior in
                            Text(behavior.rawValue.localized).tag(behavior)
                        }
                    }
                    .tint(Theme.accent)
                }
                
                Text("Import Behavior Desc".localized)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 単位設定
            SettingsSection(title: "Units".localized, icon: "ruler.fill") {
                HStack {
                    Text("Distance".localized)
                        .foregroundColor(Theme.textMain)
                    Spacer()
                    Picker("Distance".localized, selection: $settingsManager.settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .tint(Theme.accent)
                }
                
                HStack {
                    Text("Speed".localized)
                        .foregroundColor(Theme.textMain)
                    Spacer()
                    Picker("Speed".localized, selection: $settingsManager.settings.speedUnit) {
                        ForEach(SpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .tint(Theme.accent)
                }
            }
            // データ同期
             SettingsSection(title: "Data Sync".localized, icon: "icloud.fill") {
                 VStack(alignment: .leading, spacing: 10) {
                     Toggle("記録を自動でiCloudに同期", isOn: Binding(
                         get: { settingsManager.settings.iCloudSyncEnabled },
                         set: { newValue in
                             if !newValue {
                                 // OFFにする際に確認アラート
                                 showingICloudDeleteAlert = true
                             }
                             settingsManager.settings.iCloudSyncEnabled = newValue
                         }
                     ))
                     .foregroundColor(Theme.textMain)
                     .tint(Theme.accent)
                     
                     if settingsManager.settings.iCloudSyncEnabled {
                         // iCloud利用可否の表示（非同期で確認済み）
                         // ※ CoreData(CloudKit)での同期は常に動作中。この表示はiCloud Driveへの追加バックアップの状態。
                         HStack(spacing: 6) {
                             Image(systemName: iCloudSync.isAvailable ? "checkmark.icloud.fill" : "icloud.fill")
                                 .foregroundColor(iCloudSync.isAvailable ? .green : Theme.textSecondary)
                                 .font(.caption)
                             Text(iCloudSync.isAvailable ? "iCloud Drive同期: 有効" : "iCloud Drive: 確認中...")
                                 .font(.caption)
                                 .foregroundColor(Theme.textSecondary)
                         }
                         
                         if let lastSync = iCloudSync.lastSyncDate {
                             Text("最終同期: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                 .font(.caption2)
                                 .foregroundColor(Theme.textSecondary)
                         }
                         
                         if let error = iCloudSync.syncError {
                             Text("⚠️ \(error)")
                                 .font(.caption2)
                                 .foregroundColor(.orange)
                         }
                         
                         Divider().background(Theme.textSecondary.opacity(0.3))
                         
                         // 今すぐ全記録を同期
                         Button(action: { showingICloudSyncAllAlert = true }) {
                             HStack {
                                 Image(systemName: iCloudSync.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.up")
                                     .symbolEffect(.rotate, isActive: iCloudSync.isSyncing)
                                 Text(iCloudSync.isSyncing ? "同期中..." : "今すぐ全記録を同期")
                                     .foregroundColor(Theme.textMain)
                                 Spacer()
                             }
                             .foregroundColor(Theme.accent)
                         }
                         .disabled(iCloudSync.isSyncing)
                         
                         // iCloud上のデータを削除
                         Button(action: { showingICloudDeleteAlert = true }) {
                             HStack {
                                 Image(systemName: "trash.fill")
                                 Text("iCloudのRowPilotデータを削除")
                                 Spacer()
                             }
                             .foregroundColor(.red)
                         }
                     }
                     
                     Text("iCloud Sync Notice".localized)
                         .font(.caption)
                         .foregroundColor(Theme.textSecondary)
                 }
             }
             
             // コンタクト (Contact)
             SettingsSection(title: "Contact".localized, icon: "envelope.fill") {
                 NavigationLink(destination: InquiryView()) {
                     HStack {
                         Text("Contact Us".localized)
                             .foregroundColor(Theme.textMain)
                         Spacer()
                         Image(systemName: "chevron.right")
                             .font(.caption)
                             .foregroundColor(Theme.textSecondary)
                     }
                 }
             }
             
             // 利用規約 (目立ちやすいようにセクション化)
             SettingsSection(title: "Terms of Service".localized, icon: "doc.text.fill") {
                 NavigationLink(destination: TermsView()) {
                     HStack {
                         Text("Terms of Service".localized)
                             .foregroundColor(Theme.textMain)
                         Spacer()
                         Image(systemName: "chevron.right")
                             .font(.caption)
                             .foregroundColor(Theme.textSecondary)
                     }
                 }
             }
            
            // リセット
            Button(action: {
                showingResetAlert = true
            }) {
                Text("Reset Settings".localized)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
            }
            
            // すべてのワークアウトを消去
            Button(action: {
                showingDeleteAllAlert = true
            }) {
                Text("Delete All Workouts".localized)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
            }
            
            // 開発者モードセクション（有効時のみ表示）
            if devMode.isEnabled {
                developerSection
            }

            // アプリ情報
            VStack(spacing: 8) {
                NavigationLink(destination: AboutRowPilotView()) {
                    Text("About RowPilot")
                        .underline()
                }
                NavigationLink(destination: CreditsView()) {
                    Text("Credits".localized)
                        .underline()
                }
                // バージョン行: 5回タップで開発者モードトグル
                VStack(spacing: 2) {
                    Text("TestFlight Version 1.0.1(Build 3)")
                    Text("Build from August 5")
                    if devMode.isEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "hammer.fill")
                                .font(.caption2)
                            Text("Developer Mode ON")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(Theme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    let event = devMode.handleVersionTap()
                    switch event {
                    case .enabled:
                        showDevToast("Developer mode enabled")
                    case .disabled:
                        showDevToast("Developer mode disabled")
                    case .countdown(let remaining):
                        if remaining <= 3 {
                            showDevToast("あと\(remaining)回")
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom)
        }
        .navigationDestination(for: String.self) { value in
            if value == "SOSSettings" {
                SOSSettingsView()
            }
        }
    }
}

// MARK: - Developer Mode Section & Toast
extension SettingView {
    /// 開発者モードが有効な時のみ表示される設定セクション
    @ViewBuilder
    var developerSection: some View {
        SettingsSection(title: "Developer Options", icon: "hammer.fill") {
            // マネージャーモード最大接続台数
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "personalhotspot")
                        .foregroundColor(Theme.accent)
                        .font(.caption)
                    Text("Manager Max Connections")
                        .foregroundColor(Theme.textMain)
                        .font(.subheadline)
                    Spacer()
                    Text("\(devMode.maxPM5Connections) devices")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                        .fontWeight(.bold)
                }

                HStack(spacing: 12) {
                    Button {
                        if devMode.maxPM5Connections > 1 { devMode.maxPM5Connections -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(devMode.maxPM5Connections <= 1 ? .gray : Theme.accent)
                    }
                    .disabled(devMode.maxPM5Connections <= 1)

                    Slider(
                        value: Binding(
                            get: { Double(devMode.maxPM5Connections) },
                            set: { devMode.maxPM5Connections = Int($0) }
                        ),
                        in: 1...20,
                        step: 1
                    )
                    .tint(Theme.accent)

                    Button {
                        if devMode.maxPM5Connections < 20 { devMode.maxPM5Connections += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(devMode.maxPM5Connections >= 20 ? .gray : Theme.accent)
                    }
                    .disabled(devMode.maxPM5Connections >= 20)
                }

                HStack {
                    Text("1").font(.caption2).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("20").font(.caption2).foregroundColor(Theme.textSecondary)
                }

                Text("⚠️ 20台はBLE実験的制限です。実機での動作保証外。")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            Divider().background(Color.white.opacity(0.1))

            // 開発者モードを無効にするボタン
            Button {
                devMode.disable()
                showDevToast("Developer mode disabled")
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disable Developer Mode")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
    }

    /// Developer Mode のトーストを表示するヘルパー
    func showDevToast(_ message: String) {
        devModeToastTask?.cancel()
        devModeToastMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showDevModeToast = true
        }
        devModeToastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation { showDevModeToast = false }
            }
        }
    }
}

// MARK: - Helpers

struct ThemePreviewButton: View {
    let preset: ThemePreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                .fill(LinearGradient(gradient: Gradient(colors: preset.backgroundColors), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(radius: 3)
            
            Text(preset.rawValue)
                .font(.caption)
                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(Theme.subHeaderFont())
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(spacing: 16) {
                content
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .foregroundColor(Theme.textMain)
            .tint(Theme.accent)
    }
}

#Preview {
    SettingView()
}
