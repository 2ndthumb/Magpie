import Foundation
import Testing
@testable import NestCore

struct MemoryStoreTests {
    @Test
    func searchHit() async throws {
        let item = MemoryItem(type: .text, payload: Data("hello world".utf8))
        try MemoryStore.shared.write(item)
        let results = try MemoryStore.shared.search(text: "hello")
        #expect(results.contains { $0.id == item.id })
    }

    @Test
    func searchMiss() async throws {
        let item = MemoryItem(type: .text, payload: Data("foo".utf8))
        try MemoryStore.shared.write(item)
        let results = try MemoryStore.shared.search(text: "bar")
        #expect(results.isEmpty)
    }

    @Test
    func performanceSearch() async throws {
        guard MemoryStore.shared.isFTSAvailable else { return }
        for i in 0..<10000 {
            let item = MemoryItem(type: .text, payload: Data("sample \(i)".utf8))
            try MemoryStore.shared.write(item)
        }
        let start = Date()
        _ = try MemoryStore.shared.search(text: "sample 9999")
        let duration = Date().timeIntervalSince(start)
        #expect(duration < 0.12)
    }
}
