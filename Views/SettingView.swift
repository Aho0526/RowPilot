import SwiftUI

struct SettingView: View {
    @EnvironmentObject var app: AppViewModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingResetAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingTargetEditAlert = false
    @State private var targetDistanceInput = ""
    @State private var showingInviteCodeInput = false
    @State private var showingTeamCodeInput = false
    // CloudKitTeamManager依存を削除（Cloudflare移行中）
    // @ObservedObject private var ckTeam = CloudKitTeamManager.shared
    @State private var showingICloudDeleteAlert = false
    @State private var showingICloudSyncAllAlert = false
    @ObservedObject private var iCloudSync = ICloudSyncManager.shared
    
    var body: some View {
        NavigationStack(path: $app.settingsNavigationPath) {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    settingsContent.padding()
                }
            }
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
            .alert(localizationManager.language == .japanese ? "月間目標距離の変更" : "Change Monthly Goal", isPresented: $showingTargetEditAlert) {
                TextField(localizationManager.language == .japanese ? "目標距離 (km)" : "Target Distance (km)", text: $targetDistanceInput)
                    .keyboardType(.decimalPad)
                Button(localizationManager.language == .japanese ? "保存" : "Save") {
                    if let km = Double(targetDistanceInput), km > 0 {
                        settingsManager.settings.monthlyTargetDistance = km * 1000.0
                    }
                }
                Button(localizationManager.language == .japanese ? "キャンセル" : "Cancel", role: .cancel) {}
            } message: {
                Text(localizationManager.language == .japanese ? "新しい月間目標距離をキロメートル(km)単位で入力してください。" : "Please enter the new monthly target distance in kilometers (km).")
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
                    // OFFにしたがキャンセル → トグルを戻す
                    settingsManager.settings.iCloudSyncEnabled = true
                }
            } message: {
                Text("iCloud上のRowPilotのデータをすべて削除しますか？\nこの操作は取り消せません。ローカルのデータには影響しません。")
            }
            .alert("iCloud同期", isPresented: $showingICloudSyncAllAlert) {
                Button("今すぐ同期", role: .none) {
                    ICloudSyncManager.shared.syncAll(records: app.recordManager.records)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ローカルのすべての記録（\(app.recordManager.records.count)件）をiCloudにアップロードします。")
            }
            .sheet(isPresented: $showingInviteCodeInput) {
                InviteCodeInputView()
            }
            .sheet(isPresented: $showingTeamCodeInput) {
                TeamInviteCodeInputView()
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
            
            // 共有時の名前
            SettingsSection(title: "Sharing Name".localized, icon: "person.crop.circle.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(localizationManager.language == .japanese ? "表示名を入力" : "Enter display name", text: $settingsManager.settings.sharingName)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundColor(Theme.textMain)
                    
                    Divider()
                        .background(Theme.textSecondary.opacity(0.3))
                    
                    Text("Sharing Name Hint".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
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
            
            // マネージャー設定（サブスク解放時のみ表示）
            if currentPlan.hasManagerMode {
                SettingsSection(title: "Manager Mode".localized, icon: "person.3.sequence.fill") {
                    SettingsToggleRow(title: "Save 0-Record PM5s".localized, isOn: $settingsManager.settings.saveZeroRecordPM5s)
                    
                    if currentPlan.hasTeamFeature {
                        Divider().background(Theme.textSecondary.opacity(0.3))
                        NavigationLink(destination: TeamMaxManagerView()) {
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
            }
            
            // Manager Plan 共有申請（Team/MAX未加入ユーザー向け）
            if !currentPlan.hasManagerMode {
                SettingsSection(title: "Manager Plan共有".localized, icon: "person.badge.key.fill") {
                    Button(action: { showingInviteCodeInput = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("招待コードで申請".localized)
                                    .foregroundColor(Theme.textMain)
                                Text("Team/MAXユーザーのコードを入力してManagerプランを利用".localized)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // ─── チーム機能セクション ───
            if currentPlan.hasTeamFeature {
                // チーム管理（Team/MAX以上：顧問・管理者向け）
                SettingsSection(title: "チーム管理".localized, icon: "person.3.fill") {
                    NavigationLink(destination: CloudflareTeamListView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("チームダッシュボード")
                                    .foregroundColor(Theme.textMain)
                                Text("Cloudflare D1 チーム管理")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // チームに参加（選手向け）
            if !currentPlan.hasTeamFeature {
                SettingsSection(title: "チームに参加".localized, icon: "person.badge.plus") {
                    // CloudKitTeamManager依存を削除（Cloudflare移行中）
                    // チーム参加機能は現在無効化中
                    Button(action: { showingTeamCodeInput = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("チームに参加")
                                    .foregroundColor(Theme.textMain)
                                Text("顧問から招待コードをもらって参加")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
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
                Text("Test Flight v1.0(Build 7)")
                Text("Build from June 17")
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
