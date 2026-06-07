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
    
    // Low Power Mode monitoring
    @State private var showLowPowerWarning = false
    
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
                            Text("iPad版ではRowModeを使用できません".localized)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("iPhoneを艇に装着して使用してください".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Text("その他の機能（Practice, Tide等）は\niPadでもご利用いただけます".localized)
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
            
            // 省電力モード警告トースト
            if showLowPowerWarning {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "battery.100.bolt")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        Text("Low Power Mode Warning".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .padding(.top, 20)
                .zIndex(5)
            }
        }
        .onAppear {
            AppDelegate.orientationLock = .allButUpsideDown
            updateIdleTimer()
            triggerLowPowerWarningIfNeeded()
        }
        .onDisappear {
            AppDelegate.orientationLock = .portrait
            UIApplication.shared.isIdleTimerDisabled = false // Restore default behavior
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            updateIdleTimer()
            triggerLowPowerWarningIfNeeded()
        }
    }
    
    private func updateIdleTimer() {
        if SettingsManager.shared.settings.preventScreenDimming && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func triggerLowPowerWarningIfNeeded() {
        if SettingsManager.shared.settings.preventScreenDimming && ProcessInfo.processInfo.isLowPowerModeEnabled {
            withAnimation {
                showLowPowerWarning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    showLowPowerWarning = false
                }
            }
        }
    }
}
