import Testing
@testable import NestCore

struct MemoryStoreTests {
    @Test
    func writeAndSearch() async throws {
        let item = MemoryItem(type: .text, payload: Data("hello world".utf8))
        try MemoryStore.shared.write(item)
        let results = try MemoryStore.shared.search(text: "hello")
        #expect(results.contains { $0.id == item.id })
    }
}
