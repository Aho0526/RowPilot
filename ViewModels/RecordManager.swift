import Foundation
import SwiftUI
import CoreData
import Combine
/// 記録の絞り込み種別
enum RecordFilter: String, CaseIterable {
    case both = "Both"
    case outdoor = "Outdoor"
    case indoor = "Indoor"
    
    var localized: String {
        switch self {
        case .both: return "両方" // Could use LocalizationManager
        case .outdoor: return "屋外"
        case .indoor: return "屋内"
        }
    }
}

/// 練習記録を管理するViewModel (Core Data + CloudKit Version)
class RecordManager: ObservableObject {
    @Published var records: [RowingRecord] = []
    
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    
    private let legacyRecordsKey = "RowPilotRecords"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - dataPoints JSONファイル管理
    // CoreDataのTransformableでSwift structを保存する際の制限を避けるため、
    // dataPointsはDocuments/DataPoints/配下のJSONファイルで管理する
    private var dataPointsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("DataPoints", isDirectory: true)
    }
    
    private func dataPointsURL(for id: UUID) -> URL {
        dataPointsDirectory.appendingPathComponent("\(id.uuidString).json")
    }
    
    private func saveDataPoints(_ points: [WorkoutDataPoint], for id: UUID) {
        do {
            try FileManager.default.createDirectory(at: dataPointsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(points)
            try data.write(to: dataPointsURL(for: id))
        } catch {
            print("RecordManager: Failed to save dataPoints: \(error)")
        }
    }
    
    private func loadDataPoints(for id: UUID) -> [WorkoutDataPoint]? {
        let url = dataPointsURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([WorkoutDataPoint].self, from: data)
    }
    
    private func deleteDataPoints(for id: UUID) {
        try? FileManager.default.removeItem(at: dataPointsURL(for: id))
    }
    
    // MARK: - crewInfo JSONファイル管理
    // dataPointsと同様にDocuments/CrewInfo/配下のJSONファイルで管理する
    private var crewInfoDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("CrewInfo", isDirectory: true)
    }
    
    private func crewInfoURL(for id: UUID) -> URL {
        crewInfoDirectory.appendingPathComponent("\(id.uuidString).json")
    }
    
    private func saveCrewInfo(_ crewInfo: CrewInfo, for id: UUID) {
        do {
            try FileManager.default.createDirectory(at: crewInfoDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(crewInfo)
            try data.write(to: crewInfoURL(for: id))
        } catch {
            print("RecordManager: Failed to save crewInfo: \(error)")
        }
    }
    
    private func loadCrewInfo(for id: UUID) -> CrewInfo? {
        let url = crewInfoURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CrewInfo.self, from: data)
    }
    
    private func deleteCrewInfo(for id: UUID) {
        try? FileManager.default.removeItem(at: crewInfoURL(for: id))
    }
    
    // MARK: - routePoints JSONファイル管理
    private var routePointsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("RoutePoints", isDirectory: true)
    }
    
    private func routePointsURL(for id: UUID) -> URL {
        routePointsDirectory.appendingPathComponent("\(id.uuidString).json")
    }
    
    private func saveRoutePoints(_ points: [LocationData], for id: UUID) {
        do {
            try FileManager.default.createDirectory(at: routePointsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(points)
            try data.write(to: routePointsURL(for: id))
        } catch {
            print("RecordManager: Failed to save routePoints: \(error)")
        }
    }
    
    private func loadRoutePoints(for id: UUID) -> [LocationData]? {
        let url = routePointsURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LocationData].self, from: data)
    }
    
    private func deleteRoutePoints(for id: UUID) {
        try? FileManager.default.removeItem(at: routePointsURL(for: id))
    }
    
    init() {
        // Listen for store reload (iCloud toggle or initial load)
        NotificationCenter.default.publisher(for: .nPersistentStoreChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleStoreLoaded()
            }
            .store(in: &cancellables)
            
        // Automatically fetch updates when context changes
        NotificationCenter.default.addObserver(self, selector: #selector(contextObjectsDidChange(_:)), name: .NSManagedObjectContextObjectsDidChange, object: nil)
        
        // If already loaded (unlikely in init but safe)
        if PersistenceController.shared.isStoreLoaded {
            handleStoreLoaded()
        }
    }
    
    private func handleStoreLoaded() {
        print("RecordManager: Store is ready. Loading records...")
        performMigrationIfNeeded()
        fetchRecords()
    }
    
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        guard let notificationContext = notification.object as? NSManagedObjectContext,
              notificationContext === context else { return }
              
        DispatchQueue.main.async {
            self.fetchRecords()
        }
    }
    
    // MARK: - Core Data Operations
    
    func fetchRecords() {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "RowingRecordEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            self.records = entities.compactMap { entity -> RowingRecord? in
                guard var record = self.mapEntityToModel(entity) else { return nil }
                // JSONファイルからdataPointsを復元
                record.dataPoints = self.loadDataPoints(for: record.id)
                // JSONファイルからcrewInfoを復元
                record.crewInfo = self.loadCrewInfo(for: record.id)
                // JSONファイルからroutePointsを復元
                record.routePoints = self.loadRoutePoints(for: record.id)
                return record
            }
        } catch {
            print("Failed to fetch records: \(error)")
        }
    }
    
    func addRecord(_ record: RowingRecord) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        // dataPointsはJSONファイルで保存
        if let points = record.dataPoints, !points.isEmpty {
            saveDataPoints(points, for: record.id)
        }
        
        // crewInfoはJSONファイルで保存
        if let crewInfo = record.crewInfo {
            saveCrewInfo(crewInfo, for: record.id)
        }
        
        // routePointsはJSONファイルで保存
        if let routePoints = record.routePoints, !routePoints.isEmpty {
            saveRoutePoints(routePoints, for: record.id)
        }
        
        let entity = NSEntityDescription.insertNewObject(forEntityName: "RowingRecordEntity", into: context)
        mapModelToEntity(record, entity: entity)
        saveContext()
        fetchRecords()
    }
    
    func deleteAllRecords() {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let fileManager = FileManager.default
        
        // 1. 各フォルダ配下の全JSONファイルを削除
        if let files = try? fileManager.contentsOfDirectory(at: dataPointsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        if let files = try? fileManager.contentsOfDirectory(at: crewInfoDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        if let files = try? fileManager.contentsOfDirectory(at: routePointsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // 2. CoreDataからすべてのエンティティを削除
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RowingRecordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            fetchRecords() // メモリ上のリストを空にリセット
            print("RecordManager: All records and JSON files deleted successfully.")
        } catch {
            print("RecordManager: Failed to delete all records: \(error)")
        }
    }
    
    func deleteRecord(_ record: RowingRecord) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        // JSONファイルも削除
        deleteDataPoints(for: record.id)
        deleteCrewInfo(for: record.id)
        deleteRoutePoints(for: record.id)
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "RowingRecordEntity")
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            for object in results {
                context.delete(object)
            }
            saveContext()
        } catch {
            print("Failed to delete record: \(error)")
        }
    }
    
    func updateRecord(_ id: UUID, notes: String?, tags: [String]?, crewInfo: CrewInfo? = nil) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "RowingRecordEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let entity = results.first {
                entity.setValue(notes, forKey: "notes")
                entity.setValue(tags, forKey: "tags")
                saveContext()
                
                // crewInfoはJSONファイルで管理
                if let crewInfo = crewInfo {
                    saveCrewInfo(crewInfo, for: id)
                }
                
                fetchRecords()
            }
        } catch {
            print("Failed to update record: \(error)")
        }
    }
    
    /// crewInfoのみを更新する専用メソッド
    func updateCrewInfo(for id: UUID, crewInfo: CrewInfo?) {
        if let crewInfo = crewInfo {
            saveCrewInfo(crewInfo, for: id)
        } else {
            deleteCrewInfo(for: id)
        }
        fetchRecords()
    }
    
    func clearAllRecords() {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "RowingRecordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            context.reset()
            fetchRecords()
        } catch {
            print("Failed to clear records: \(error)")
        }
    }
    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving Core Data: \(error)")
            }
        }
    }
    
    // MARK: - Mapping
    
    private func mapEntityToModel(_ entity: NSManagedObject) -> RowingRecord? {
        // ... (same as before)
        guard let id = entity.value(forKey: "id") as? UUID,
              let date = entity.value(forKey: "date") as? Date else {
            print("RecordManager: Warning - Skipping invalid record entity (missing ID or Date)")
            return nil
        }
        
        let duration = entity.value(forKey: "duration") as? Double ?? 0
        let distance = entity.value(forKey: "distance") as? Double ?? 0
        let avgSPM = entity.value(forKey: "averageSPM") as? Int ?? 0
        let avgSpeed = entity.value(forKey: "averageSpeed") as? Double ?? 0
        let avgPace = entity.value(forKey: "averagePace") as? Double ?? 0
        let notes = entity.value(forKey: "notes") as? String
        let tags = entity.value(forKey: "tags") as? [String]
        
        var startLoc: LocationData? = nil
        if let sLat = entity.value(forKey: "startLat") as? Double,
           let sLon = entity.value(forKey: "startLon") as? Double, sLat != 0 {
            startLoc = LocationData(latitude: sLat, longitude: sLon)
        }
        
        var endLoc: LocationData? = nil
        if let eLat = entity.value(forKey: "endLat") as? Double,
           let eLon = entity.value(forKey: "endLon") as? Double, eLat != 0 {
            endLoc = LocationData(latitude: eLat, longitude: eLon)
        }
        
        let isManagerMode = entity.value(forKey: "isManagerMode") as? Bool ?? false
        let managerSessionId = entity.value(forKey: "managerSessionId") as? UUID
        let pm5SerialNumber = entity.value(forKey: "pm5SerialNumber") as? String
        let pm5CustomName = entity.value(forKey: "pm5CustomName") as? String
        let averageWatt = entity.value(forKey: "averageWatt") as? Int
        // dataPointsはJSONファイルから取得 (fetchRecordsで別途ロード)
        
        return RowingRecord(
            id: id,
            date: date,
            duration: duration,
            distance: distance,
            averageSPM: avgSPM,
            averageSpeed: avgSpeed,
            averagePace: avgPace,
            startLocation: startLoc,
            endLocation: endLoc,
            notes: notes,
            tags: tags,
            isManagerMode: isManagerMode,
            managerSessionId: managerSessionId,
            pm5SerialNumber: pm5SerialNumber,
            pm5CustomName: pm5CustomName,
            averageWatt: averageWatt,
            dataPoints: nil // fetchRecordsでJSONファイルから注入
        )
    }
    
    private func mapModelToEntity(_ model: RowingRecord, entity: NSManagedObject) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.date, forKey: "date")
        entity.setValue(model.duration, forKey: "duration")
        entity.setValue(model.distance, forKey: "distance")
        entity.setValue(model.averageSPM, forKey: "averageSPM")
        entity.setValue(model.averageSpeed, forKey: "averageSpeed")
        entity.setValue(model.averagePace, forKey: "averagePace")
        entity.setValue(model.notes, forKey: "notes")
        entity.setValue(model.tags, forKey: "tags")
        
        if let start = model.startLocation {
            entity.setValue(start.latitude, forKey: "startLat")
            entity.setValue(start.longitude, forKey: "startLon")
        }
        
        if let end = model.endLocation {
            entity.setValue(end.latitude, forKey: "endLat")
            entity.setValue(end.longitude, forKey: "endLon")
        }
        
        entity.setValue(model.isManagerMode, forKey: "isManagerMode")
        entity.setValue(model.managerSessionId, forKey: "managerSessionId")
        entity.setValue(model.pm5SerialNumber, forKey: "pm5SerialNumber")
        entity.setValue(model.pm5CustomName, forKey: "pm5CustomName")
        if let watt = model.averageWatt {
            entity.setValue(watt, forKey: "averageWatt")
        } else {
            entity.setValue(nil, forKey: "averageWatt")
        }
        // dataPointsはCoreDataに保存しない（JSONファイルで管理）
        // entity.setValue(model.dataPoints, forKey: "dataPoints") -- 削除
    }
    
    // MARK: - Migration
    
    private func performMigrationIfNeeded() {
        if let data = UserDefaults.standard.data(forKey: legacyRecordsKey),
           let legacyRecords = try? JSONDecoder().decode([RowingRecord].self, from: data),
           !legacyRecords.isEmpty {
            
            print("Core Data Migration: Found \(legacyRecords.count) legacy records.")
            for record in legacyRecords {
                if !recordExists(id: record.id) {
                    addRecord(record)
                }
            }
            UserDefaults.standard.removeObject(forKey: legacyRecordsKey)
        }
    }
    
    private func recordExists(id: UUID) -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "RowingRecordEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    // MARK: - Statistics
    
    var totalDistance: Double { records.reduce(0) { $0 + $1.distance } }
    var totalDuration: TimeInterval { records.reduce(0) { $0 + $1.duration } }
    var totalCount: Int { records.count }
    
    var recordsThisMonth: [RowingRecord] {
        let calendar = Calendar.current
        let now = Date()
        return records.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }
    
    var monthlyDistance: Double { recordsThisMonth.reduce(0) { $0 + $1.distance } }
    var monthlyDuration: TimeInterval { recordsThisMonth.reduce(0) { $0 + $1.duration } }
    
    // MARK: - Advanced Filtering
    
    func records(for month: Date, filter: RecordFilter) -> [RowingRecord] {
        let calendar = Calendar.current
        return records.filter { record in
            guard calendar.isDate(record.date, equalTo: month, toGranularity: .month) else {
                return false
            }
            switch filter {
            case .both: return true
            case .outdoor: return isOutdoor(record)
            case .indoor: return !isOutdoor(record)
            }
        }
    }
    
    func allRecords(filter: RecordFilter) -> [RowingRecord] {
        switch filter {
        case .both: return records
        case .outdoor: return records.filter { isOutdoor($0) }
        case .indoor: return records.filter { !isOutdoor($0) }
        }
    }
    
    func stats(for records: [RowingRecord]) -> (distance: Double, duration: TimeInterval, count: Int) {
        let dist = records.reduce(0) { $0 + $1.distance }
        let dur = records.reduce(0) { $0 + $1.duration }
        return (dist, dur, records.count)
    }
    
    func isOutdoor(_ record: RowingRecord) -> Bool {
        // Indoor records typically have tags containing "Indoor" or isManagerMode == true
        if let tags = record.tags, tags.contains("Indoor") {
            return false
        }
        if record.isManagerMode {
            return false
        }
        if record.startLocation != nil {
            return true
        }
        // Default assumption
        return true
    }
}
