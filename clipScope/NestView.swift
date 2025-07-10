import SwiftUI
import Combine
import AVKit
import AppKit

struct NestView: View {
    @StateObject private var clipStorage = ClipStorage.shared
    @State private var selectedItemID: UUID?
    @State private var multiSelection: [UUID] = []
    @State private var isMultiSelectMode = false
    @State private var normalModeSelectedID: UUID?
    @State private var expireInterval: Int = 1
    @State private var searchText: String = ""
    @State private var filter: FilterType = .all
    @State private var viewMode: ViewMode = .grid  // Default to grid
    @State private var isEditing = false
    @State private var timerTick: Date = Date()
    @State private var previewingItem: ClipItem? = nil
    
    enum ViewMode { case list, grid }
    enum FilterType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case files = "Files"
    }
    
    private var selectedTextItems: [ClipItem] {
        clipStorage.items.filter { multiSelection.contains($0.id) && $0.type.contains("text") }
    }

    private func filterBySearch(_ items: [ClipItem]) -> [ClipItem] {
        searchText.isEmpty ? items : items.filter { $0.matches(searchText) }
    }
    
    private func filterByType(_ items: [ClipItem], type: FilterType) -> [ClipItem] {
        switch type {
        case .all:
            return items
        case .text:
            return items.filter { $0.type.contains("text") }
        case .images:
            return items.filter { $0.type.contains("public.image") }
        case .files:
            return items.filter {
                !$0.type.contains("text") &&
                !$0.type.contains("public.image") &&
                ($0.fileType != .unknown && $0.fileType != .none)
            }
        }
    }

    private var displayItems: [ClipItem] {
        let searchFiltered = filterBySearch(clipStorage.items)
        return filterByType(searchFiltered, type: filter)
    }
    
    private func handleCombineButtonTap() {
        if isMultiSelectMode && !multiSelection.isEmpty {
            combineSelectedTextItems()
        } else {
            isMultiSelectMode.toggle()
            if !isMultiSelectMode { multiSelection.removeAll() }
        }
    }
    
    private var toolbarView: some View {
        HStack {
            Image(.magpie)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .foregroundStyle(.quaternary)
            Text("Nest").font(.largeTitle).bold()
            Spacer()
            Button(action: handleCombineButtonTap) {
                Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "text.badge.plus")
                Text(isMultiSelectMode ? "Finish" : "Combine")
            }
            .foregroundColor(isMultiSelectMode ? .accentColor : .primary)
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
    
    private var searchAndFilterView: some View {
        HStack {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            
            Picker("Filter", selection: $filter) {
                ForEach(FilterType.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(ViewMode.list)
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.2))
    }
    
    private var footerView: some View {
        VStack {
            Divider()
            HStack {
                Stepper("Expire items after: \(expireInterval) day(s)", value: $expireInterval, in: 1...30)
                Spacer()
            }
            .padding()
        }
        .background(Color.black.opacity(0.2))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            searchAndFilterView
            Divider().opacity(0)
            contentBody
            footerView
        }
        .frame(minWidth: 400, minHeight: 600)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .onAppear(perform: setupView)
        .onChange(of: expireInterval) { oldValue, newValue in
            clipStorage.expireInterval = TimeInterval(newValue * 60 * 60 * 24)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            timerTick = now
        }
        .sheet(item: $previewingItem) { item in
            if item.type.contains("text"), let decoded = Data(base64Encoded: item.base64Data), let string = String(data: decoded, encoding: .utf8) {
                MinimalTextEditorView(text: string)
            } else if item.type.contains("image"), let decoded = Data(base64Encoded: item.base64Data), let nsImage = NSImage(data: decoded) {
                MinimalImagePreviewView(image: nsImage)
            } else {
                Text("Cannot preview this item.")
                    .frame(width: 300, height: 200)
            }
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if displayItems.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(.magpie)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.quaternary)
                Text("Empty Nest")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("Go collect some treasures!")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                if viewMode == .grid {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
                    ], spacing: 12) {
                        ForEach(displayItems) { item in
                            gridItemView(for: item)
                        }
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(displayItems) { item in
                            listItemView(for: item)
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.2))
        }
    }

    private func handleItemSelection(itemId: UUID) {
        if isMultiSelectMode {
            if let idx = multiSelection.firstIndex(of: itemId) {
                multiSelection.remove(at: idx)
            } else {
                multiSelection.append(itemId)
            }
        } else {
            if normalModeSelectedID == itemId {
                normalModeSelectedID = nil
            } else {
                normalModeSelectedID = itemId
            }
        }
    }
    
    private func handleItemCombine(itemId: UUID) {
        if multiSelection.contains(itemId) {
            if let idx = multiSelection.firstIndex(of: itemId) {
                multiSelection.remove(at: idx)
            }
        } else {
            multiSelection.append(itemId)
            // Automatically enter combine mode when adding an item
            if !isMultiSelectMode {
                isMultiSelectMode = true
            }
        }
    }
    
    private func handleItemDelete(item: ClipItem) {
        if let idx = multiSelection.firstIndex(of: item.id) {
            multiSelection.remove(at: idx)
        }
        normalModeSelectedID = nil
        clipStorage.delete(item: item)
    }

    private func copyItem(_ item: ClipItem) {
        ClipboardWatcher.shared.willCopyFromHistory()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(String(data: Data(base64Encoded: item.base64Data)!, encoding: .utf8)!, forType: .string)
    }

    private func gridItemView(for item: ClipItem) -> some View {
        let isSelected = isMultiSelectMode ? multiSelection.contains(item.id) : (normalModeSelectedID == item.id)
        let isText = item.type.contains("text")
        return GridItemView(
            item: item,
            isSelected: isSelected,
            isCombineSelected: multiSelection.contains(item.id),
            combineMode: isMultiSelectMode,
            onTap: { handleItemSelection(itemId: item.id) },
            onCombine: isText ? { handleItemCombine(itemId: item.id) } : nil,
            onDelete: { handleItemDelete(item: item) },
            onCopy: { copyItem(item) }
        )
        .onTapGesture(count: 2) {
            previewingItem = item
        }
    }

    private func listItemView(for item: ClipItem) -> some View {
        let isSelected = isMultiSelectMode ? multiSelection.contains(item.id) : (normalModeSelectedID == item.id)
        let isText = item.type.contains("text")
        return QuickMenuItem(
            item: item,
            isSelected: isSelected,
            isCombineSelected: multiSelection.contains(item.id),
            combineMode: isMultiSelectMode,
            onTap: { handleItemSelection(itemId: item.id) },
            onCombine: isText ? { handleItemCombine(itemId: item.id) } : nil,
            onDelete: { handleItemDelete(item: item) }
        )
        .onTapGesture(count: 2) {
            previewingItem = item
        }
    }
    
    private func setupView() {
        // items are now observed from clipStorage
        expireInterval = Int(clipStorage.expireInterval / (60 * 60 * 24))
        selectedItemID = clipStorage.items.first?.id
    }
    
    private func copySelectedTextItems() {
        let combined = clipStorage.items
            .filter { multiSelection.contains($0.id) }
            .compactMap { item in
                Data(base64Encoded: item.base64Data).flatMap { String(data: $0, encoding: .utf8) }
            }
            .joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
        
        isMultiSelectMode = false
        multiSelection.removeAll()
    }
    
    private func combineSelectedTextItems() {
        let combined = multiSelection.compactMap { id in
            clipStorage.items.first(where: { $0.id == id && $0.type.contains("text") })
                .flatMap { Data(base64Encoded: $0.base64Data).flatMap { String(data: $0, encoding: .utf8) } }
        }.joined(separator: "\n")
        
        ClipboardWatcher.shared.willCopyFromCombineOperation()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
        
        multiSelection.removeAll()
        isMultiSelectMode = false
    }
    
    private func handleItemTap(_ item: ClipItem) {
        if isMultiSelectMode {
            if let idx = multiSelection.firstIndex(of: item.id) {
                multiSelection.remove(at: idx)
            } else {
                multiSelection.append(item.id)
            }
        } else {
            selectedItemID = item.id
        }
    }
}

struct GridItemView: View {
    let item: ClipItem
    var isSelected: Bool
    var isCombineSelected: Bool = false
    var combineMode: Bool = false
    var onTap: () -> Void = {}
    var onDoubleTap: (() -> Void)?
    var onCombine: (() -> Void)?
    var onDelete: (() -> Void)?
    var onCopy: (() -> Void)?
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content Preview
            contentPreview
            
            // Metadata
            metadataView
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if combineMode && isCombineSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .background(Color(.windowBackgroundColor))
                    .clipShape(Circle())
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
            if !combineMode {
                showingMenu = true
            }
        }
        .popover(isPresented: $showingMenu, arrowEdge: .leading, content: {
            menuContent
                .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
        })
    }
    
    private var contentPreview: some View {
        Group {
            if item.type.contains("image"),
               let imageData = Data(base64Encoded: item.base64Data),
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if item.type.contains("text"),
                      let decoded = Data(base64Encoded: item.base64Data),
                      let string = String(data: decoded, encoding: .utf8) {
                Text(string)
                    .lineLimit(5)
                    .font(.system(size: 13, design: .default))
                    .lineSpacing(2)
                    .padding(12)
                    .frame(height: 120, alignment: .topLeading)
            } else {
                Image(systemName: item.iconName)
                    .font(.system(size: 40))
                    .frame(height: 120)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.textBackgroundColor).opacity(0.1))
        .cornerRadius(8)
    }
    
    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.sourceAppName)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(relativeTimeString(from: item.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }
    
    private var menuContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                onCopy?()
                showingMenu = false
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(MenuButtonStyle())
            
            if onCombine != nil {
                Divider()
                Button(action: {
                    onCombine?()
                    showingMenu = false
                }) {
                    Label(isCombineSelected ? "Remove from Combine" : "Add to Combine", systemImage: isCombineSelected ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(MenuButtonStyle())
            }
            
            if onDelete != nil {
                Divider()
                Button(action: {
                    onDelete?()
                    showingMenu = false
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(MenuButtonStyle())
            }
        }
        .frame(width: 150)
        .cornerRadius(8)
        .padding(4)
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        }
        return ""
    }
}

struct ListItemView: View {
    let item: ClipItem
    var isSelected: Bool
    var isMultiSelectMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon or Image Preview
            Group {
                if item.type.contains("image"),
                   let imageData = Data(base64Encoded: item.base64Data),
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                Image(systemName: item.iconName)
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if item.type.contains("text"),
                   let decoded = Data(base64Encoded: item.base64Data),
                   let string = String(data: decoded, encoding: .utf8) {
                    Text(string)
                        .lineLimit(2)
                        .font(.system(size: 13))
                } else {
                    Text(item.typeDescription)
                        .font(.system(size: 13))
                }
                
                HStack {
                    Text(item.sourceAppName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        }
        return ""
    }
}



// A helper view to create the frosted glass effect
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}


extension ClipItem {
    var iconName: String {
        switch fileType {
        case .pdf: return "doc.richtext.fill"
        case .word: return "doc.text.fill"
        case .audio: return "waveform"
        case .video: return "video.fill"
        case .none:
            if type.contains("image") { return "photo" }
            if type.contains("text") { return "text.quote" }
            return "doc.on.doc"
        case .unknown:
            return "questionmark.diamond.fill"
        }
    }
    
    var typeDescription: String {
        if type.contains("image") { return "Image" }
        switch fileType {
        case .pdf: return "PDF Document"
        case .word: return "Word Document"
        case .audio: return "Audio File"
        case .video: return "Video File"
        case .unknown: return "File"
        case .none: return "Text"
        }
    }
    
    var sourceAppName: String {
        applicationName.isEmpty ? "Unknown App" : applicationName
    }
    
    func matches(_ searchText: String) -> Bool {
        if sourceAppName.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        if let decoded = Data(base64Encoded: base64Data),
           let string = String(data: decoded, encoding: .utf8),
           string.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        return false
    }
}

struct MinimalTextEditorView: View {
    @State var text: String
    var body: some View {
        VStack(spacing: 0) {
            Text("Text Preview")
                .font(.headline)
                .padding(.top, 8)
            Divider()
            TextEditor(text: $text)
                .font(.system(size: 14, design: .monospaced))
                .padding()
        }
        .frame(width: 400, height: 300)
    }
}

struct MinimalImagePreviewView: View {
    let image: NSImage
    var body: some View {
        VStack(spacing: 0) {
            Text("Image Preview")
                .font(.headline)
                .padding(.top, 8)
            Divider()
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        }
        .frame(width: 400, height: 300)
    }
}
