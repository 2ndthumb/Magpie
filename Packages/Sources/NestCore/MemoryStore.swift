import Foundation
import SQLite

public final class MemoryStore {
    public static let shared = MemoryStore()
    private var db: Connection!
    private let memoryItems = Table("memory_items")

    private let id = Expression<String>("id")
    private let ts = Expression<Double>("ts")
    private let type = Expression<String>("type")
    private let payload = Expression<Data>("payload")
    private let embedding = Expression<Data?>("embedding")
    private let tags = Expression<String?>("tags")
    private let flags = Expression<Int>("flags")

    private init() {
        let fm = FileManager.default
        let folder = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Nest", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("nest.db").path
        db = try? Connection(path)
        if let sql = initialMigrationSQL as String? {
            try? db.run(sql)
        }
    }

    public func write(_ item: MemoryItem) throws {
        let insert = memoryItems.insert(or: .replace,
            id <- item.id.uuidString,
            ts <- item.ts.timeIntervalSince1970,
            type <- item.type.rawValue,
            payload <- item.payload,
            embedding <- item.embedding.withUnsafeBufferPointer { Data(buffer: $0) },
            tags <- (try? JSONEncoder().encode(item.tags)).flatMap { String(data: $0, encoding: .utf8) },
            flags <- Int(item.flags)
        )
        try db.run(insert)
    }

    public func search(text: String, limit: Int = 50) throws -> [MemoryItem] {
        guard !text.isEmpty else { return [] }
        let sql = "SELECT memory_items.* FROM memory_fts JOIN memory_items ON memory_fts.rowid = memory_items.rowid WHERE memory_fts MATCH ? LIMIT ?"
        let stmt = try db.prepare(sql, text, limit)
        return try stmt.map { row in try rowToItem(row) }
    }

    public func retrieveForPrompt(budget: Int) -> String {
        let query = memoryItems.order(ts.desc).limit(budget)
        let items = (try? db.prepare(query).compactMap { try rowToItem($0) }) ?? []
        return items.map { String(data: $0.payload, encoding: .utf8) ?? "" }.joined(separator: "\n")
    }

    private func rowToItem(_ row: Row) throws -> MemoryItem {
        let idVal = UUID(uuidString: row[id]) ?? UUID()
        let tagsValue: [String] = {
            if let str = row[tags], let data = str.data(using: .utf8) {
                return (try? JSONDecoder().decode([String].self, from: data)) ?? []
            }
            return []
        }()
        let embedData = row[embedding] ?? Data()
        let floatArray: [Float] = embedData.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
        return MemoryItem(id: idVal, ts: Date(timeIntervalSince1970: row[ts]), type: MemoryItem.PayloadType(rawValue: row[type]) ?? .text, payload: row[payload], embedding: floatArray, tags: tagsValue, flags: UInt8(row[flags]))
    }
}
