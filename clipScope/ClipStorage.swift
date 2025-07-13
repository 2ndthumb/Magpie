import Foundation
import CryptoKit
import SwiftUI
import Combine
#if NEST_CORE
import NestCore
#endif

class ClipStorage: ObservableObject {
    static let shared = ClipStorage()
    
    @Published var items: [ClipItem] = []
    
    var expireInterval: TimeInterval = 60 * 60 * 24 { // Default to 1 day
        didSet {
            UserDefaults.standard.set(expireInterval, forKey: "expireInterval")
        }
    }
    
    private init() {
        loadItems()
        expireInterval = UserDefaults.standard.double(forKey: "expireInterval")
        if expireInterval == 0 {
            expireInterval = 60 * 60 * 24 // Default if not set
        }
    }
    
    func save(type: String, data: Data, applicationName: String, windowName: String) {
        let base64String = data.base64EncodedString()
        let newItem = ClipItem(id: UUID(), type: type, base64Data: base64String, timestamp: Date(), applicationName: applicationName, windowName: windowName)

#if NEST_CORE
        let pType: MemoryItem.PayloadType
        if type.contains("text") {
            pType = .text
        } else if type.contains("image") {
            pType = .image
        } else if type.contains("url") {
            pType = .url
        } else {
            pType = .data
        }
        let mItem = MemoryItem(id: newItem.id, ts: newItem.timestamp, type: pType, payload: data, embedding: [], tags: [], flags: 0)
        try? MemoryStore.shared.write(mItem)
#endif
        
        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
            self.saveItems()
        }
    }
    
    func delete(item: ClipItem) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
            self.saveItems()
        }
    }
    
    func deleteExpiredItems() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-expireInterval)
        
        DispatchQueue.main.async {
            self.items.removeAll { $0.timestamp < cutoff }
            self.saveItems()
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: "clipboardItems") {
            do {
                let decodedItems = try JSONDecoder().decode([ClipItem].self, from: data)
                self.items = decodedItems.sorted(by: { $0.timestamp > $1.timestamp })
            } catch {
                print("Failed to load clipboard items: \(error)")
            }
        }
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: "clipboardItems")
        } catch {
            print("Failed to save clipboard items: \(error)")
        }
    }
}
