import SwiftUI

@main
struct RowPilotApp: App {
    @StateObject private var app = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
