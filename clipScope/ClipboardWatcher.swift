import Foundation
import AppKit

class ClipboardWatcher {
    static let shared = ClipboardWatcher()
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1

    func start() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkClipboard()
        }
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let appName = sourceApp?.localizedName ?? "Unknown"
        
        // Prioritize specific data types to avoid clutter
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                let data = bitmap.representation(using: .png, properties: [:])
                ClipStorage.shared.save(type: "public.png", data: data ?? Data(), applicationName: appName, windowName: "")
            }
        } else if let string = pasteboard.string(forType: .string) {
            ClipStorage.shared.save(type: "public.utf8-plain-text", data: Data(string.utf8), applicationName: appName, windowName: "")
        } else if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL, url.isFileURL {
             ClipStorage.shared.save(type: "public.file-url", data: Data(url.path.utf8), applicationName: appName, windowName: "")
        }
    }
}