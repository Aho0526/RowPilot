import Foundation
import CoreBluetooth

// MARK: - Global BLE Write Limiter
/// CoreBluetooth internal queue collapse 防止のための同時書き込み数制限
/// 多台数接続時に同時 BLE write が集中するのを防ぐ
actor GlobalWriteLimiter {
    private let maxConcurrent: Int
    private var activeCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }
    
    func acquire() async {
        if activeCount < maxConcurrent {
            activeCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func release() {
        if !waiters.isEmpty {
            // スロットを次の waiter に直接譲渡（activeCount は変わらない）
            let next = waiters.removeFirst()
            next.resume()
        } else {
            activeCount -= 1
        }
    }
}

/// BLE CSAFE コマンドのフォールトトレラント・キュー (v4)
/// デバイスごとの直列化（Actor）と、デバイス間の並行処理（TaskGroup）を組み合わせ、
/// 1台の通信失敗が全体のワークアウト送信をブロックしないようにする。
///
/// v4 変更点:
/// - Minimum inter-frame gap: 50ms (Concept2仕様 Table 10 準拠)
/// - Global write limiter: maxConcurrentWrites = 3 (CoreBluetooth queue collapse 防止)
class CSAFECommandQueue {
    
    struct Command {
        let peripheral: CBPeripheral
        let characteristic: CBCharacteristic
        let frame: Data          // 完全な CSAFE フレーム (F0...F2 extended)
        let label: String        // デバッグ用ラベル
    }
    
    enum DeviceState {
        case healthy
        case degraded
    }
    
    private let lock = NSLock()
    private var continuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var deviceStates: [UUID: DeviceState] = [:]
    
    /// タイムアウト値（秒） - 8台接続時などを考慮して余裕を持たせる
    private let timeoutDuration: TimeInterval = 2.0
    
    /// Concept2仕様 Table 10: Minimum Inter-frame Gap = 50 msec
    private let interFrameGapNanoseconds: UInt64 = 50_000_000 // 50ms
    
    /// 同時 BLE write 数制限 (CoreBluetooth internal queue collapse 防止)
    private let writeLimiter = GlobalWriteLimiter(maxConcurrent: 3)
    
    // Per-Device Queue Actor (デバイス固有の直列化を保証)
    actor DeviceQueue {
        let peripheral: CBPeripheral
        private weak var manager: CSAFECommandQueue?
        
        init(peripheral: CBPeripheral, manager: CSAFECommandQueue) {
            self.peripheral = peripheral
            self.manager = manager
        }
        
        func enqueue(command: Command) async {
            guard let manager = manager else { return }
            
            // Degraded状態のデバイスには重いコマンドを送らない（必要に応じて軽量Pingだけ許可する）
            if manager.getHealthState(for: peripheral.identifier) == .degraded {
                if command.label != "POLL_STATUS" {
                    print("CSAFEQueue: ⚠️ Skipping \(peripheral.name ?? "?") [\(command.label)] because state is Degraded.")
                    return
                }
            }
            
            do {
                try await manager.writeAsync(command: command)
                // 成功したらHealthyに復帰
                manager.setHealthState(for: peripheral.identifier, state: .healthy)
            } catch {
                print("CSAFEQueue: ❌ Timeout or Error on \(peripheral.name ?? "?"). Marking as Degraded.")
                manager.setHealthState(for: peripheral.identifier, state: .degraded)
            }
        }
    }
    
    private var deviceQueues: [UUID: DeviceQueue] = [:]
    
    /// デバイスの状態を取得
    func getHealthState(for uuid: UUID) -> DeviceState {
        lock.lock(); defer { lock.unlock() }
        return deviceStates[uuid] ?? .healthy
    }
    
    /// デバイスの状態を更新
    func setHealthState(for uuid: UUID, state: DeviceState) {
        lock.lock(); defer { lock.unlock() }
        deviceStates[uuid] = state
    }
    
    /// デバイス専用のキューを取得（なければ作成）
    private func getQueue(for peripheral: CBPeripheral) -> DeviceQueue {
        lock.lock(); defer { lock.unlock() }
        if let q = deviceQueues[peripheral.identifier] { return q }
        let q = DeviceQueue(peripheral: peripheral, manager: self)
        deviceQueues[peripheral.identifier] = q
        return q
    }
    
    /// 非同期でBLE Writeを実行し、タイムアウトと競合させる
    /// Global write limiter により同時書き込み数を制限
    func writeAsync(command: Command) async throws {
        let peripheralID = command.peripheral.identifier
        
        // Global write limiter: 同時 BLE write 数を制限
        await writeLimiter.acquire()
        defer { Task { await writeLimiter.release() } }
        
        // タイムアウト付きのタスクグループ
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            // Task 1: 実際のBLE Write待機
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    self.lock.lock()
                    self.continuations[peripheralID] = continuation
                    self.lock.unlock()
                    
                    if command.label != "POLL_STATUS" {
                        let hex = command.frame.map { String(format: "%02X", $0) }.joined(separator: " ")
                        print("CSAFEQueue: TX → \(command.peripheral.name ?? "?") [\(command.label)]: \(hex)")
                    }
                    
                    command.peripheral.writeValue(command.frame, for: command.characteristic, type: .withResponse)
                }
            }
            
            // Task 2: タイムアウトの時計
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutDuration * 1_000_000_000))
                throw NSError(domain: "BLETimeoutError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Write operation timed out"])
            }
            
            // どちらか早い方を待つ（タイムアウトが先ならthrowされる）
            try await group.next()
            
            // 残りのタスク（タイムアウト等）をキャンセル
            group.cancelAll()
        }
        
        // Continuationのクリーンアップ（成功時も念のため）
        lock.lock()
        continuations.removeValue(forKey: peripheralID)
        lock.unlock()
        
        // Concept2仕様準拠: Minimum Inter-frame Gap = 50ms
        try? await Task.sleep(nanoseconds: interFrameGapNanoseconds)
    }
    
    /// コマンド配列をキューに追加し、全デバイスに対して【並行】で送信する。
    /// Global write limiter により同時に実行される BLE write は最大3つに制限される。
    func enqueueSequential(_ commands: [Command], perDeviceCompletion: ((CBPeripheral, Bool) -> Void)? = nil, completion: (() -> Void)? = nil) {
        guard !commands.isEmpty else {
            completion?()
            return
        }
        
        Task {
            // 全デバイスの送信完了を待機
            await withTaskGroup(of: Void.self) { group in
                for cmd in commands {
                    let deviceQueue = self.getQueue(for: cmd.peripheral)
                    group.addTask {
                        await deviceQueue.enqueue(command: cmd)
                        // 個別の完了通知（成否判定は getHealthState で行う）
                        let isSuccess = self.getHealthState(for: cmd.peripheral.identifier) == .healthy
                        perDeviceCompletion?(cmd.peripheral, isSuccess)
                    }
                }
            }
            
            // 全てのタスク（送信）が完了したらコールバックを実行
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// CBPeripheralDelegate から呼ばれる
    func handleWriteComplete(for peripheral: CBPeripheral, error: Error?) {
        lock.lock()
        let continuation = continuations.removeValue(forKey: peripheral.identifier)
        lock.unlock()
        
        if let error = error {
            print("CSAFEQueue: ❌ Error writing to \(peripheral.name ?? "?"): \(error.localizedDescription)")
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: ())
        }
    }
    
    /// キュー内の全コマンドをクリアする
    func cancelAll() {
        lock.lock()
        for cont in continuations.values {
            cont.resume(throwing: CancellationError())
        }
        continuations.removeAll()
        lock.unlock()
        print("CSAFEQueue: ⚠️ All pending commands cancelled")
    }
    
    /// 処理中かどうか
    var isBusy: Bool {
        lock.lock(); defer { lock.unlock() }
        return !continuations.isEmpty
    }
}
