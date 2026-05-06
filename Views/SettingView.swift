import SwiftUI

struct SettingView: View {
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
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
                Button("Cancel".localized, role: .cancel) { }
                Button("Reset".localized, role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            } message: {
                Text("Reset Alert Message".localized)
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
            
            // 音声設定
            SettingsSection(title: "Voice Feedback".localized, icon: "speaker.wave.3.fill") {
                SettingsToggleRow(title: "Sound Effects".localized, isOn: $settingsManager.settings.soundEnabled)
                SettingsToggleRow(title: "Voice Guide".localized, isOn: $settingsManager.settings.voiceFeedbackEnabled)
                
                if settingsManager.settings.voiceFeedbackEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interval: \(Int(settingsManager.settings.feedbackInterval))s")
                            .foregroundColor(Theme.textMain)
                            .font(.subheadline)
                        Slider(value: $settingsManager.settings.feedbackInterval, in: 30...300, step: 30)
                            .tint(Theme.accent)
                    }
                    .padding(.top, 4)
                }
            }
            
            // 表示設定
            SettingsSection(title: "Display".localized, icon: "display") {
                SettingsToggleRow(title: "Show Battery".localized, isOn: $settingsManager.settings.showBatteryStatus)
                SettingsToggleRow(title: "Show GPS Accuracy".localized, isOn: $settingsManager.settings.showGPSAccuracy)
            }
            
            // 計測設定
            SettingsSection(title: "Measurement".localized, icon: "stopwatch.fill") {
                SettingsToggleRow(title: "Auto Start".localized, isOn: $settingsManager.settings.autoStartOnMotion)
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
                 // Disabled toggle with Coming Soon style
                 Toggle("iCloud Sync", isOn: .constant(false))
                     .disabled(true)
                     .tint(Theme.accent)
                     .opacity(0.5)
                 
                 Text("Coming Soon".localized)
                     .font(.caption)
                     .foregroundColor(Theme.textSecondary)
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
            
            // アプリ情報
            VStack(spacing: 8) {
                Text("Version 1.0.0")
                NavigationLink(destination: TermsView()) {
                    Text("Terms of Service".localized)
                        .underline()
                }
                NavigationLink(destination: CreditsView()) {
                    Text("Credits".localized)
                        .underline()
                }
            }
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom)
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

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    @Published var settings: UserSettings {
        didSet {
            saveSettings()
        }
    }
    
    init() {
        self.settings = UserSettings.load()
        // Initialize LocalizationManager with saved language on startup
        LocalizationManager.shared.setLanguage(self.settings.language)
    }
    
    private func saveSettings() {
        settings.save()
    }
    
    func resetToDefaults() {
        UserSettings.reset()
        settings = UserSettings()
        LocalizationManager.shared.setLanguage(settings.language)
    }
}

#Preview {
    SettingView()
}
