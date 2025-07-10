import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide the window on launch
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.close()
        }

        // Create the popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: QuickMenuView(onExpand: showFullWindow))

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let magpieImage = NSImage(named: "magpie")
            magpieImage?.isTemplate = true // This makes it work with dark/light mode
            button.image = magpieImage
            button.action = #selector(togglePopover)
        }
        
        // Start watching for clipboard changes
        ClipboardWatcher.shared.start()
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func showFullWindow() {
        popover?.performClose(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Quick menu view for the popover
struct QuickMenuView: View {
    @StateObject private var clipStorage = ClipStorage.shared
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var selectedItems = Set<UUID>()
    @State private var combineMode = false
    @State private var selectedItemID: UUID?
    @State private var viewMode: ViewMode = .list
    let onExpand: () -> Void
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case files = "Files"
        
        var icon: String {
            switch self {
            case .all: return "doc.on.doc"
            case .text: return "doc.text"
            case .images: return "photo"
            case .files: return "folder"
            }
        }
    }
    
    enum ViewMode { case list, grid }
    
    var filteredItems: [ClipItem] {
        let searched = clipStorage.items.filter {
            searchText.isEmpty ? true : $0.matches(searchText)
        }
        
        switch selectedFilter {
        case .all:
            return searched
        case .text:
            return searched.filter { $0.type.contains("text") }
        case .images:
            return searched.filter { $0.type.contains("image") }
        case .files:
            return searched.filter { 
                !$0.type.contains("text") && 
                !$0.type.contains("image") && 
                ($0.fileType != .unknown && $0.fileType != .none)
            }
        }
    }
    
    var selectedTextItems: [ClipItem] {
        clipStorage.items.filter { selectedItems.contains($0.id) && $0.type.contains("text") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search clipboard...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(.textBackgroundColor).opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top)
            
            // Filter and actions bar
            HStack(spacing: 4) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .background(selectedFilter == filter ? Color.accentColor : Color.clear)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Button(action: { combineMode.toggle(); if !combineMode { selectedItems.removeAll() } }) {
                    Image(systemName: combineMode ? "checkmark.circle.fill" : "text.badge.plus")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .cornerRadius(6)
                .foregroundColor(combineMode ? .accentColor : .primary)
                
                Button(action: { viewMode = viewMode == .list ? .grid : .list }) {
                    Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .cornerRadius(6)
                
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .cornerRadius(6)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if combineMode && !selectedItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTextItems) { item in
                            if let decoded = Data(base64Encoded: item.base64Data),
                               let string = String(data: decoded, encoding: .utf8) {
                                Text(string)
                                    .lineLimit(1)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 30)
                .background(Color(.textBackgroundColor).opacity(0.05))
            }
            
            Divider()
                .background(Color.secondary.opacity(0.2))
            
            // Items list/grid
            ScrollView {
                if viewMode == .grid {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(filteredItems.prefix(10)) { item in
                            QuickGridItem(
                                item: item,
                                isSelected: combineMode ? selectedItems.contains(item.id) : (selectedItemID == item.id),
                                isCombineSelected: selectedItems.contains(item.id),
                                combineMode: combineMode,
                                onTap: {
                                    if combineMode {
                                        if selectedItems.contains(item.id) {
                                            selectedItems.remove(item.id)
                                        } else {
                                            selectedItems.insert(item.id)
                                        }
                                    } else {
                                        if selectedItemID == item.id {
                                            selectedItemID = nil
                                        } else {
                                            selectedItemID = item.id
                                        }
                                    }
                                },
                                onCombine: item.type.contains("text") ? {
                                    if selectedItems.contains(item.id) {
                                        selectedItems.remove(item.id)
                                    } else {
                                        selectedItems.insert(item.id)
                                        // Automatically enter combine mode when adding an item
                                        if !combineMode {
                                            combineMode = true
                                        }
                                    }
                                } : nil,
                                onDelete: {
                                    selectedItems.remove(item.id)
                                    selectedItemID = nil
                                    clipStorage.delete(item: item)
                                }
                            )
                        }
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems.prefix(10)) { item in
                            QuickMenuItem(
                                item: item,
                                isSelected: combineMode ? selectedItems.contains(item.id) : (selectedItemID == item.id),
                                isCombineSelected: selectedItems.contains(item.id),
                                combineMode: combineMode,
                                onTap: {
                                    if combineMode {
                                        if selectedItems.contains(item.id) {
                                            selectedItems.remove(item.id)
                                        } else {
                                            selectedItems.insert(item.id)
                                        }
                                    } else {
                                        if selectedItemID == item.id {
                                            selectedItemID = nil
                                        } else {
                                            selectedItemID = item.id
                                        }
                                    }
                                },
                                onCombine: item.type.contains("text") ? {
                                    if selectedItems.contains(item.id) {
                                        selectedItems.remove(item.id)
                                    } else {
                                        selectedItems.insert(item.id)
                                        // Automatically enter combine mode when adding an item
                                        if !combineMode {
                                            combineMode = true
                                        }
                                    }
                                } : nil,
                                onDelete: {
                                    selectedItems.remove(item.id)
                                    selectedItemID = nil
                                    clipStorage.delete(item: item)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onChange(of: combineMode) { newValue in
            if !newValue && !selectedItems.isEmpty {
                combineSelectedItems()
            }
        }
    }
    
    private func copyItem(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.type == "public.image" {
            if let imageData = Data(base64Encoded: item.base64Data) {
                // Try to create NSImage first
                if let image = NSImage(data: imageData) {
                    pasteboard.writeObjects([image])
                } else {
                    // Fallback: try different image types
                    pasteboard.setData(imageData, forType: .tiff)
                    pasteboard.setData(imageData, forType: .png)
                }
            }
        } else if item.type.contains("text"),
                  let data = Data(base64Encoded: item.base64Data),
                  let string = String(data: data, encoding: .utf8) {
            pasteboard.setString(string, forType: .string)
        } else if let data = Data(base64Encoded: item.base64Data) {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(item.type))
        }
    }
    
    private func combineSelectedItems() {
        let combined = selectedTextItems
            .compactMap { item in
                Data(base64Encoded: item.base64Data)
                    .flatMap { String(data: $0, encoding: .utf8) }
            }
            .joined(separator: "\n")
        
        ClipboardWatcher.shared.willCopyFromCombineOperation()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
        
        selectedItems.removeAll()
    }
}

struct QuickGridItem: View {
    let item: ClipItem
    let isSelected: Bool
    let isCombineSelected: Bool
    let combineMode: Bool
    let onTap: () -> Void
    let onCombine: (() -> Void)?
    let onDelete: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Content Preview
            Group {
                if item.type.contains("image"),
                   let imageData = Data(base64Encoded: item.base64Data),
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if item.type.contains("text"),
                          let decoded = Data(base64Encoded: item.base64Data),
                          let string = String(data: decoded, encoding: .utf8) {
                    Text(string)
                        .lineLimit(3)
                        .font(.system(size: 11, design: .default))
                        .lineSpacing(1)
                        .padding(8)
                        .frame(height: 60, alignment: .topLeading)
                } else {
                    Image(systemName: itemIcon)
                        .font(.system(size: 24))
                        .frame(height: 60)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor).opacity(0.1))
            .cornerRadius(6)
            
            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.sourceAppName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(relativeTimeString(from: item.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
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
                showMenu = true
            }
        }
        .popover(isPresented: $showMenu, arrowEdge: .leading, content: {
            menuContent
                .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
        })
    }
    
    private var menuContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                copyToPasteboard()
                showMenu = false
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(MenuButtonStyle())
            
            if let onCombine = onCombine {
                Divider()
                Button(action: {
                    onCombine()
                    showMenu = false
                }) {
                    Label(isCombineSelected ? "Remove from Combine" : "Add to Combine", systemImage: isCombineSelected ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(MenuButtonStyle())
            }
            
            Divider()
            Button(action: {
                onDelete()
                showMenu = false
            }) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(MenuButtonStyle())
        }
        .frame(width: 150)
        .cornerRadius(8)
        .padding(4)
    }
    
    private var itemIcon: String {
        if item.type.contains("text") { return "doc.text" }
        if item.type.contains("image") { return "photo" }
        return "doc"
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


