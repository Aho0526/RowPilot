import Foundation
import SwiftUI
import CoreData
import Combine

/// 練習記録を管理するViewModel (Core Data + CloudKit Version)
class RecordManager: ObservableObject {
    @Published var records: [RowingRecord] = []
    
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    
    private let legacyRecordsKey = "RowPilotRecords"
    private var cancellables = Set<AnyCancellable>()
    
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
            self.records = entities.compactMap { self.mapEntityToModel($0) }
        } catch {
            print("Failed to fetch records: \(error)")
        }
    }
    
    func addRecord(_ record: RowingRecord) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let entity = NSEntityDescription.insertNewObject(forEntityName: "RowingRecordEntity", into: context)
        mapModelToEntity(record, entity: entity)
        saveContext()
        fetchRecords() // 明示的にフェッチを呼び出してリストを即時更新
    }
    
    func deleteRecord(_ record: RowingRecord) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
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
    
    func updateRecord(_ id: UUID, notes: String?, tags: [String]?) {
        guard PersistenceController.shared.isStoreLoaded else { return }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "RowingRecordEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let entity = results.first {
                entity.setValue(notes, forKey: "notes")
                entity.setValue(tags, forKey: "tags")
                saveContext()
                fetchRecords()
            }
        } catch {
            print("Failed to update record: \(error)")
        }
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
            tags: tags
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
}
