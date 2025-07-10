import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide the window on launch
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.close()
        }

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Nest")
            button.action = #selector(toggleWindow)
        }
        
        // Start watching for clipboard changes
        ClipboardWatcher.shared.start()
    }

    @objc func toggleWindow() {
        if let window = window, window.isVisible {
            window.close()
        } else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}