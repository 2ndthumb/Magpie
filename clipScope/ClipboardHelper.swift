import AppKit
import Foundation

class ClipboardHelper {
    static let shared = ClipboardHelper()

    func copyToClipboard(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = Data(base64Encoded: item.base64Data) {
            pasteboard.setData(data, forType: .string)
        }
        // Universal Clipboard integration
        if #available(macOS 10.12, *) {
            pasteboard.setString(item.base64Data, forType: .string)
        }
    }

    func readFromClipboard() -> ClipItem? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .string),
           let base64String = String(data: data, encoding: .utf8),
           let decodedData = Data(base64Encoded: base64String) {
            return ClipItem(
                id: UUID(),
                type: "text",
                base64Data: base64String,
                timestamp: Date(),
                applicationName: "",
                windowName: ""
            )
        }
        return nil
    }

    func paste(data: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let decodedData = Data(base64Encoded: data.base64Data) {
            pasteboard.setData(decodedData, forType: .string)
        }
    }
}