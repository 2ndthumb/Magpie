import SwiftUI
import AppKit

class TextEditorWindowController: NSWindowController, NSWindowDelegate {
    private var onSave: () -> Void
    
    convenience init(text: Binding<String>, onSave: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Text"
        window.minSize = NSSize(width: 300, height: 200)
        
        self.init(window: window)
        self.onSave = onSave
        window.center()
        window.delegate = self
        
        let view = TextEditorView(text: text, onSave: { [weak self] in
            self?.onSave()
            self?.close()
        })
        window.contentView = NSHostingView(rootView: view)
    }
    
    func windowWillClose(_ notification: Notification) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.textEditorControllers.removeAll { $0 === self }
        }
    }
}

struct TextEditorView: View {
    @Binding var text: String
    var onSave: () -> Void
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .font(.body)
                .padding()
            
            HStack {
                Button("Cancel") {
                    if let window = NSApp.keyWindow {
                        window.close()
                    }
                }
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

extension View {
    func openInTextEditor(text: Binding<String>, onSave: @escaping () -> Void) {
        let windowController = TextEditorWindowController(text: text, onSave: onSave)
        windowController.showWindow(nil)
        // Keep a reference to the window controller
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.textEditorControllers.append(windowController)
        }
    }
} 