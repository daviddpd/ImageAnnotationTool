import AppKit
import SwiftUI

struct FilesSidebarSection: View {
    @ObservedObject private var store = AnnotationAppStore.shared
    @State private var expandedDirectoryIDs: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files")
                    .font(.headline)
                Spacer()
                if store.isFilteringFiles {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
        .onChange(of: store.rootDirectoryURL?.path) { _ in
            expandedDirectoryIDs.removeAll()
        }
        .onChange(of: store.isScanningDirectory) { isScanning in
            if isScanning {
                expandedDirectoryIDs.removeAll()
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if !store.hasRootDirectory {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    store.openDirectoryPanel()
                } label: {
                    Label("Open Directory…", systemImage: "folder.badge.plus")
                }
                Text("Supports .jpg, .jpeg, .png")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if store.isScanningDirectory {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView()
                Text(store.scanProgressMessage ?? "Scanning directory…")
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let root = store.displayedFileTreeRoot, root.descendantFileCount > 0 {
            FilesOutlineTreeView(
                store: store,
                rootNode: root,
                structureVersion: store.fileTreeStructureVersion,
                decorationVersion: store.fileTreeDecorationsVersion,
                selectedImageURL: store.selectedImageURL,
                isSearchActive: store.isSidebarSearchActive,
                expandedDirectoryIDs: expandedDirectoryIDs,
                onExpandedDirectoryIDsChanged: { expandedDirectoryIDs = $0 }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        } else {
            Text(store.isSidebarSearchActive ? "No matching files" : "No jpg/png images found")
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct FilesOutlineTreeView: NSViewRepresentable {
    let store: AnnotationAppStore
    let rootNode: SidebarFileTreeNode
    let structureVersion: UInt64
    let decorationVersion: UInt64
    let selectedImageURL: URL?
    let isSearchActive: Bool
    let expandedDirectoryIDs: Set<String>
    let onExpandedDirectoryIDsChanged: (Set<String>) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 22
        outlineView.indentationPerLevel = 14
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.floatsGroupRows = false
        outlineView.focusRingType = .none
        outlineView.backgroundColor = .clear
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        outlineView.target = context.coordinator
        outlineView.action = #selector(Coordinator.outlineAction(_:))
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FilesColumn"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        scrollView.documentView = outlineView
        context.coordinator.outlineView = outlineView
        context.coordinator.apply(parent: self, forceStructureReload: true)
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.apply(parent: self, forceStructureReload: false)
    }
    
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private(set) var parent: FilesOutlineTreeView
        weak var outlineView: NSOutlineView?
        
        private var rootNode: SidebarFileTreeNode?
        private var fileNodeByURL: [URL: SidebarFileTreeNode] = [:]
        private var lastStructureVersion: UInt64 = .max
        private var lastDecorationVersion: UInt64 = .max
        private var lastSelectedImageURL: URL?
        private var lastSearchActive = false
        private var expandedDirectoryIDs: Set<String> = []
        private var isRestoringExpansion = false
        
        init(parent: FilesOutlineTreeView) {
            self.parent = parent
            self.expandedDirectoryIDs = parent.expandedDirectoryIDs
        }
        
        func apply(parent: FilesOutlineTreeView, forceStructureReload: Bool) {
            self.parent = parent
            guard let outlineView else { return }
            
            let structureChanged = forceStructureReload || lastStructureVersion != parent.structureVersion
            let decorationsChanged = lastDecorationVersion != parent.decorationVersion
            let searchStateChanged = lastSearchActive != parent.isSearchActive
            let externalExpansionChanged = self.expandedDirectoryIDs != parent.expandedDirectoryIDs
            
            if structureChanged {
                rootNode = parent.rootNode
                rebuildNodeIndex()
                outlineView.reloadData()
                if parent.isSearchActive {
                    expandAllDirectories()
                } else {
                    if externalExpansionChanged {
                        self.expandedDirectoryIDs = parent.expandedDirectoryIDs
                    }
                    restoreExpandedDirectories()
                }
                lastStructureVersion = parent.structureVersion
            } else if searchStateChanged {
                if parent.isSearchActive {
                    expandAllDirectories()
                } else {
                    if externalExpansionChanged {
                        self.expandedDirectoryIDs = parent.expandedDirectoryIDs
                    }
                    restoreExpandedDirectories()
                }
            } else if externalExpansionChanged && !parent.isSearchActive {
                self.expandedDirectoryIDs = parent.expandedDirectoryIDs
                restoreExpandedDirectories()
            }
            
            if decorationsChanged {
                reloadVisibleRows()
                lastDecorationVersion = parent.decorationVersion
            }
            
            if structureChanged || lastSelectedImageURL != parent.selectedImageURL || searchStateChanged {
                syncSelection()
                lastSelectedImageURL = parent.selectedImageURL
            }
            
            lastSearchActive = parent.isSearchActive
        }
        
        @objc func outlineAction(_ sender: Any?) {
            guard let outlineView else { return }
            let row = outlineView.clickedRow
            guard row >= 0, let node = outlineView.item(atRow: row) as? SidebarFileTreeNode else { return }
            if node.isDirectory {
                if outlineView.isItemExpanded(node) {
                    outlineView.collapseItem(node)
                } else {
                    outlineView.expandItem(node)
                }
            }
        }
        
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            guard let rootNode else { return 0 }
            guard let node = item as? SidebarFileTreeNode else {
                return 1
            }
            return node.isDirectory ? node.children.count : 0
        }
        
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            guard let rootNode else {
                fatalError("Missing root node")
            }
            guard let node = item as? SidebarFileTreeNode else {
                return rootNode
            }
            return node.children[index]
        }
        
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? SidebarFileTreeNode else { return false }
            return node.isDirectory && !node.children.isEmpty
        }
        
        func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            guard let node = item as? SidebarFileTreeNode else { return false }
            return !node.isDirectory
        }
        
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? SidebarFileTreeNode else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("SidebarFileTreeCell")
            let cell = (outlineView.makeView(withIdentifier: identifier, owner: nil) as? SidebarFileTreeCellView)
                ?? SidebarFileTreeCellView(frame: .zero)
            cell.identifier = identifier
            
            let hasWarning = !node.isDirectory && parent.store.loadWarningsByImageURL[node.url] != nil
            let isDirty = !node.isDirectory && parent.store.dirtyImageURLs.contains(node.url)
            cell.configure(node: node, hasWarning: hasWarning, isDirty: isDirty)
            return cell
        }
        
        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView else { return }
            let row = outlineView.selectedRow
            guard row >= 0, let node = outlineView.item(atRow: row) as? SidebarFileTreeNode, !node.isDirectory else {
                return
            }
            if parent.store.selectedImageURL != node.url {
                parent.store.selectImage(url: node.url)
            }
        }
        
        func outlineViewItemDidExpand(_ notification: Notification) {
            guard !isRestoringExpansion, !parent.isSearchActive else { return }
            guard let node = notification.userInfo?["NSObject"] as? SidebarFileTreeNode else { return }
            expandedDirectoryIDs.insert(node.id)
            parent.onExpandedDirectoryIDsChanged(expandedDirectoryIDs)
        }
        
        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard !isRestoringExpansion, !parent.isSearchActive else { return }
            guard let node = notification.userInfo?["NSObject"] as? SidebarFileTreeNode else { return }
            expandedDirectoryIDs.remove(node.id)
            parent.onExpandedDirectoryIDsChanged(expandedDirectoryIDs)
        }
        
        private func rebuildNodeIndex() {
            fileNodeByURL.removeAll(keepingCapacity: true)
            guard let rootNode else { return }
            
            func visit(_ node: SidebarFileTreeNode) {
                if node.isDirectory {
                    for child in node.children {
                        visit(child)
                    }
                } else {
                    fileNodeByURL[node.url] = node
                }
            }
            
            visit(rootNode)
        }
        
        private func reloadVisibleRows() {
            guard let outlineView else { return }
            let visibleRange = outlineView.rows(in: outlineView.visibleRect)
            guard visibleRange.length > 0 else { return }
            let rowIndexes = IndexSet(integersIn: visibleRange.location..<(visibleRange.location + visibleRange.length))
            let columnIndexes = IndexSet(integer: 0)
            outlineView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
        }
        
        private func syncSelection() {
            guard let outlineView else { return }
            guard let selectedImageURL = parent.selectedImageURL,
                  let selectedNode = fileNodeByURL[selectedImageURL] else {
                if outlineView.selectedRow >= 0 {
                    outlineView.deselectAll(nil)
                }
                return
            }
            
            let targetRow = outlineView.row(forItem: selectedNode)
            if targetRow >= 0 {
                if outlineView.selectedRow != targetRow {
                    outlineView.selectRowIndexes(IndexSet(integer: targetRow), byExtendingSelection: false)
                }
            } else if !parent.isSearchActive {
                if outlineView.selectedRow >= 0 {
                    outlineView.deselectAll(nil)
                }
            }
        }
        
        private func restoreExpandedDirectories() {
            guard let outlineView, let rootNode else { return }
            isRestoringExpansion = true
            defer { isRestoringExpansion = false }
            
            outlineView.collapseItem(nil, collapseChildren: true)
            
            func visit(_ node: SidebarFileTreeNode) {
                guard node.isDirectory else { return }
                if expandedDirectoryIDs.contains(node.id) {
                    outlineView.expandItem(node)
                }
                for child in node.children where child.isDirectory {
                    visit(child)
                }
            }
            
            visit(rootNode)
        }
        
        private func expandAllDirectories() {
            guard let outlineView, let rootNode else { return }
            isRestoringExpansion = true
            defer { isRestoringExpansion = false }
            
            func visit(_ node: SidebarFileTreeNode) {
                guard node.isDirectory else { return }
                if !node.children.isEmpty {
                    outlineView.expandItem(node)
                }
                for child in node.children where child.isDirectory {
                    visit(child)
                }
            }
            
            visit(rootNode)
        }
    }
}

private final class SidebarFileTreeCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = false
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        addSubview(iconView)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(node: SidebarFileTreeNode, hasWarning: Bool, isDirty: Bool) {
        if node.isDirectory {
            iconView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")
            iconView.contentTintColor = .secondaryLabelColor
            titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = .labelColor
            titleLabel.stringValue = node.name
            return
        }
        
        iconView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        iconView.contentTintColor = hasWarning ? .systemOrange : .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = hasWarning ? .systemOrange : .labelColor
        
        var title = node.name
        if isDirty {
            title += " • Unsaved"
        }
        if hasWarning {
            title += " • Warning"
        }
        titleLabel.stringValue = title
    }
}

struct FilesSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        FilesSidebarSection()
            .frame(width: 260, height: 400)
    }
}
