import Foundation
import SQLite

public final class MemoryStore: @unchecked Sendable {
    public static let shared = MemoryStore()
    private var db: Connection!
    private let dbQueue = DispatchQueue(label: "NestCore.DB")
    private let memoryItems = Table("memory_items")
    private var ftsAvailable = true
    public var isFTSAvailable: Bool { ftsAvailable }

    private let id = Expression<String>("id")
    private let ts = Expression<Double>("ts")
    private let type = Expression<String>("type")
    private let payload = Expression<Data>("payload")
    private let embedding = Expression<Data?>("embedding")
    private let tags = Expression<String?>("tags")
    private let flags = Expression<Int>("flags")

    private init() {
        let fm = FileManager.default
#if os(iOS)
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.nest") ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
#else
        let base = fm.homeDirectoryForCurrentUser
#endif
        let folder = base.appendingPathComponent("Library/Application Support/Nest", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("nest.db").path
        dbQueue.sync {
            do {
                db = try Connection(path)
                db.busyTimeout = 5.0
                try db.execute("PRAGMA journal_mode=WAL;")
                try db.execute(initialMigrationSQL)
            } catch {
                print("DB init error: \(error)")
                ftsAvailable = false
                let fallback = """
                CREATE TABLE IF NOT EXISTS memory_items(
                    id TEXT PRIMARY KEY,
                    ts REAL NOT NULL,
                    type TEXT NOT NULL,
                    payload BLOB NOT NULL,
                    embedding BLOB,
                    tags TEXT,
                    flags INTEGER DEFAULT 0
                );
                """
                try? db.execute(fallback)
            }
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
        var firstError: Error?
        dbQueue.sync {
            do { try db.run(insert) } catch { firstError = error }
        }
        if let err = firstError { throw err }
    }

    public func search(text: String, limit: Int = 50) throws -> [MemoryItem] {
        guard !text.isEmpty else { return [] }
        var result: Swift.Result<[MemoryItem], Error>!
        dbQueue.sync {
            do {
                if ftsAvailable {
                    let sql = "SELECT memory_items.* FROM memory_fts JOIN memory_items ON memory_fts.rowid = memory_items.rowid WHERE memory_fts MATCH ? LIMIT ?"
                    var items: [MemoryItem] = []
                    let iterator = try db.prepareRowIterator(sql, bindings: [text, limit])
                    while let row = try iterator.failableNext() {
                        items.append(try rowToItem(row))
                    }
                    result = .success(items)
                } else {
                    var items: [MemoryItem] = []
                    for row in try db.prepare(memoryItems) {
                        let item = try rowToItem(row)
                        if let str = String(data: item.payload, encoding: .utf8), str.contains(text) {
                            items.append(item)
                        }
                        if items.count >= limit { break }
                    }
                    result = .success(items)
                }
            } catch {
                result = .failure(error)
            }
        }
        return try result.get()
    }

    public func retrieveForPrompt(budget: Int) -> String {
        var result = ""
        dbQueue.sync {
            var totalTokens = 0
            var pieces: [String] = []
            if let rows = try? db.prepare(memoryItems.order(ts.desc)) {
                for row in rows {
                    guard let item = try? rowToItem(row), let string = String(data: item.payload, encoding: .utf8) else { continue }
                    let tokens = string.count / 4
                    if totalTokens + tokens > budget { break }
                    totalTokens += tokens
                    pieces.append(string)
                }
            }
            result = pieces.joined(separator: "\n")
        }
        return result
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
