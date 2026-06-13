import Foundation
import Combine

// MARK: - ICloudSyncManager
/// iCloud Drive (Ubiquity Container) に .rowpilot ファイルを保存・削除・読み込みする専任クラス
class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager()

    /// iCloud同期の状態
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var syncError: String? = nil

    /// iCloud利用可否
    @Published var isAvailable: Bool = true

    // iCloud Container に対応するURL（バックグラウンドで解決済みのものをキャッシュ）
    private var cachedContainerURL: URL? = nil

    private let fileExtension = "rowpilot"

    private init() {
        self.isAvailable = true
        // url(forUbiquityContainerIdentifier:) はブロッキング呼び出しのためバックグラウンドで実行
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents", isDirectory: true)
            DispatchQueue.main.async {
                self?.cachedContainerURL = url
            }
        }
    }

    // MARK: - Container URL

    private var iCloudContainerURL: URL? {
        cachedContainerURL
    }

    // MARK: - Upload (Add / Update)

    /// 記録をiCloud Driveにアップロード（既に存在する場合は上書き）
    func upload(record: RowingRecord) {
        guard UserSettings.load().iCloudSyncEnabled else { return }
        guard let containerURL = iCloudContainerURL else {
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            do {
                try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            } catch {
                DispatchQueue.main.async { self.syncError = "iCloudディレクトリ作成失敗: \(error.localizedDescription)" }
                return
            }

            let fileURL = containerURL.appendingPathComponent("\(record.id.uuidString).\(self.fileExtension)")
            let sharedData = SharedWorkoutData(record: record)

            guard let jsonData = try? JSONEncoder().encode(sharedData) else {
                DispatchQueue.main.async { self.syncError = "エンコード失敗" }
                return
            }

            do {
                try jsonData.write(to: fileURL, options: .atomic)
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                    self.syncError = nil
                    print("ICloudSyncManager: Uploaded \(record.id)")
                }
            } catch {
                DispatchQueue.main.async { self.syncError = "アップロード失敗: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Delete Single Record

    /// 指定された記録をiCloud Driveから削除
    func delete(recordId: UUID) {
        guard let containerURL = iCloudContainerURL else { return }

        DispatchQueue.global(qos: .background).async {
            let fileURL = containerURL.appendingPathComponent("\(recordId.uuidString).rowpilot")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("ICloudSyncManager: Deleted \(recordId)")
            } catch {
                print("ICloudSyncManager: Failed to delete \(recordId): \(error)")
            }
        }
    }

    // MARK: - Delete All RowPilot Data from iCloud

    /// iCloud Drive上のRowPilot関連ファイルをすべて削除
    func deleteAllFromICloud(completion: @escaping (Bool) -> Void) {
        guard let containerURL = iCloudContainerURL else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: nil
                ).filter { $0.pathExtension == "rowpilot" }

                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
                print("ICloudSyncManager: Deleted \(files.count) files from iCloud")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("ICloudSyncManager: Failed to delete all: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - Import from iCloud

    /// iCloud Drive上の.rowpilotファイルをすべて読み込み、RecordManagerへインポートする
    func importAll(into recordManager: RecordManager, completion: @escaping (Int) -> Void) {
        guard let containerURL = iCloudContainerURL else {
            completion(0)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // まずiCloudのメタデータをダウンロードさせる
            let coordinator = NSFileCoordinator()
            var importedCount = 0

            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: [.ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingStatusKey],
                    options: .skipsHiddenFiles
                ).filter { $0.pathExtension == "rowpilot" }

                for fileURL in files {
                    // ダウンロードが必要なファイルはダウンロードをトリガー
                    let status = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    let downloadStatus = status?.ubiquitousItemDownloadingStatus
                    if downloadStatus != .current {
                        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                        continue // ダウンロード中は次回起動時に読み込み
                    }

                    var error: NSError?
                    coordinator.coordinate(readingItemAt: fileURL, options: [], error: &error) { url in
                        guard let data = try? Data(contentsOf: url),
                              let sharedData = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) else {
                            return
                        }

                        DispatchQueue.main.sync {
                            let result = WorkoutShareManager.shared.importToRecordManager(sharedData, recordManager: recordManager)
                            if result == .success {
                                importedCount += 1
                            }
                        }
                    }
                }
            } catch {
                print("ICloudSyncManager: importAll error: \(error)")
            }

            DispatchQueue.main.async {
                completion(importedCount)
            }
        }
    }

    // MARK: - Sync All Local Records

    /// ローカルの全記録をiCloudへアップロード（一括同期）
    func syncAll(records: [RowingRecord]) {
        guard UserSettings.load().iCloudSyncEnabled else { return }
        DispatchQueue.main.async { self.isSyncing = true }

        DispatchQueue.global(qos: .background).async { [weak self] in
            for record in records {
                self?.uploadSync(record: record)
            }
            DispatchQueue.main.async {
                self?.isSyncing = false
                self?.lastSyncDate = Date()
                print("ICloudSyncManager: Synced \(records.count) records")
            }
        }
    }

    // MARK: - Private

    /// 同期版アップロード（バックグラウンドスレッドから呼ぶ用）
    private func uploadSync(record: RowingRecord) {
        guard let containerURL = iCloudContainerURL else { return }

        let fileURL = containerURL.appendingPathComponent("\(record.id.uuidString).\(fileExtension)")
        let sharedData = SharedWorkoutData(record: record)
        guard let jsonData = try? JSONEncoder().encode(sharedData) else { return }

        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try? jsonData.write(to: fileURL, options: .atomic)
    }
}
