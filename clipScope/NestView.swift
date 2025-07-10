import SwiftUI
import AVKit

struct NestView: View {
    @StateObject private var clipStorage = ClipStorage.shared
    @State private var selectedItemID: UUID? // Single selection
    @State private var multiSelection = Set<UUID>() // For combining
    @State private var isMultiSelectMode = false
    @State private var expireInterval: Int = 1
    @State private var searchText: String = ""
    @State private var filter: FilterType = .all
    @State private var viewMode: ViewMode = .list
    @State private var isEditing = false
    
    enum ViewMode { case list, grid }
    enum FilterType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case files = "Files"
    }
    
    private var filteredItems: [ClipItem] {
        let searched = clipStorage.items.filter {
            searchText.isEmpty ? true : $0.matches(searchText)
        }
        
        switch filter {
        case .all:
            return searched
        case .text:
            return searched.filter { $0.type.contains("text") }
        case .images:
            return searched.filter { $0.type.contains("image") }
        case .files:
            return searched.filter { $0.fileType != .unknown }
        }
    }
    
    private var selectedTextItems: [ClipItem] {
        clipStorage.items.filter { multiSelection.contains($0.id) && $0.type.contains("text") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Toolbar
            HStack {
                Text("Nest").font(.largeTitle).bold()
                Spacer()
                
                Button(action: { isMultiSelectMode.toggle() }) {
                    Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "text.badge.plus")
                    Text(isMultiSelectMode ? "Done" : "Combine")
                }
                
                if isMultiSelectMode && !multiSelection.isEmpty {
                    Button(action: copySelectedTextItems) {
                        Text("Copy \(multiSelection.count) Items")
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.2))

            // MARK: - Search and Filter Bar
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
            
            Divider().opacity(0)

            // MARK: - Content Area
            contentBody
            
            // MARK: - Footer / Settings
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
        .frame(minWidth: 400, minHeight: 600)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .onAppear(perform: setupView)
        .onChange(of: expireInterval) {
            clipStorage.expireInterval = TimeInterval($1 * 60 * 60 * 24)
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if filteredItems.isEmpty {
            VStack {
                Spacer()
                Text("No Clipboard Items")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("Your clipboard history will appear here.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(filteredItems) { item in
                        HistoryItemView(
                            item: item,
                            isSelected: isMultiSelectMode ? multiSelection.contains(item.id) : (selectedItemID == item.id),
                            isMultiSelectMode: isMultiSelectMode
                        )
                        .onTapGesture(count: 2) { // Double-tap to copy
                            ClipboardHelper.shared.paste(data: item)
                        }
                        .onTapGesture(count: 1) { // Single-tap to select
                            if isMultiSelectMode {
                                if multiSelection.contains(item.id) {
                                    multiSelection.remove(item.id)
                                } else {
                                    multiSelection.insert(item.id)
                                }
                            } else {
                                selectedItemID = item.id
                            }
                        }
                        .contextMenu {
                            Button("Copy", action: { ClipboardHelper.shared.paste(data: item) })
                            Button("Delete", action: { clipStorage.delete(item: item) })
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black.opacity(0.2))
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
}

struct HistoryItemView: View {
    let item: ClipItem
    var isSelected: Bool
    var isMultiSelectMode: Bool

    var body: some View {
        HStack(spacing: 15) {
            VStack {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                if isMultiSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(.top, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.sourceAppName)
                        .font(.headline)
                    Spacer()
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if item.type.contains("text"),
                   let decoded = Data(base64Encoded: item.base64Data),
                   let string = String(data: decoded, encoding: .utf8) {
                    Text(string)
                        .lineLimit(2)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text(item.typeDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                if isSelected {
                    VisualEffectView(material: .selection, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        )
        .overlay( // Keep overlay for a subtle border if needed, or remove
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
