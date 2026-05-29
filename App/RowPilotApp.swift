import SwiftUI

@main
struct RowPilotApp: App {
    @StateObject private var app = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    // Import state
    @State private var showImportConfirmation = false
    @State private var pendingImportData: SharedWorkoutData?
    @State private var importBannerMessage: String?
    @State private var showImportBanner = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // メインビュー: 常にPortraitRootViewを表示
                // RowModeタブ内でGeometryReaderにより縦横切り替え
                PortraitRootView()
                
                // オーバーレイ：スプラッシュ画面
                if app.isSplashVisible {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1) // 最前面に表示
                }
                
                // インポート完了バナー
                if showImportBanner, let message = importBannerMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: message.contains("済み") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(message.contains("済み") ? .orange : .green)
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .environmentObject(app)
            .environmentObject(app.ergManager)
            .environmentObject(app.pm5Manager)
            .animation(.default, value: app.isSplashVisible)
            // アプリ全体のテーマ設定を適用
            .preferredColorScheme(getPreferredColorScheme())
            .onChange(of: scenePhase) { _, newPhase in
                app.handleScenePhaseChange(newPhase)
            }
            .onOpenURL { url in
                handleIncomingFile(url: url)
            }
            .alert("ワークアウトのインポート", isPresented: $showImportConfirmation) {
                Button("インポート") {
                    if let data = pendingImportData {
                        performImport(data)
                    }
                    pendingImportData = nil
                }
                Button("キャンセル", role: .cancel) {
                    pendingImportData = nil
                }
            } message: {
                if let data = pendingImportData {
                    let dateStr = data.record.formattedDate
                    let distStr = data.record.formattedDistance
                    Text("受信したワークアウトデータをインポートしますか？\n日付: \(dateStr)\n距離: \(distStr)")
                } else {
                    Text("受信したワークアウトデータをインポートしますか？")
                }
            }
        }
    }
    
    // MARK: - File Import Handling
    
    private func handleIncomingFile(url: URL) {
        let settings = SettingsManager.shared.settings
        
        // 受信拒否設定の場合は何もしない
        guard settings.importBehavior != .reject else { return }
        
        guard let sharedData = WorkoutShareManager.shared.importRecord(from: url) else {
            showBanner("インポートに失敗しました")
            return
        }
        
        switch settings.importBehavior {
        case .autoImport:
            performImport(sharedData)
        case .askEachTime:
            pendingImportData = sharedData
            showImportConfirmation = true
        case .reject:
            break // 到達しないがswitch網羅のため
        }
    }
    
    private func performImport(_ data: SharedWorkoutData) {
        let result = WorkoutShareManager.shared.importToRecordManager(data, recordManager: app.recordManager)
        
        switch result {
        case .success:
            showBanner("ワークアウトをインポートしました")
        case .duplicate:
            showBanner("この記録は既にインポート済みです")
        case .failed:
            showBanner("インポートに失敗しました")
        }
    }
    
    private func showBanner(_ message: String) {
        importBannerMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showImportBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showImportBanner = false
            }
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        let settings = UserSettings.load()
        switch settings.preferredColorScheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
