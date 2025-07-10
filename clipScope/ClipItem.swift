import Foundation

struct ClipItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: String
    var base64Data: String
    let applicationName: String
    let windowName: String

    // Add support for additional file types
    var fileType: FileType {
        if type.contains("pdf") {
            return .pdf
        } else if type.contains("word") {
            return .word
        } else if type.contains("audio") {
            return .audio
        } else if type.contains("video") {
            return .video
        } else {
            return .none
        }
    }

    enum FileType: String {
        case pdf, word, audio, video, none, unknown
    }
}