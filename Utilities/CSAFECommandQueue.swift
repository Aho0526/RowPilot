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
/// 非同期処理に対応したOperationの基底クラス
class AsyncOperation: Operation {
    enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { "is" + rawValue }
    }
    
    private var state: State = .ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
    
    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool { state == .executing }
    override var isFinished: Bool { state == .finished }
    
    override func start() {
        if isCancelled {
            state = .finished
            return
        }
        state = .executing
        main()
    }
    
    override func main() {
        fatalError("Subclasses must implement `main` without overriding `start`.")
    }
    
    func finish() {
        state = .finished
    }
}

/// BLE書き込み用の非同期Operation
class BLEWriteOperation: AsyncOperation {
    let command: CSAFECommandQueue.Command
    weak var queue: CSAFECommandQueue?
    var semaphore: DispatchSemaphore?
    
    private let interWriteDelay: TimeInterval = 0.03 // 30ms
    
    init(command: CSAFECommandQueue.Command, queue: CSAFECommandQueue) {
        self.command = command
        self.queue = queue
        super.init()
    }
    
    override func main() {
        let hex = command.frame.map { String(format: "%02X", $0) }.joined(separator: " ")
        if command.label != "POLL_STATUS" {
            print("CSAFEQueue: TX → \(command.peripheral.name ?? "?") [\(command.label)]: \(hex)")
        }
        
        semaphore = DispatchSemaphore(value: 0)
        
        queue?.register(operation: self, for: command.peripheral.identifier)
        
        // 実際のACKを待つため .withResponse を使用
        command.peripheral.writeValue(command.frame, for: command.characteristic, type: .withResponse)
        
        let result = semaphore?.wait(timeout: .now() + 2.0)
        
        if result == .timedOut {
            print("CSAFEQueue: ⚠️ Timeout waiting for ACK from \(command.peripheral.name ?? "?")")
            // タイムアウト時のリトライ対象マーク等の処理は必要に応じてViewModel側で対応する
        }
        
        queue?.unregister(for: command.peripheral.identifier)
        
        // フレーム破壊防止のため規定の30ms間隔は維持
        Thread.sleep(forTimeInterval: interWriteDelay)
        
        finish()
    }
}

class CSAFECommandQueue {
    
    struct Command {
        let peripheral: CBPeripheral
        let characteristic: CBCharacteristic
        let frame: Data          // 完全な CSAFE フレーム (F1...F2)
        let label: String        // デバッグ用ラベル
    }
    
    private let operationQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1 // 1台ずつ順次送信する
        q.qualityOfService = .userInitiated
        return q
    }()
    
    private var activeOperations: [UUID: BLEWriteOperation] = [:]
    private let lock = NSLock()
    
    /// コマンド配列を順次送信キューに追加し、全完了後にコールバックを呼ぶ
    func enqueueSequential(_ commands: [Command], completion: (() -> Void)? = nil) {
        guard !commands.isEmpty else {
            completion?()
            return
        }
        
        var ops: [Operation] = []
        for cmd in commands {
            let op = BLEWriteOperation(command: cmd, queue: self)
            ops.append(op)
            operationQueue.addOperation(op)
        }
        
        // 最後のOperationに依存するBlockOperationを追加
        if let completion = completion {
            let blockOp = BlockOperation {
                DispatchQueue.main.async {
                    completion()
                }
            }
            if let last = ops.last {
                blockOp.addDependency(last)
            }
            operationQueue.addOperation(blockOp)
        }
    }
    
    /// キュー内の全コマンドをクリアする（緊急時用）
    func cancelAll() {
        operationQueue.cancelAllOperations()
        print("CSAFEQueue: ⚠️ All commands cancelled")
    }
    
    /// キューが処理中かどうか
    var isBusy: Bool {
        return operationQueue.operationCount > 0
    }
    
    func register(operation: BLEWriteOperation, for uuid: UUID) {
        lock.lock()
        activeOperations[uuid] = operation
        lock.unlock()
    }
    
    func unregister(for uuid: UUID) {
        lock.lock()
        activeOperations.removeValue(forKey: uuid)
        lock.unlock()
    }
    
    /// CBPeripheralDelegate から呼ばれる
    func handleWriteComplete(for peripheral: CBPeripheral, error: Error?) {
        lock.lock()
        let op = activeOperations[peripheral.identifier]
        lock.unlock()
        
        if let error = error {
            print("CSAFEQueue: ❌ Error writing to \(peripheral.name ?? "?"): \(error.localizedDescription)")
        }
        
        op?.semaphore?.signal()
    }
}
