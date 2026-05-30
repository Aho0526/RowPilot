import Foundation
import Combine

class RiggingManager: ObservableObject {
    static let shared = RiggingManager()
    
    @Published var configs: [RiggingConfig] = []
    @Published var activeConfigId: UUID?
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("rigging_configs.json")
    }
    
    private var activeIdURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("active_rigging_id.json")
    }
    
    var activeConfig: RiggingConfig? {
        if let id = activeConfigId {
            return configs.first(where: { $0.id == id })
        }
        return configs.first
    }
    
    init() {
        loadConfigs()
        loadActiveId()
        
        // If empty, seed a default config
        if configs.isEmpty {
            let defaultSingle = RiggingConfig(
                name: "Single Scull Default".localized,
                boatType: .singleSculls,
                oarType: .scull,
                oarTotalLength: 289.0,
                oarInboard: 88.0,
                oarBladeType: "Smoothie2",
                boatSpan: 160.0,
                boatWorkHeight: 16.0,
                boatPitch: 4.0,
                boatFootstretch: 8.0
            )
            configs.append(defaultSingle)
            activeConfigId = defaultSingle.id
            saveConfigs()
            saveActiveId()
        }
    }
    
    func loadConfigs() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            configs = try decoder.decode([RiggingConfig].self, from: data)
        } catch {
            print("Failed to load rigging configs: \(error.localizedDescription)")
            configs = []
        }
    }
    
    func saveConfigs() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configs)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save rigging configs: \(error.localizedDescription)")
        }
    }
    
    func loadActiveId() {
        do {
            let data = try Data(contentsOf: activeIdURL)
            let decoder = JSONDecoder()
            activeConfigId = try decoder.decode(UUID.self, from: data)
        } catch {
            activeConfigId = configs.first?.id
        }
    }
    
    func saveActiveId() {
        guard let id = activeConfigId else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(id)
            try data.write(to: activeIdURL)
        } catch {
            print("Failed to save active rigging id: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Actions
    
    func addConfig(_ config: RiggingConfig) {
        configs.append(config)
        saveConfigs()
    }
    
    func updateConfig(_ config: RiggingConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
            // Force redraw of activeConfig if it was updated
            if activeConfigId == config.id {
                objectWillChange.send()
            }
        }
    }
    
    func deleteConfig(id: UUID) {
        configs.removeAll(where: { $0.id == id })
        saveConfigs()
        
        if activeConfigId == id {
            activeConfigId = configs.first?.id
            saveActiveId()
        }
    }
    
    func selectActiveConfig(id: UUID) {
        if configs.contains(where: { $0.id == id }) {
            activeConfigId = id
            saveActiveId()
            objectWillChange.send()
        }
    }
}
