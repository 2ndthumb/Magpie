import SwiftUI
import AppKit

class ImagePreviewWindowController: NSWindowController, NSWindowDelegate {
    convenience init(image: NSImage) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Image Preview"
        
        // Set minimum size based on image dimensions while maintaining aspect ratio
        let minSize: CGFloat = 200
        let aspectRatio = image.size.width / image.size.height
        let minWidth = max(minSize, minSize * aspectRatio)
        let minHeight = max(minSize, minSize / aspectRatio)
        window.minSize = NSSize(width: minWidth, height: minHeight)
        
        // Set initial size based on image dimensions, but cap at screen size
        if let screen = window.screen {
            let maxWidth = screen.frame.width * 0.8
            let maxHeight = screen.frame.height * 0.8
            let width = min(maxWidth, image.size.width)
            let height = min(maxHeight, image.size.height)
            window.setContentSize(NSSize(width: width, height: height))
        }
        
        self.init(window: window)
        window.center()
        window.delegate = self
        
        let view = ImagePreviewView(image: image)
        window.contentView = NSHostingView(rootView: view)
    }
    
    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.imagePreviewControllers.removeAll { $0 === self }
        }
    }
}

struct ImagePreviewView: View {
    let image: NSImage
    
    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding()
    }
}

extension View {
    func openInImagePreview(image: NSImage) {
        let windowController = ImagePreviewWindowController(image: image)
        windowController.showWindow(nil)
        // Keep a reference to the window controller
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.imagePreviewControllers.append(windowController)
        }
    }
} 