public struct MemoryItem: Identifiable, Codable {
    public enum PayloadType: String, Codable { case text, image, url, data }
    public let id: UUID
    public let ts: Date
    public let type: PayloadType
    public let payload: Data
    public let embedding: [Float]
    public var tags: [String]
    public var flags: UInt8

    public init(id: UUID = UUID(), ts: Date = Date(), type: PayloadType, payload: Data, embedding: [Float] = [], tags: [String] = [], flags: UInt8 = 0) {
        self.id = id
        self.ts = ts
        self.type = type
        self.payload = payload
        self.embedding = embedding
        self.tags = tags
        self.flags = flags
    }
}

public let initialMigrationSQL = """
CREATE TABLE IF NOT EXISTS memory_items(
    id TEXT PRIMARY KEY,
    ts REAL NOT NULL,
    type TEXT NOT NULL,
    payload BLOB NOT NULL,
    embedding BLOB,
    tags TEXT,
    flags INTEGER DEFAULT 0
);
CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts
USING fts5(content='memory_items', payload);
"""
