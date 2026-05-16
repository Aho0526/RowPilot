import SwiftUI

/// 下部タブを管理する親ビュー
struct PortraitRootView: View {
    @EnvironmentObject var app: AppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        TabView(selection: $app.activeTab) {
            // ① Home
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(0)

            // ② Tide (Placeholder)
            TideView()
                .tabItem {
                    Image(systemName: "water.waves")
                    Text("Tide")
                }
                .tag(1)
            
            // ③ RowMode (Container with Geometry-based rotation)
            RowModeContainerView()
                .tabItem {
                    Image(systemName: "figure.outdoor.rowing")
                    Text("RowMode")
                }
                .tag(2)
            
            // ④ Practice (New)
            PracticeView()
                .tabItem {
                    Image(systemName: "figure.rower")
                    Text("Practice")
                }
                .tag(3)

            // ⑤ RowSettings (Existing SettingView)
            SettingView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(Theme.accent)
        .id(themeManager.currentPreset)
        .onChange(of: app.activeTab) { oldTab, newTab in
            if oldTab == 3 {
                app.lastPracticeTabLeaveTime = Date()
            }
            if newTab == 3 {
                if let leaveTime = app.lastPracticeTabLeaveTime, Date().timeIntervalSince(leaveTime) > 300 {
                    app.practiceNavigationPath = NavigationPath()
                }
                app.lastPracticeTabLeaveTime = nil
            }
        }
    }
}
