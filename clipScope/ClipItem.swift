import Foundation

struct ClipItem: Identifiable, Codable {
    let id: UUID
    let type: String
    let base64Data: String
    let timestamp: Date
    let applicationName: String
    let windowName: String
    
    var detectedURL: URL? {
        if type.contains("text"),
           let data = Data(base64Encoded: base64Data),
           let text = String(data: data, encoding: .utf8) {
            return LinkHelper.shared.extractFirstLink(from: text)
        }
        return nil
    }
    
    var decodedText: String? {
        if type.contains("text"),
           let data = Data(base64Encoded: base64Data) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    var decodedImage: NSImage? {
        if type.contains("image"),
           let data = Data(base64Encoded: base64Data) {
            return NSImage(data: data)
        }
        return nil
    }
    
    enum FileType {
        case pdf
        case word
        case audio
        case video
        case unknown
        case none
    }
    
    var fileType: FileType {
        if type.contains("pdf") { return .pdf }
        if type.contains("word") || type.contains("doc") { return .word }
        if type.contains("audio") { return .audio }
        if type.contains("video") { return .video }
        if type.contains("file") { return .unknown }
        return .none
    }
    
    func matches(_ searchText: String) -> Bool {
        if applicationName.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        if let text = decodedText,
           text.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        return false
    }
}