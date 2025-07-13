import Foundation

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
CREATE TRIGGER IF NOT EXISTS memory_ai AFTER INSERT ON memory_items BEGIN
    INSERT INTO memory_fts(rowid, payload) VALUES (new.rowid, new.payload);
END;
CREATE TRIGGER IF NOT EXISTS memory_ad AFTER DELETE ON memory_items BEGIN
    INSERT INTO memory_fts(memory_fts, rowid, payload) VALUES('delete', old.rowid, old.payload);
END;
CREATE TRIGGER IF NOT EXISTS memory_au AFTER UPDATE ON memory_items BEGIN
    INSERT INTO memory_fts(memory_fts, rowid, payload) VALUES('delete', old.rowid, old.payload);
    INSERT INTO memory_fts(rowid, payload) VALUES (new.rowid, new.payload);
END;
"""
