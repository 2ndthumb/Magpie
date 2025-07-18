import SwiftUI

struct QuickMenuItem: View {
    let item: ClipItem
    let isSelected: Bool
    let isCombineSelected: Bool
    let combineMode: Bool
    let onTap: () -> Void
    let onCombine: (() -> Void)?
    let onDelete: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 8) {
                if combineMode && isCombineSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
                itemPreview
                VStack(alignment: .leading, spacing: 3) {
                    Text(itemDisplayText)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if !item.applicationName.isEmpty {
                            Text(item.applicationName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Text(item.timestamp, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
                if !combineMode {
                    showMenu = true
                }
            }
            .onDrag {
                if let text = item.decodedText {
                    let provider = NSItemProvider(object: text as NSString)
                    if let url = item.detectedURL {
                        provider.registerObject(url as NSURL, visibility: .all)
                    }
                    return provider
                } else if let image = item.decodedImage {
                    return NSItemProvider(object: image)
                }
                return NSItemProvider()
            }
            .popover(isPresented: $showMenu, arrowEdge: .leading, content: {
                menuContent
                    .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
            })
        }
    }
    
    private var menuContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                copyToPasteboard()
                showMenu = false
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if let url = item.detectedURL {
                Divider()
                Button(action: {
                    LinkHelper.shared.openLink(url)
                    showMenu = false
                }) {
                    Label("Open in Browser", systemImage: "safari")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    showMenu = false
                }) {
                    Label("Copy URL", systemImage: "link")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            if item.type.contains("text"), let text = item.decodedText {
                Divider()
                Button(action: {
                    var editableText = text
                    openInTextEditor(text: .init(
                        get: { editableText },
                        set: { editableText = $0 }
                    )) {
                        // On save, create a new clipboard item
                        ClipboardWatcher.shared.willCopyFromCombineOperation()
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(editableText, forType: .string)
                    }
                    showMenu = false
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            if item.type.contains("image"), let image = item.decodedImage {
                Divider()
                Button(action: {
                    openInImagePreview(image: image)
                    showMenu = false
                }) {
                    Label("Preview", systemImage: "eye")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            if let onCombine = onCombine {
                Divider()
                Button(action: {
                    onCombine()
                    showMenu = false
                }) {
                    Label(isCombineSelected ? "Remove from Combine" : "Add to Combine", systemImage: isCombineSelected ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider()
            Button(role: .destructive, action: {
                onDelete()
                showMenu = false
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 150)
    }
    
    private var itemDisplayText: String {
        if let url = item.detectedURL {
            return url.host ?? url.absoluteString
        } else if let text = item.decodedText {
            return text
        } else if item.type.contains("image") {
            return "Image"
        } else if item.type.contains("file") {
            return "File"
        }
        return "Unknown"
    }
    
    private var itemPreview: some View {
        Group {
            if item.type.contains("image"),
               let nsImage = item.decodedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            } else if let url = item.detectedURL {
                Image(systemName: "link")
                    .foregroundColor(.accentColor)
            } else if item.type.contains("text") {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
            } else if item.type.contains("file") {
                Image(systemName: "doc")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "questionmark")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 32, height: 32)
    }
    
    private func copyToPasteboard() {
        ClipboardWatcher.shared.willCopyFromHistory()
        
        if item.type.contains("text"), let data = Data(base64Encoded: item.base64Data), let str = String(data: data, encoding: .utf8) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(str, forType: .string)
        } else if item.type.contains("image"), let data = Data(base64Encoded: item.base64Data), let nsImage = NSImage(data: data) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([nsImage])
        }
        // Add file support if needed
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color(.selectedMenuItemColor) : Color.clear)
            .contentShape(Rectangle())
    }
} 