import Foundation
#if canImport(CoreData)
import CoreData
#endif
import NestCore

let storeURL = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Magpie/ClipData.sqlite").expandingTildeInPath)
let container = NSPersistentContainer(name: "ClipData", managedObjectModel: .init())
container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
container.loadPersistentStores { _, error in if let error = error { fatalError("\(error)") } }

let context = container.viewContext
let request = NSFetchRequest<NSManagedObject>(entityName: "ClipboardItem")
if let items = try? context.fetch(request) {
    for obj in items {
        guard
            let id = obj.value(forKey: "id") as? UUID,
            let ts = obj.value(forKey: "timestamp") as? Date,
            let type = obj.value(forKey: "type") as? String,
            let payload = obj.value(forKey: "data") as? Data
        else { continue }
        let pType: MemoryItem.PayloadType = type.contains("text") ? .text : (type.contains("image") ? .image : .data)
        let item = MemoryItem(id: id, ts: ts, type: pType, payload: payload, embedding: [], tags: [], flags: 0)
        try? MemoryStore.shared.write(item)
    }
}
