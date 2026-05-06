import CoreData
import SwiftUI

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer // Regular container, NOT CloudKit
    
    @Published var isStoreLoaded = false

    init(inMemory: Bool = false) {
        // Use regular NSPersistentContainer (no CloudKit)
        container = NSPersistentContainer(name: "RowPilot")
        
        guard let description = container.persistentStoreDescriptions.first else {
            return
        }
        
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable automatic migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        loadStores()
    }
    
    private func loadStores() {
        self.isStoreLoaded = false
        container.loadPersistentStores(completionHandler: { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                print("PersistenceController Error: Store loading failed: \(error), \(error.userInfo)")
            } else {
                DispatchQueue.main.async {
                    self?.isStoreLoaded = true
                    NotificationCenter.default.post(name: .nPersistentStoreChanged, object: nil)
                }
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

extension Notification.Name {
    static let nPersistentStoreChanged = Notification.Name("nPersistentStoreChanged")
}
