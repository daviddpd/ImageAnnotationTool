import AppKit
import Foundation
import ImageIO
import SwiftUI

struct AnnotationBoundingBox: Identifiable, Hashable {
    let id: UUID
    var label: String
    var xMin: Double
    var yMin: Double
    var xMax: Double
    var yMax: Double
    
    init(
        id: UUID = UUID(),
        label: String,
        xMin: Double,
        yMin: Double,
        xMax: Double,
        yMax: Double
    ) {
        self.id = id
        self.label = label
        self.xMin = xMin
        self.yMin = yMin
        self.xMax = xMax
        self.yMax = yMax
    }
}

struct AnnotationImageSize: Hashable {
    var width: Int
    var height: Int
    var depth: Int
}

struct ImageAnnotationDocument: Hashable {
    var imageURL: URL
    var filename: String
    var imageSize: AnnotationImageSize
    var objects: [AnnotationBoundingBox]
    var isDirty: Bool
    var loadedFromXML: Bool
    
    var xmlURL: URL {
        imageURL.deletingPathExtension().appendingPathExtension("xml")
    }
    
    var yoloURL: URL {
        imageURL.deletingPathExtension().appendingPathExtension("txt")
    }
}

struct SidebarFileTreeNode: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case directory
        case file
    }
    
    let id: String
    let name: String
    let url: URL
    let relativePath: String
    let searchKey: String
    let kind: Kind
    let children: [SidebarFileTreeNode]
    let descendantFileCount: Int
    
    var isDirectory: Bool {
        kind == .directory
    }
    
    func replacingChildren(_ children: [SidebarFileTreeNode]) -> SidebarFileTreeNode {
        SidebarFileTreeNode(
            id: id,
            name: name,
            url: url,
            relativePath: relativePath,
            searchKey: searchKey,
            kind: kind,
            children: children,
            descendantFileCount: children.reduce(0) { $0 + $1.descendantFileCount }
        )
    }
}

@MainActor
final class AnnotationAppStore: ObservableObject {
    static let shared = AnnotationAppStore()
    
    @Published private(set) var rootDirectoryURL: URL?
    @Published private(set) var imageFiles: [URL] = []
    @Published private(set) var selectedImageURL: URL?
    @Published private(set) var documentsByImageURL: [URL: ImageAnnotationDocument] = [:]
    @Published private(set) var dirtyImageURLs: Set<URL> = []
    @Published private(set) var unsavedImageFiles: [URL] = []
    @Published private(set) var loadWarningsByImageURL: [URL: String] = [:]
    @Published private(set) var displayedFileTreeRoot: SidebarFileTreeNode?
    @Published private(set) var fileTreeStructureVersion: UInt64 = 0
    @Published private(set) var fileTreeDecorationsVersion: UInt64 = 0
    @Published private(set) var isFilteringFiles = false
    @Published private(set) var isScanningDirectory = false
    @Published private(set) var scanProgressMessage: String?
    @Published var sidebarSearchText: String = "" {
        didSet {
            scheduleSidebarTreeFilter()
        }
    }
    @Published var lastErrorMessage: String?
    @Published private(set) var statusMessage: String?
    
    private let fileManager = FileManager.default
    private var scanTask: Task<Void, Never>?
    private var sidebarFilterTask: Task<Void, Never>?
    private var activeScanID = UUID()
    private var activeSidebarFilterID = UUID()
    private var lastSavedObjectsByImageURL: [URL: [AnnotationBoundingBox]] = [:]
    private var imageIndexByURL: [URL: Int] = [:]
    private var fullFileTreeRoot: SidebarFileTreeNode?
    
    private init() {}
    
    var hasRootDirectory: Bool {
        rootDirectoryURL != nil
    }
    
    var hasImages: Bool {
        !imageFiles.isEmpty
    }
    
    var currentImageIndex: Int? {
        guard let selectedImageURL else { return nil }
        return imageIndexByURL[selectedImageURL]
    }
    
    var canGoPrevious: Bool {
        guard let currentImageIndex else { return false }
        return currentImageIndex > 0
    }
    
    var canGoNext: Bool {
        guard let currentImageIndex else { return false }
        return currentImageIndex < imageFiles.count - 1
    }
    
    var currentDocument: ImageAnnotationDocument? {
        guard let selectedImageURL else { return nil }
        return documentsByImageURL[selectedImageURL]
    }
    
    var currentImageNSImage: NSImage? {
        guard let selectedImageURL else { return nil }
        return NSImage(contentsOf: selectedImageURL)
    }
    
    var filteredImageFiles: [URL] {
        let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return imageFiles }
        return imageFiles.filter { url in
            let relative = relativePath(for: url).localizedLowercase
            return relative.contains(query.localizedLowercase)
        }
    }
    
    var hasUnsavedChanges: Bool {
        !dirtyImageURLs.isEmpty
    }
    
    var canSaveCurrent: Bool {
        selectedImageURL != nil && !isScanningDirectory
    }
    
    var canSaveAllUnsaved: Bool {
        hasRootDirectory && !unsavedImageFiles.isEmpty && !isScanningDirectory
    }
    
    var currentImageWarningMessage: String? {
        guard let selectedImageURL else { return nil }
        return loadWarningsByImageURL[selectedImageURL]
    }
    
    var isSidebarSearchActive: Bool {
        !sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func openDirectoryPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Image Directory"
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        
        requestOpenDirectory(url)
    }
    
    func requestOpenDirectory(_ url: URL) {
        guard !dirtyImageURLs.isEmpty else {
            loadDirectory(url)
            return
        }
        
        let unsavedCount = dirtyImageURLs.count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "You have \(unsavedCount) unsaved annotation\(unsavedCount == 1 ? "" : "s")."
        alert.informativeText = "Opening a different directory will discard in-memory unsaved changes for the current session."
        alert.addButton(withTitle: "Save All and Open")
        alert.addButton(withTitle: "Discard and Open")
        alert.addButton(withTitle: "Cancel")
        
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if saveAllUnsavedAnnotations() {
                loadDirectory(url)
            }
        case .alertSecondButtonReturn:
            loadDirectory(url)
        default:
            break
        }
    }
    
    func loadDirectory(_ url: URL) {
        let scanID = UUID()
        activeScanID = scanID
        scanTask?.cancel()
        sidebarFilterTask?.cancel()
        
        rootDirectoryURL = url
        imageFiles = []
        imageIndexByURL.removeAll()
        selectedImageURL = nil
        documentsByImageURL.removeAll()
        dirtyImageURLs.removeAll()
        unsavedImageFiles = []
        loadWarningsByImageURL.removeAll()
        fullFileTreeRoot = nil
        displayedFileTreeRoot = nil
        fileTreeStructureVersion &+= 1
        fileTreeDecorationsVersion &+= 1
        isFilteringFiles = false
        lastSavedObjectsByImageURL.removeAll()
        sidebarSearchText = ""
        lastErrorMessage = nil
        isScanningDirectory = true
        scanProgressMessage = "Starting scan…"
        statusMessage = "Scanning \(url.lastPathComponent)…"
        
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let files = try await Self.scanImageFilesAsync(in: url) { progress in
                    await MainActor.run {
                        guard self.activeScanID == scanID else { return }
                        self.scanProgressMessage = progress.message
                        self.statusMessage = progress.message
                    }
                }
                
                await MainActor.run {
                    guard self.activeScanID == scanID else { return }
                    self.scanProgressMessage = "Building file tree…"
                    self.statusMessage = "Building file tree…"
                }
                let fileTreeRoot = try await Self.buildSidebarFileTreeAsync(rootDirectoryURL: url, fileURLs: files)
                
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeScanID == scanID else { return }
                    self.finishDirectoryLoad(url: url, files: files, fileTreeRoot: fileTreeRoot)
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard self.activeScanID == scanID else { return }
                    self.isScanningDirectory = false
                    self.scanProgressMessage = nil
                    self.statusMessage = "Directory scan cancelled"
                }
            } catch {
                await MainActor.run {
                    guard self.activeScanID == scanID else { return }
                    self.isScanningDirectory = false
                    self.scanProgressMessage = nil
                    self.lastErrorMessage = "Failed to open directory: \(error.localizedDescription)"
                    self.statusMessage = "Directory scan failed"
                }
            }
        }
    }
    
    func selectImage(url: URL?) {
        guard !isScanningDirectory else { return }
        guard let url else {
            selectedImageURL = nil
            return
        }
        
        guard imageIndexByURL[url] != nil else {
            return
        }
        
        selectedImageURL = url
        ensureDocumentLoaded(for: url)
    }
    
    func goToPreviousImage() {
        guard !isScanningDirectory else { return }
        guard let currentImageIndex, currentImageIndex > 0 else { return }
        selectImage(url: imageFiles[currentImageIndex - 1])
    }
    
    func goToNextImage() {
        guard !isScanningDirectory else { return }
        guard let currentImageIndex, currentImageIndex < imageFiles.count - 1 else { return }
        selectImage(url: imageFiles[currentImageIndex + 1])
    }
    
    @discardableResult
    func saveCurrentAnnotations() -> Bool {
        guard !isScanningDirectory else { return false }
        guard let selectedImageURL else { return false }
        return saveAnnotations(for: selectedImageURL)
    }
    
    func saveCurrentAndAdvance() {
        if saveCurrentAnnotations() {
            goToNextImage()
        }
    }
    
    @discardableResult
    func saveAllUnsavedAnnotations() -> Bool {
        guard !isScanningDirectory else { return false }
        guard let _ = rootDirectoryURL else { return false }
        let urlsToSave = unsavedImageFiles
        guard !urlsToSave.isEmpty else {
            statusMessage = "No unsaved annotations"
            lastErrorMessage = nil
            return true
        }
        
        var failed: [String] = []
        for url in urlsToSave {
            if !saveAnnotations(for: url) {
                failed.append(url.lastPathComponent)
            }
        }
        
        if failed.isEmpty {
            statusMessage = "Saved \(urlsToSave.count) unsaved annotation\(urlsToSave.count == 1 ? "" : "s")"
            lastErrorMessage = nil
            return true
        } else {
            let summary = failed.prefix(3).joined(separator: ", ")
            let suffix = failed.count > 3 ? " (+\(failed.count - 3) more)" : ""
            lastErrorMessage = "Failed to save \(failed.count) file\(failed.count == 1 ? "" : "s"): \(summary)\(suffix)"
            statusMessage = "Save All completed with errors"
            return false
        }
    }
    
    func terminationReplyForUnsavedChanges() -> NSApplication.TerminateReply {
        if isScanningDirectory {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "A directory scan is in progress."
            alert.informativeText = "Cancel the scan and quit, or continue scanning."
            alert.addButton(withTitle: "Cancel Scan and Quit")
            alert.addButton(withTitle: "Continue Scanning")
            if alert.runModal() == .alertFirstButtonReturn {
                scanTask?.cancel()
                return .terminateNow
            }
            return .terminateCancel
        }
        
        guard !dirtyImageURLs.isEmpty else {
            return .terminateNow
        }
        
        let unsavedCount = dirtyImageURLs.count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit with \(unsavedCount) unsaved annotation\(unsavedCount == 1 ? "" : "s")?"
        alert.informativeText = "Unsaved in-memory annotation changes will be lost if you quit now."
        alert.addButton(withTitle: "Save All and Quit")
        alert.addButton(withTitle: "Discard and Quit")
        alert.addButton(withTitle: "Cancel")
        
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveAllUnsavedAnnotations() ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
    
    func updateObjectsForCurrentImage(
        _ objects: [AnnotationBoundingBox],
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Bounding Boxes"
    ) {
        guard let selectedImageURL else { return }
        updateObjects(for: selectedImageURL, objects: objects, undoManager: undoManager, actionName: actionName)
    }
    
    func relativePath(for url: URL) -> String {
        guard let rootDirectoryURL else { return url.lastPathComponent }
        let rootPath = rootDirectoryURL.path
        let urlPath = url.path
        if urlPath == rootPath {
            return url.lastPathComponent
        }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if urlPath.hasPrefix(prefix) {
            return String(urlPath.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }
    
    func metadataSummary(for url: URL) -> String {
        let indexText: String
        if let index = imageIndexByURL[url] {
            indexText = "\(index + 1)/\(imageFiles.count)"
        } else {
            indexText = "-/-"
        }
        
        let dirtyMark = dirtyImageURLs.contains(url) ? " • Unsaved" : ""
        if let document = documentsByImageURL[url] {
            let size = document.imageSize
            return "\(indexText) • \(size.width)x\(size.height) • \(document.objects.count) box\(document.objects.count == 1 ? "" : "es")\(dirtyMark)"
        }
        return "\(indexText)\(dirtyMark)"
    }
    
    func createEmptyAnnotationsForCurrentIfNeeded() {
        guard let selectedImageURL else { return }
        ensureDocumentLoaded(for: selectedImageURL)
        // TODO(Stage 002): interactive canvas edits will call updateObjectsForCurrentImage(_:)
    }
    
    @discardableResult
    func updateObjects(
        for imageURL: URL,
        objects: [AnnotationBoundingBox],
        undoManager: UndoManager? = nil,
        actionName: String = "Edit Bounding Boxes"
    ) -> Bool {
        guard var document = documentsByImageURL[imageURL] else { return false }
        let previousObjects = document.objects
        guard previousObjects != objects else { return false }
        
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { target in
                _ = target.updateObjects(
                    for: imageURL,
                    objects: previousObjects,
                    undoManager: undoManager,
                    actionName: actionName
                )
            }
            undoManager.setActionName(actionName)
        }
        
        document.objects = objects
        documentsByImageURL[imageURL] = document
        refreshDirtyState(for: imageURL)
        return true
    }
    
    private func markDirty(_ isDirty: Bool, for imageURL: URL) {
        guard var document = documentsByImageURL[imageURL] else { return }
        if document.isDirty != isDirty {
            document.isDirty = isDirty
            documentsByImageURL[imageURL] = document
        }
        
        let dirtySetChanged: Bool
        if isDirty {
            dirtySetChanged = dirtyImageURLs.insert(imageURL).inserted
        } else {
            dirtySetChanged = dirtyImageURLs.remove(imageURL) != nil
        }
        
        if dirtySetChanged {
            rebuildUnsavedImageFilesCache()
            bumpFileTreeDecorationsVersion()
        }
    }
    
    private func refreshDirtyState(for imageURL: URL) {
        guard let document = documentsByImageURL[imageURL] else { return }
        let baseline = lastSavedObjectsByImageURL[imageURL] ?? []
        markDirty(document.objects != baseline, for: imageURL)
    }
    
    @discardableResult
    private func saveAnnotations(for imageURL: URL) -> Bool {
        ensureDocumentLoaded(for: imageURL)
        guard let document = documentsByImageURL[imageURL] else {
            lastErrorMessage = "Save failed: missing in-memory document for \(imageURL.lastPathComponent)"
            return false
        }
        guard let rootDirectoryURL else {
            lastErrorMessage = "Save failed: no root directory selected"
            return false
        }
        
        do {
            let labels = Set(document.objects.map(\.label).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            let classes = try ClassesFileStore.loadAndMergeClasses(rootDirectory: rootDirectoryURL, adding: labels)
            try PascalVOCStore.write(document: document)
            try YOLOStore.write(document: document, classes: classes)
            lastSavedObjectsByImageURL[imageURL] = document.objects
            markDirty(false, for: imageURL)
            statusMessage = "Saved \(document.filename)"
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = "Save failed for \(document.filename): \(error.localizedDescription)"
            return false
        }
    }
    
    private func ensureDocumentLoaded(for imageURL: URL) {
        if documentsByImageURL[imageURL] != nil {
            return
        }
        
        do {
            let document = try PascalVOCStore.loadDocument(for: imageURL)
            documentsByImageURL[imageURL] = document
            lastSavedObjectsByImageURL[imageURL] = document.objects
            if loadWarningsByImageURL.removeValue(forKey: imageURL) != nil {
                bumpFileTreeDecorationsVersion()
            }
        } catch {
            let annotationError = "Failed to load annotations for \(imageURL.lastPathComponent): \(error.localizedDescription)"
            lastErrorMessage = annotationError
            do {
                let size = try ImageMetadataReader.readSize(for: imageURL)
                documentsByImageURL[imageURL] = ImageAnnotationDocument(
                    imageURL: imageURL,
                    filename: imageURL.lastPathComponent,
                    imageSize: size,
                    objects: [],
                    isDirty: false,
                    loadedFromXML: false
                )
                lastSavedObjectsByImageURL[imageURL] = []
                let warning = "Annotation XML could not be loaded. Using empty annotations. \(error.localizedDescription)"
                if loadWarningsByImageURL[imageURL] != warning {
                    loadWarningsByImageURL[imageURL] = warning
                    bumpFileTreeDecorationsVersion()
                }
            } catch {
                lastErrorMessage = "Failed to load image metadata for \(imageURL.lastPathComponent): \(error.localizedDescription)"
                let warning = "Image could not be read: \(error.localizedDescription)"
                if loadWarningsByImageURL[imageURL] != warning {
                    loadWarningsByImageURL[imageURL] = warning
                    bumpFileTreeDecorationsVersion()
                }
            }
        }
    }
    
    private func finishDirectoryLoad(url: URL, files: [URL], fileTreeRoot: SidebarFileTreeNode) {
        guard rootDirectoryURL == url else { return }
        isScanningDirectory = false
        scanProgressMessage = nil
        statusMessage = "Loaded \(files.count) image\(files.count == 1 ? "" : "s")"
        imageFiles = files
        imageIndexByURL = Dictionary(uniqueKeysWithValues: files.enumerated().map { ($0.element, $0.offset) })
        fullFileTreeRoot = fileTreeRoot
        isFilteringFiles = false
        applyDisplayedSidebarTree(fileTreeRoot)
        rebuildUnsavedImageFilesCache()
        
        if let first = files.first {
            selectImage(url: first)
        }
    }
    
    private func rebuildUnsavedImageFilesCache() {
        unsavedImageFiles = imageFiles.filter { dirtyImageURLs.contains($0) }
    }
    
    private func scheduleSidebarTreeFilter() {
        sidebarFilterTask?.cancel()
        
        let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fullFileTreeRoot else {
            isFilteringFiles = false
            if displayedFileTreeRoot != nil {
                applyDisplayedSidebarTree(nil)
            }
            return
        }
        
        guard !query.isEmpty else {
            isFilteringFiles = false
            applyDisplayedSidebarTree(fullFileTreeRoot)
            return
        }
        
        isFilteringFiles = true
        let filterID = UUID()
        activeSidebarFilterID = filterID
        
        sidebarFilterTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                return
            }
            
            let filtered = await Self.filterSidebarFileTreeAsync(root: fullFileTreeRoot, query: query)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                guard self.activeSidebarFilterID == filterID else { return }
                self.isFilteringFiles = false
                self.applyDisplayedSidebarTree(filtered)
            }
        }
    }
    
    private func applyDisplayedSidebarTree(_ root: SidebarFileTreeNode?) {
        displayedFileTreeRoot = root
        fileTreeStructureVersion &+= 1
    }
    
    private func bumpFileTreeDecorationsVersion() {
        fileTreeDecorationsVersion &+= 1
    }
    
    nonisolated private static func buildSidebarFileTreeAsync(
        rootDirectoryURL: URL,
        fileURLs: [URL]
    ) async throws -> SidebarFileTreeNode {
        try await Task.detached(priority: .userInitiated) {
            try buildSidebarFileTree(rootDirectoryURL: rootDirectoryURL, fileURLs: fileURLs)
        }.value
    }
    
    nonisolated private static func filterSidebarFileTreeAsync(
        root: SidebarFileTreeNode,
        query: String
    ) async -> SidebarFileTreeNode? {
        await Task.detached(priority: .userInitiated) {
            filterSidebarFileTree(root: root, query: query)
        }.value
    }
    
    nonisolated private static func buildSidebarFileTree(
        rootDirectoryURL: URL,
        fileURLs: [URL]
    ) throws -> SidebarFileTreeNode {
        final class MutableDirectoryNode {
            let name: String
            let url: URL
            let relativePath: String
            var directories: [String: MutableDirectoryNode] = [:]
            var files: [URL] = []
            
            init(name: String, url: URL, relativePath: String) {
                self.name = name
                self.url = url
                self.relativePath = relativePath
            }
        }
        
        let rootNode = MutableDirectoryNode(
            name: rootDirectoryURL.lastPathComponent,
            url: rootDirectoryURL,
            relativePath: ""
        )
        let rootPath = rootDirectoryURL.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        
        for (index, fileURL) in fileURLs.enumerated() {
            if index % 500 == 0 {
                try Task.checkCancellation()
            }
            let standardizedPath = fileURL.standardizedFileURL.path
            guard standardizedPath.hasPrefix(prefix) else { continue }
            let relativePath = String(standardizedPath.dropFirst(prefix.count))
            let components = relativePath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let fileName = components.last else { continue }
            
            var current = rootNode
            if components.count > 1 {
                var currentRelativePath = ""
                for directoryName in components.dropLast() {
                    currentRelativePath = currentRelativePath.isEmpty
                        ? directoryName
                        : currentRelativePath + "/" + directoryName
                    if let existing = current.directories[directoryName] {
                        current = existing
                    } else {
                        let directoryURL = rootDirectoryURL.appendingPathComponent(currentRelativePath, isDirectory: true)
                        let created = MutableDirectoryNode(
                            name: directoryName,
                            url: directoryURL,
                            relativePath: currentRelativePath
                        )
                        current.directories[directoryName] = created
                        current = created
                    }
                }
            }
            
            if current.relativePath.isEmpty {
                current.files.append(fileURL)
            } else {
                // Preserve file sort correctness later via localized sort in freeze.
                current.files.append(fileURL.deletingLastPathComponent().appendingPathComponent(fileName))
            }
        }
        
        func freeze(_ directory: MutableDirectoryNode, isRoot: Bool) throws -> SidebarFileTreeNode {
            try Task.checkCancellation()
            
            let directoryChildren = try directory.directories.values
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { try freeze($0, isRoot: false) }
            
            let fileChildren = directory.files
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { fileURL in
                    let relativePath = directory.relativePath.isEmpty
                        ? fileURL.lastPathComponent
                        : directory.relativePath + "/" + fileURL.lastPathComponent
                    return SidebarFileTreeNode(
                        id: fileURL.path,
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        relativePath: relativePath,
                        searchKey: relativePath.localizedLowercase,
                        kind: .file,
                        children: [],
                        descendantFileCount: 1
                    )
                }
            
            let children = directoryChildren + fileChildren
            let relativePath = isRoot ? "" : directory.relativePath
            let searchKey = (isRoot ? directory.name : (relativePath.isEmpty ? directory.name : relativePath)).localizedLowercase
            return SidebarFileTreeNode(
                id: directory.url.path,
                name: directory.name,
                url: directory.url,
                relativePath: relativePath,
                searchKey: searchKey,
                kind: .directory,
                children: children,
                descendantFileCount: children.reduce(0) { $0 + $1.descendantFileCount }
            )
        }
        
        return try freeze(rootNode, isRoot: true)
    }
    
    nonisolated private static func filterSidebarFileTree(
        root: SidebarFileTreeNode,
        query: String
    ) -> SidebarFileTreeNode? {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !normalizedQuery.isEmpty else { return root }
        
        func filter(_ node: SidebarFileTreeNode, isRoot: Bool) -> SidebarFileTreeNode? {
            if !node.isDirectory {
                return node.searchKey.contains(normalizedQuery) ? node : nil
            }
            
            let filteredChildren = node.children.compactMap { child in
                filter(child, isRoot: false)
            }
            
            if isRoot {
                return filteredChildren.isEmpty ? nil : node.replacingChildren(filteredChildren)
            }
            
            if !filteredChildren.isEmpty {
                return node.replacingChildren(filteredChildren)
            }
            
            return node.searchKey.contains(normalizedQuery) ? node.replacingChildren([]) : nil
        }
        
        return filter(root, isRoot: true)
    }
    
    private struct DirectoryScanProgress: Sendable {
        let filesVisited: Int
        let imagesMatched: Int
        
        var message: String {
            "Scanning… \(filesVisited) files, \(imagesMatched) image\(imagesMatched == 1 ? "" : "s")"
        }
    }
    
    nonisolated private static func scanImageFilesAsync(
        in root: URL,
        progress: @escaping @Sendable (DirectoryScanProgress) async -> Void
    ) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try await scanImageFiles(in: root) { update in
                await progress(update)
            }
        }.value
    }
    
    nonisolated private static func scanImageFiles(
        in root: URL,
        progress: (@Sendable (DirectoryScanProgress) async -> Void)? = nil
    ) async throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw AnnotationStoreError.directoryEnumerationFailed(root.path)
        }
        
        var results: [URL] = []
        var filesVisited = 0
        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            filesVisited += 1
            let ext = fileURL.pathExtension.lowercased()
            if ["jpg", "jpeg", "png"].contains(ext) {
                results.append(fileURL)
            }
            if filesVisited == 1 || filesVisited % 250 == 0 {
                if let progress {
                    await progress(.init(filesVisited: filesVisited, imagesMatched: results.count))
                }
            }
        }
        
        if let progress {
            await progress(.init(filesVisited: filesVisited, imagesMatched: results.count))
        }
        
        return results.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }
}

enum AnnotationStoreError: LocalizedError {
    case directoryEnumerationFailed(String)
    case invalidImageMetadata(String)
    case invalidXML(String)
    case missingRootElement
    case missingImageSelection
    
    var errorDescription: String? {
        switch self {
        case .directoryEnumerationFailed(let path):
            return "Could not enumerate directory: \(path)"
        case .invalidImageMetadata(let filename):
            return "Invalid image metadata for \(filename)"
        case .invalidXML(let message):
            return "Invalid XML: \(message)"
        case .missingRootElement:
            return "Missing XML root element"
        case .missingImageSelection:
            return "No image selected"
        }
    }
}

enum ImageMetadataReader {
    static func readSize(for imageURL: URL) throws -> AnnotationImageSize {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            throw AnnotationStoreError.invalidImageMetadata(imageURL.lastPathComponent)
        }
        
        let depth = (props[kCGImagePropertyDepth] as? Int) ?? 3
        return AnnotationImageSize(width: width, height: height, depth: max(depth, 1))
    }
}

enum PascalVOCStore {
    static func loadDocument(for imageURL: URL) throws -> ImageAnnotationDocument {
        let xmlURL = imageURL.deletingPathExtension().appendingPathExtension("xml")
        let fallbackImageSize = try ImageMetadataReader.readSize(for: imageURL)
        
        guard FileManager.default.fileExists(atPath: xmlURL.path) else {
            return ImageAnnotationDocument(
                imageURL: imageURL,
                filename: imageURL.lastPathComponent,
                imageSize: fallbackImageSize,
                objects: [],
                isDirty: false,
                loadedFromXML: false
            )
        }
        
        let xmlDocument = try XMLDocument(contentsOf: xmlURL, options: [])
        guard let root = xmlDocument.rootElement() else {
            throw AnnotationStoreError.missingRootElement
        }
        
        let filename = root.stringValue(forChildNamed: "filename") ?? imageURL.lastPathComponent
        let sizeElement = root.firstChild(named: "size")
        let width = sizeElement?.intValue(forChildNamed: "width") ?? fallbackImageSize.width
        let height = sizeElement?.intValue(forChildNamed: "height") ?? fallbackImageSize.height
        let depth = sizeElement?.intValue(forChildNamed: "depth") ?? fallbackImageSize.depth
        
        let objects: [AnnotationBoundingBox] = root.elements(forName: "object").compactMap { objectElement in
            guard let label = objectElement.stringValue(forChildNamed: "name")?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty,
                  let bndBox = objectElement.firstChild(named: "bndbox"),
                  let xMin = bndBox.doubleValue(forChildNamed: "xmin"),
                  let yMin = bndBox.doubleValue(forChildNamed: "ymin"),
                  let xMax = bndBox.doubleValue(forChildNamed: "xmax"),
                  let yMax = bndBox.doubleValue(forChildNamed: "ymax") else {
                return nil
            }
            return AnnotationBoundingBox(label: label, xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax)
        }
        
        return ImageAnnotationDocument(
            imageURL: imageURL,
            filename: filename,
            imageSize: AnnotationImageSize(width: max(width, 1), height: max(height, 1), depth: max(depth, 1)),
            objects: objects,
            isDirty: false,
            loadedFromXML: true
        )
    }
    
    static func write(document: ImageAnnotationDocument) throws {
        let root = XMLElement(name: "annotation")
        root.addChild(XMLElement(name: "filename", stringValue: document.filename))
        
        let sizeElement = XMLElement(name: "size")
        sizeElement.addChild(XMLElement(name: "width", stringValue: "\(document.imageSize.width)"))
        sizeElement.addChild(XMLElement(name: "height", stringValue: "\(document.imageSize.height)"))
        sizeElement.addChild(XMLElement(name: "depth", stringValue: "\(document.imageSize.depth)"))
        root.addChild(sizeElement)
        
        for object in document.objects {
            let objectElement = XMLElement(name: "object")
            objectElement.addChild(XMLElement(name: "name", stringValue: object.label))
            let boxElement = XMLElement(name: "bndbox")
            boxElement.addChild(XMLElement(name: "xmin", stringValue: "\(Int(object.xMin.rounded()))"))
            boxElement.addChild(XMLElement(name: "ymin", stringValue: "\(Int(object.yMin.rounded()))"))
            boxElement.addChild(XMLElement(name: "xmax", stringValue: "\(Int(object.xMax.rounded()))"))
            boxElement.addChild(XMLElement(name: "ymax", stringValue: "\(Int(object.yMax.rounded()))"))
            objectElement.addChild(boxElement)
            root.addChild(objectElement)
        }
        
        let xmlDocument = XMLDocument(rootElement: root)
        xmlDocument.characterEncoding = "UTF-8"
        xmlDocument.version = "1.0"
        let data = xmlDocument.xmlData(options: [.nodePrettyPrint])
        try AtomicFileWriter.write(data: data, to: document.xmlURL)
    }
}

enum ClassesFileStore {
    static func loadAndMergeClasses(rootDirectory: URL, adding labels: Set<String>) throws -> [String] {
        let classesURL = rootDirectory.appendingPathComponent("classes.txt")
        var classes = try readClasses(from: classesURL)
        
        for label in labels.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            if !classes.contains(label) {
                classes.append(label)
            }
        }
        
        try writeClasses(classes, to: classesURL)
        return classes
    }
    
    private static func readClasses(from url: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private static func writeClasses(_ classes: [String], to url: URL) throws {
        let body = classes.joined(separator: "\n") + (classes.isEmpty ? "" : "\n")
        try AtomicFileWriter.write(string: body, to: url)
    }
}

enum YOLOStore {
    static func write(document: ImageAnnotationDocument, classes: [String]) throws {
        let classIndexByName = Dictionary(uniqueKeysWithValues: classes.enumerated().map { ($0.element, $0.offset) })
        let lines = try makeLines(document: document, classIndexByName: classIndexByName)
        
        // Stage 001 behavior choice: write an empty .txt file when there are zero objects.
        let body = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try AtomicFileWriter.write(string: body, to: document.yoloURL)
    }
    
    private static func makeLines(
        document: ImageAnnotationDocument,
        classIndexByName: [String: Int]
    ) throws -> [String] {
        let width = Double(document.imageSize.width)
        let height = Double(document.imageSize.height)
        guard width > 0, height > 0 else {
            throw AnnotationStoreError.invalidImageMetadata(document.filename)
        }
        
        return try document.objects.map { box in
            guard let classID = classIndexByName[box.label] else {
                throw AnnotationStoreError.invalidXML("Missing class mapping for \(box.label)")
            }
            
            let xMin = clamp(box.xMin, min: 0, max: width)
            let xMax = clamp(box.xMax, min: 0, max: width)
            let yMin = clamp(box.yMin, min: 0, max: height)
            let yMax = clamp(box.yMax, min: 0, max: height)
            
            let boxWidth = max(0, xMax - xMin)
            let boxHeight = max(0, yMax - yMin)
            let xCenter = xMin + (boxWidth / 2)
            let yCenter = yMin + (boxHeight / 2)
            
            return [
                "\(classID)",
                formatFloat(xCenter / width),
                formatFloat(yCenter / height),
                formatFloat(boxWidth / width),
                formatFloat(boxHeight / height)
            ].joined(separator: " ")
        }
    }
    
    private static func formatFloat(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
    
    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}

enum AtomicFileWriter {
    static func write(string: String, to url: URL) throws {
        try write(data: Data(string.utf8), to: url)
    }
    
    static func write(data: Data, to url: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = url.deletingLastPathComponent()
        let tempURL = directoryURL.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        
        do {
            try data.write(to: tempURL, options: [])
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(
                    url,
                    withItemAt: tempURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }
}

private extension XMLElement {
    func firstChild(named name: String) -> XMLElement? {
        elements(forName: name).first
    }
    
    func stringValue(forChildNamed name: String) -> String? {
        firstChild(named: name)?.stringValue
    }
    
    func intValue(forChildNamed name: String) -> Int? {
        guard let text = stringValue(forChildNamed: name)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Int(text)
    }
    
    func doubleValue(forChildNamed name: String) -> Double? {
        guard let text = stringValue(forChildNamed: name)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Double(text)
    }
}
