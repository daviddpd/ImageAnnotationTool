import SwiftUI

struct GeneralSidebarSection: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    @State private var expandedDirectoryIDs: Set<String> = []
    @State private var cachedRootNode: FileTreeNode?
    @State private var cachedFilteredFileCount: Int = 0
    
    var body: some View {
        Section(header: Text("Files")) {
            if !store.hasRootDirectory {
                Button {
                    store.openDirectoryPanel()
                } label: {
                    Label("Open Directory…", systemImage: "folder.badge.plus")
                }
            } else if store.isScanningDirectory {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(store.scanProgressMessage ?? "Scanning directory…")
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            } else if store.imageFiles.isEmpty {
                Text("No jpg/png images found")
                    .foregroundColor(.secondary)
            } else if cachedFilteredFileCount == 0 {
                Text("No matching files")
                    .foregroundColor(.secondary)
            } else if let rootNode = cachedRootNode {
                FileTreeNodeRow(
                    node: rootNode,
                    expandedDirectoryIDs: $expandedDirectoryIDs,
                    isSearchActive: isSearchActive
                )
            } else {
                Text("No matching files")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            rebuildTreeCache()
        }
        .onChange(of: store.rootDirectoryURL?.path) { _ in
            expandedDirectoryIDs.removeAll()
            rebuildTreeCache()
        }
        .onChange(of: store.imageFiles) { _ in
            rebuildTreeCache()
        }
        .onChange(of: store.sidebarSearchText) { _ in
            rebuildTreeCache()
        }
        .onChange(of: store.isScanningDirectory) { isScanning in
            if isScanning {
                expandedDirectoryIDs.removeAll()
                cachedRootNode = nil
                cachedFilteredFileCount = 0
            } else {
                rebuildTreeCache()
            }
        }
    }
    
    private var isSearchActive: Bool {
        !store.sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func rebuildTreeCache() {
        guard let rootDirectoryURL = store.rootDirectoryURL, !store.isScanningDirectory else {
            cachedRootNode = nil
            cachedFilteredFileCount = 0
            return
        }
        
        let filtered = store.filteredImageFiles
        cachedFilteredFileCount = filtered.count
        guard !filtered.isEmpty else {
            cachedRootNode = nil
            return
        }
        
        cachedRootNode = FileTreeNode.makeRoot(rootDirectoryURL: rootDirectoryURL, fileURLs: filtered)
    }
}

struct GeneralSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        List {
            GeneralSidebarSection()
        }
    }
}

private struct FileSidebarRow: View {
    @ObservedObject private var store = AnnotationAppStore.shared
    
    let fileURL: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fileURL.lastPathComponent)
                .lineLimit(1)
            if store.loadWarningsByImageURL[fileURL] != nil {
                Text("Annotation warning")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
            let relativePath = store.relativePath(for: fileURL)
            if relativePath != fileURL.lastPathComponent {
                Text(relativePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct FileTreeNode: Identifiable, Hashable {
    enum Kind: Hashable {
        case directory
        case file
    }
    
    let id: String
    let name: String
    let url: URL
    let kind: Kind
    let children: [FileTreeNode]
    
    var isDirectory: Bool {
        kind == .directory
    }
    
    static func makeRoot(rootDirectoryURL: URL, fileURLs: [URL]) -> FileTreeNode {
        FileTreeNode(
            id: rootDirectoryURL.path,
            name: rootDirectoryURL.lastPathComponent,
            url: rootDirectoryURL,
            kind: .directory,
            children: makeChildren(parentDirectoryURL: rootDirectoryURL, fileURLs: fileURLs)
        )
    }
    
    private static func makeChildren(parentDirectoryURL: URL, fileURLs: [URL]) -> [FileTreeNode] {
        var directFiles: [URL] = []
        var groupedByFirstDirectory: [String: [URL]] = [:]
        
        for fileURL in fileURLs {
            let remainingComponents = pathComponents(relativeFrom: parentDirectoryURL, to: fileURL)
            guard let first = remainingComponents.first else { continue }
            if remainingComponents.count == 1 {
                directFiles.append(fileURL)
            } else {
                groupedByFirstDirectory[first, default: []].append(fileURL)
            }
        }
        
        let directoryNodes = groupedByFirstDirectory.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { directoryName in
                let directoryURL = parentDirectoryURL.appendingPathComponent(directoryName, isDirectory: true)
                return FileTreeNode(
                    id: directoryURL.path,
                    name: directoryName,
                    url: directoryURL,
                    kind: .directory,
                    children: makeChildren(
                        parentDirectoryURL: directoryURL,
                        fileURLs: groupedByFirstDirectory[directoryName] ?? []
                    )
                )
            }
        
        let fileNodes = directFiles
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { fileURL in
                FileTreeNode(
                    id: fileURL.path,
                    name: fileURL.lastPathComponent,
                    url: fileURL,
                    kind: .file,
                    children: []
                )
            }
        
        return directoryNodes + fileNodes
    }
    
    private static func pathComponents(relativeFrom parentDirectoryURL: URL, to fileURL: URL) -> [String] {
        let parentComponents = parentDirectoryURL.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        guard fileComponents.count >= parentComponents.count else { return [] }
        return Array(fileComponents.dropFirst(parentComponents.count))
    }
}

private struct FileTreeNodeRow: View {
    @ObservedObject private var store = AnnotationAppStore.shared
    
    let node: FileTreeNode
    @Binding var expandedDirectoryIDs: Set<String>
    let isSearchActive: Bool
    
    var body: some View {
        Group {
            if node.isDirectory {
                DisclosureGroup(isExpanded: expansionBinding) {
                    if node.children.isEmpty {
                        Text("No images")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(node.children) { child in
                            FileTreeNodeRow(
                                node: child,
                                expandedDirectoryIDs: $expandedDirectoryIDs,
                                isSearchActive: isSearchActive
                            )
                        }
                    }
                } label: {
                    Label(node.name, systemImage: "folder")
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                    FileSidebarRow(fileURL: node.url)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    store.selectImage(url: node.url)
                }
                .tag(Optional(node.url))
            }
        }
    }
    
    private var expansionBinding: Binding<Bool> {
        Binding(
            get: {
                if isSearchActive {
                    return true
                }
                return expandedDirectoryIDs.contains(node.id)
            },
            set: { isExpanded in
                guard !isSearchActive else { return }
                if isExpanded {
                    expandedDirectoryIDs.insert(node.id)
                } else {
                    expandedDirectoryIDs.remove(node.id)
                }
            }
        )
    }
}
