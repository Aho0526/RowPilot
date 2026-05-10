import SwiftUI
import MessageUI

/// RowModeタブ専用のコンテナビュー
/// GeometryReaderでwidth > heightを判定し、縦横画面を切り替える
struct RowModeContainerView: View {
    @EnvironmentObject var app: AppViewModel
    
    /// 前回のジオメトリ状態を追跡してロック解除タイミングを検出
    @State private var wasPortrait: Bool = true
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // SOS UI State in Container
    @State private var showingSOSMessage = false
    @State private var currentSOSMessage = ""
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                
                Group {
                    if isLandscape && !app.landscapeLocked {
                        // 横画面かつロックされていない場合
                        LandscapeView()
                            // iPadではタブバーを隠さない（常時表示の要求に対応）
                            .toolbar(isIPad ? .visible : .hidden, for: .tabBar)
                    } else {
                        // 縦画面、またはロック中
                        PortraitView()
                    }
                }
                .onChange(of: isLandscape) { _, newValue in
                    // 横→縦に戻った時にロック解除
                    if !newValue && app.landscapeLocked {
                        app.unlockLandscape()
                    }
                }
            }
            .sheet(isPresented: $showingSOSMessage) {
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipients: [SettingsManager.shared.settings.sosContactPhone], body: currentSOSMessage)
                } else {
                    Text("SMS is not available")
                }
            }
            .onChange(of: app.pendingSOSMessage) { _, newValue in
                if let msg = newValue {
                    currentSOSMessage = msg
                    showingSOSMessage = true
                    app.pendingSOSMessage = nil
                }
            }
            
            // iPad制限オーバーレイ
            if isIPad {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "ipad.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            Text("iPad版ではRowModeを使用できません")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("iPhoneを艇に装着して使用してください")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Text("その他の機能（Practice, Tide等）は\niPadでもご利用いただけます")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Theme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(20)
                }
                .zIndex(10)
            }
        }
    }
}
