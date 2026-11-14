import Foundation
import SwiftUI

/// 開発者モードを管理するシングルトン
/// バージョン表示を5回タップするたびに ON/OFF をトグルする（永続しない: アプリ再起動でリセット）
@MainActor
class DeveloperModeManager: ObservableObject {
    static let shared = DeveloperModeManager()

    /// 開発者モードの現在状態（セッション中のみ有効・永続しない）
    @Published var isEnabled: Bool = false

    /// マネージャーモードの最大接続台数（開発者モード有効時に変更可能 / UserDefaultsで永続）
    @AppStorage("devMaxPM5Connections") var maxPM5Connections: Int = 10 {
        willSet { objectWillChange.send() }
    }

    /// バージョン表示のタップカウント（現在のカウント数を外部から参照するのみ）
    private(set) var tapCount: Int = 0

    /// タップ間隔タイムアウト（秒）：この間隔内にタップしないとリセット
    private let tapResetInterval: TimeInterval = 3.0
    private var tapResetTimer: Timer?

    private init() {}

    /// バージョン行がタップされた時に呼ぶ
    /// - Returns: 開発者モードの状態変化イベント
    @discardableResult
    func handleVersionTap() -> DeveloperModeEvent {
        tapResetTimer?.invalidate()

        tapCount += 1

        // 5回タップでトグル
        if tapCount >= 5 {
            tapCount = 0
            let newState = !isEnabled
            isEnabled = newState
            // 開発者モードを無効にしたらデフォルト(10)に戻す
            if !newState {
                maxPM5Connections = 10
            }
            return newState ? .enabled : .disabled
        }

        let remaining = 5 - tapCount
        tapResetTimer = Timer.scheduledTimer(withTimeInterval: tapResetInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.tapCount = 0
            }
        }

        return .countdown(remaining: remaining)
    }

    func disable() {
        tapResetTimer?.invalidate()
        tapResetTimer = nil
        tapCount = 0
        isEnabled = false
        maxPM5Connections = 10
    }

    enum DeveloperModeEvent {
        case enabled
        case disabled
        case countdown(remaining: Int)
    }
}
