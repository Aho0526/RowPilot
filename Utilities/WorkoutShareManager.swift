import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Workout Data (Transfer Format)

/// AirDrop/共有で送受信するワークアウトデータの包括構造体
struct SharedWorkoutData: Codable {
    let version: Int
    let record: RowingRecord
    let dataPoints: [WorkoutDataPoint]?
    let crewInfo: CrewInfo?
    let routePoints: [LocationData]?
    
    init(record: RowingRecord) {
        self.version = 1
        self.record = record
        self.dataPoints = record.dataPoints
        self.crewInfo = record.crewInfo
        self.routePoints = record.routePoints
    }
}

// MARK: - Custom UTI

extension UTType {
    static var rowpilotWorkout: UTType {
        UTType(exportedAs: "com.rowpilot.workout")
    }
}

// MARK: - WorkoutShareManager

/// ワークアウトデータの共有・インポートを管理
class WorkoutShareManager {
    static let shared = WorkoutShareManager()
    
    private let fileExtension = "rowpilot"
    
    // MARK: - File Load Helpers for Export
    
    private func loadDataPointsFromFile(for id: UUID) -> [WorkoutDataPoint]? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("DataPoints/\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([WorkoutDataPoint].self, from: data)
    }
    
    private func loadCrewInfoFromFile(for id: UUID) -> CrewInfo? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("CrewInfo/\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CrewInfo.self, from: data)
    }
    
    private func loadRoutePointsFromFile(for id: UUID) -> [LocationData]? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("RoutePoints/\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LocationData].self, from: data)
    }
    
    // MARK: - Export
    
    /// RowingRecordをJSONファイルとしてtempディレクトリに書き出す
    func exportRecord(_ record: RowingRecord) -> URL? {
        var recordToShare = record
        
        // メモリ上に欠落しているデータをファイルから補完する（1:1共有でグラフデータ等を確実に含めるため）
        if recordToShare.dataPoints == nil || recordToShare.dataPoints?.isEmpty == true {
            if let loadedPoints = loadDataPointsFromFile(for: record.id) {
                recordToShare.dataPoints = loadedPoints
            }
        }
        if recordToShare.crewInfo == nil {
            if let loadedCrew = loadCrewInfoFromFile(for: record.id) {
                recordToShare.crewInfo = loadedCrew
            }
        }
        if recordToShare.routePoints == nil || recordToShare.routePoints?.isEmpty == true {
            if let loadedRoute = loadRoutePointsFromFile(for: record.id) {
                recordToShare.routePoints = loadedRoute
            }
        }
        
        let sharedData = SharedWorkoutData(record: recordToShare)
        
        guard let jsonData = try? JSONEncoder().encode(sharedData) else {
            print("WorkoutShareManager: Failed to encode record")
            return nil
        }
        
        let fileName = "RowPilot_\(formatDateForFileName(record.date))_\(record.id.uuidString.prefix(8)).\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("WorkoutShareManager: Failed to write file: \(error)")
            return nil
        }
    }
    
    /// マネージャーモード用のレコードを共有用に加工（メモに「Recorded by Manager Mode」を追加）
    func prepareManagerRecord(_ record: RowingRecord) -> RowingRecord {
        var modified = record
        let managerNote = "📋 Recorded by Manager Mode"
        if let existingNotes = modified.notes, !existingNotes.isEmpty {
            modified.notes = "\(existingNotes)\n\(managerNote)"
        } else {
            modified.notes = managerNote
        }
        return modified
    }
    
    // MARK: - Import
    
    /// .rowpilotファイルからRowingRecordを復元
    func importRecord(from url: URL) -> SharedWorkoutData? {
        // セキュリティスコープの開始
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("WorkoutShareManager: Failed to read file at \(url)")
            return nil
        }
        
        guard let sharedData = try? JSONDecoder().decode(SharedWorkoutData.self, from: data) else {
            print("WorkoutShareManager: Failed to decode SharedWorkoutData")
            return nil
        }
        
        return sharedData
    }
    
    /// レコードをRecordManagerにインポート（重複チェック付き）
    @discardableResult
    func importToRecordManager(_ sharedData: SharedWorkoutData, recordManager: RecordManager) -> ImportResult {
        // 重複チェック
        if recordManager.records.contains(where: { $0.id == sharedData.record.id }) {
            return .duplicate
        }
        
        // レコードを復元（dataPoints, crewInfo, routePointsを再結合）
        var record = sharedData.record
        record.dataPoints = sharedData.dataPoints
        record.crewInfo = sharedData.crewInfo
        record.routePoints = sharedData.routePoints
        
        // マネージャーモードで記録されたものを受信した場合は、1:1の個人記録として扱うよう変換
        if record.isManagerMode {
            record.isManagerMode = false
            record.managerSessionId = nil
            
            let noteLabel = "Recorded by Manager Mode"
            if let existingNotes = record.notes, !existingNotes.isEmpty {
                if !existingNotes.contains(noteLabel) {
                    record.notes = "\(existingNotes)\n📋 \(noteLabel)"
                }
            } else {
                record.notes = "📋 \(noteLabel)"
            }
        }
        
        recordManager.addRecord(record)
        return .success
    }
    
    // MARK: - Share Sheet
    
    /// UIActivityViewControllerを表示
    func presentShareSheet(for record: RowingRecord, from sourceView: UIView? = nil) {
        guard let fileURL = exportRecord(record) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // iPad対応: sourceViewが必要
        if let sourceView = sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }
        
        // クリーンアップ
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // 既に表示中のVCがあればそちらから表示
                let presenter = rootVC.presentedViewController ?? rootVC
                presenter.present(activityVC, animated: true)
            }
        }
    }
    
    /// RowingRecordをCSVファイルとしてtempディレクトリに書き出して共有
    func presentCSVShareSheet(for record: RowingRecord, from sourceView: UIView? = nil) {
        guard let fileURL = exportRecordToCSV(record) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // iPad対応
        if let sourceView = sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }
        
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                let presenter = rootVC.presentedViewController ?? rootVC
                presenter.present(activityVC, animated: true)
            }
        }
    }
    
    /// RowingRecordをCSV形式で保存し、その一時ファイルのURLを返す
    func exportRecordToCSV(_ record: RowingRecord) -> URL? {
        let recordToShare = record
        var csvString = ""
        
        // メタデータ部
        csvString += "RowPilot Workout Record Summary\n"
        csvString += "Date,Duration (seconds),Distance (meters),Avg SPM,Avg Pace (seconds/500m),Avg Pace (formatted),Avg Speed (km/h),Avg Watt,Device,Notes\n"
        
        let dateStr = formatDateForFileName(recordToShare.date)
        let durationVal = recordToShare.duration
        let distanceVal = recordToShare.distance
        let avgSPM = recordToShare.averageSPM
        let avgPaceSec = recordToShare.averagePace
        let avgPaceFormatted = recordToShare.formattedPace
        let avgSpeed = recordToShare.averageSpeed
        let avgWatt = recordToShare.averageWatt ?? 0
        let device = recordToShare.pm5CustomName ?? recordToShare.pm5SerialNumber ?? "N/A"
        
        // notesの改行とダブルクォーテーションをエスケープ
        let notesClean = (recordToShare.notes ?? "")
            .replacingOccurrences(of: "\"", with: "\"\"")
        let notesVal = "\"\(notesClean)\""
        
        csvString += "\(dateStr),\(durationVal),\(distanceVal),\(avgSPM),\(avgPaceSec),\(avgPaceFormatted),\(avgSpeed),\(avgWatt),\(device),\(notesVal)\n"
        
        // Excelで文字化けしないようにBOM付き of UTF-8にする
        let bom = "\u{FEFF}"
        let finalCSVString = bom + csvString
        
        let fileName = "RowPilot_\(formatDateForFileName(record.date))_\(record.id.uuidString.prefix(8)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try finalCSVString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("WorkoutShareManager: Failed to write CSV file: \(error)")
            return nil
        }
    }
    
    private func formatPace(_ pace: TimeInterval) -> String {
        let totalSeconds = Int(pace)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Manager Mode Sequential Share Flow
    
    /// 最前面に表示されているUIViewControllerを再帰的に取得
    private func getTopViewController(from viewController: UIViewController? = nil) -> UIViewController? {
        let base = viewController ?? UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?.rootViewController
        
        if let nav = base as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getTopViewController(from: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return getTopViewController(from: presented)
        }
        return base
    }
    
    /// マネージャーモードの順次共有フロー
    /// 各レコードに対して確認ダイアログ → AirDrop共有シートを表示
    func startManagerShareFlow(records: [RowingRecord], completion: @escaping () -> Void) {
        guard !records.isEmpty else {
            completion()
            return
        }
        
        var remainingRecords = records
        // SwiftUIのアラート閉じるアニメーションなどを考慮して、わずかにディレイを置いてから開始する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.shareNextManagerRecord(&remainingRecords, completion: completion)
        }
    }
    
    private func shareNextManagerRecord(_ records: inout [RowingRecord], completion: @escaping () -> Void) {
        guard let record = records.first else {
            completion()
            return
        }
        
        let remaining = Array(records.dropFirst())
        let displayName = record.pm5CustomName ?? record.pm5SerialNumber ?? "PM5"
        let preparedRecord = prepareManagerRecord(record)
        
        guard let fileURL = exportRecord(preparedRecord) else {
            // エクスポート失敗時は次へ
            var mutableRemaining = remaining
            shareNextManagerRecord(&mutableRemaining, completion: completion)
            return
        }
        
        DispatchQueue.main.async {
            guard let presenter = self.getTopViewController() else {
                print("WorkoutShareManager: Failed to get top view controller")
                try? FileManager.default.removeItem(at: fileURL)
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "Share Confirmation".localized,
                message: String(format: "Share to \"%@\"?".localized, displayName),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Share".localized, style: .default) { _ in
                let activityVC = UIActivityViewController(
                    activityItems: [fileURL],
                    applicationActivities: nil
                )
                
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: fileURL)
                    // アニメーション完了後に次のレコードへ進むためディレイ
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        var mutableRemaining = remaining
                        self.shareNextManagerRecord(&mutableRemaining, completion: completion)
                    }
                }
                
                // iPad対応
                activityVC.popoverPresentationController?.sourceView = presenter.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0, height: 0
                )
                
                presenter.present(activityVC, animated: true)
            })
            
            alert.addAction(UIAlertAction(title: "Skip".localized, style: .cancel) { _ in
                try? FileManager.default.removeItem(at: fileURL)
                // アニメーション完了後に次のレコードへ進むためディレイ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    var mutableRemaining = remaining
                    self.shareNextManagerRecord(&mutableRemaining, completion: completion)
                }
            })
            
            presenter.present(alert, animated: true)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDateForFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
    }
    
    enum ImportResult {
        case success
        case duplicate
        case failed
    }
}
