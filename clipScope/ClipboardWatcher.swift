import Foundation
import AppKit

class ClipboardWatcher {
    static let shared = ClipboardWatcher()
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1
    private var ignoringInternalCopy = false
    private var isFromCombineOperation = false

    func start() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkClipboard()
        }
    }
    
    func willCopyFromHistory() {
        ignoringInternalCopy = true
        // Reset the flag after a longer delay to ensure we don't double-register combine operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.ignoringInternalCopy = false
        }
    }
    
    func willCopyFromCombineOperation() {
        isFromCombineOperation = true
        // Reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isFromCombineOperation = false
        }
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        // Skip saving if we're currently copying from our own history
        if ignoringInternalCopy {
            return
        }
        
        let sourceApp = NSWorkspace.shared.frontmostApplication
        var appName = sourceApp?.localizedName ?? "Unknown"
        
        // Check if this might be from Universal Clipboard
        // Universal Clipboard items often come when no specific app is frontmost
        // or when the change happens without user interaction in the current app
        if appName == "clipScope" || appName == "Nest" {
            return
        }
        
        // If frontmost app is Finder, Dock, or system processes, likely Universal Clipboard
        if appName == "Finder" || appName == "Dock" || appName == "loginwindow" || appName == "SystemUIServer" {
            appName = "System"
        }
        
        // Check for images first - try multiple image types
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            NSPasteboard.PasteboardType("com.apple.pict"),
            NSPasteboard.PasteboardType("public.jpeg")
        ]
        
        for imageType in imageTypes {
            if let imageData = pasteboard.data(forType: imageType) {
                ClipStorage.shared.save(
                    type: "public.image",
                    data: imageData,
                    applicationName: appName,
                    windowName: ""
                )
                return
            }
        }
        
        // Fallback to NSImage if direct data access fails
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tiffData = image.tiffRepresentation {
            ClipStorage.shared.save(
                type: "public.image",
                data: tiffData,
                applicationName: appName,
                windowName: ""
            )
            return
        }
        
        // Then check for standard text
        if let string = pasteboard.string(forType: .string) {
            let finalAppName = isFromCombineOperation ? "Nest Combine" : appName
            ClipStorage.shared.save(
                type: "public.utf8-plain-text",
                data: Data(string.utf8),
                applicationName: finalAppName,
                windowName: ""
            )
            return
        }
        
        // Finally check for other types
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                ClipStorage.shared.save(
                    type: type.rawValue,
                    data: data,
                    applicationName: appName,
                    windowName: ""
                )
                return
            }
        }
    }
}