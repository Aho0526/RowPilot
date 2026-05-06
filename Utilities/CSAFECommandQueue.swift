import Foundation
import CoreBluetooth

/// BLE CSAFE コマンドのシリアライズキュー
/// 複数PM5デバイスへの送信を1台ずつ順次実行し、フレーム破壊を防止する
///
/// ## 使い方
/// 1. コマンドを `Command` として構築
/// 2. `enqueueSequential()` で全デバイスへの送信を登録
/// 3. キューが自動的に1台ずつ順次送信し、完了後にコールバックを呼ぶ
///
/// ## 設計原則
/// - BLE write は常に1台の peripheral に対してのみ実行
/// - 次のデバイスへの送信は、前のデバイスの書き込み完了後に開始
/// - writeWithoutResponse のため、最小限の固定遅延で完了を推定
class CSAFECommandQueue {
    
    // MARK: - Types
    
    struct Command {
        let peripheral: CBPeripheral
        let characteristic: CBCharacteristic
        let frame: Data          // 完全な CSAFE フレーム (F1...F2)
        let label: String        // デバッグ用ラベル
    }
    
    // MARK: - Properties
    
    private var queue: [Command] = []
    private var isProcessing = false
    private var batchCompletion: (() -> Void)?
    
    /// 各write間の最小遅延（BLEラジオの競合を防止）
    /// PM5は writeWithoutResponse のため、実際の完了通知は来ない
    /// この値は BLE コントローラがフレームを処理するのに十分な時間
    private let interWriteDelay: TimeInterval = 0.03  // 30ms
    
    // MARK: - Public API
    
    /// コマンド配列を順次送信キューに追加し、全完了後にコールバックを呼ぶ
    ///
    /// - Parameters:
    ///   - commands: 送信するコマンドの配列（順序が保証される）
    ///   - completion: 全コマンド送信完了後に呼ばれるコールバック（メインスレッド）
    func enqueueSequential(_ commands: [Command], completion: (() -> Void)? = nil) {
        guard !commands.isEmpty else {
            completion?()
            return
        }
        
        queue.append(contentsOf: commands)
        
        // 既にキューが動いている場合は、末尾に追加されたコマンドも処理される
        // 新しい completion は最後のバッチの完了時に呼ばれる
        if let comp = completion {
            // 前の completion をチェーンする
            let previousCompletion = batchCompletion
            batchCompletion = {
                previousCompletion?()
                comp()
            }
        }
        
        if !isProcessing {
            batchCompletion = completion
            processNext()
        }
    }
    
    /// キュー内の全コマンドをクリアする（緊急時用）
    func cancelAll() {
        queue.removeAll()
        isProcessing = false
        batchCompletion = nil
        print("CSAFEQueue: ⚠️ All commands cancelled")
    }
    
    /// キューが処理中かどうか
    var isBusy: Bool {
        isProcessing
    }
    
    // MARK: - Internal Processing
    
    private func processNext() {
        guard !queue.isEmpty else {
            isProcessing = false
            let completion = batchCompletion
            batchCompletion = nil
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        
        isProcessing = true
        let cmd = queue.removeFirst()
        
        executeWrite(cmd) { [weak self] in
            // 書き込み完了後、最小間隔を空けて次を処理
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.interWriteDelay ?? 0.03)) {
                self?.processNext()
            }
        }
    }
    
    private func executeWrite(_ cmd: Command, done: @escaping () -> Void) {
        let hex = cmd.frame.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        // ポーリング等の頻繁なログは抑制
        if cmd.label != "POLL_STATUS" {
            print("CSAFEQueue: TX → \(cmd.peripheral.name ?? "?") [\(cmd.label)]: \(hex)")
        }
        
        cmd.peripheral.writeValue(cmd.frame, for: cmd.characteristic, type: .withoutResponse)
        
        // writeWithoutResponse の場合、CBPeripheral からの完了コールバックは来ない
        // BLE コントローラがフレームを処理する時間を確保するため、固定遅延で完了を推定
        // PM5 の CSAFE 処理時間は通常 10-20ms 程度
        DispatchQueue.main.asyncAfter(deadline: .now() + interWriteDelay) {
            done()
        }
    }
}
