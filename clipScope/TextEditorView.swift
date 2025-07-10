import SwiftUI

struct TextEditorView: View {
    @Binding var text: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .font(.body)
                .padding()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    onSave()
                    dismiss()
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Text"
        window.center()
        
        let view = TextEditorView(text: text, onSave: onSave)
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
    }
} 