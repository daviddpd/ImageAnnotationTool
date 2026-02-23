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

@MainActor
final class AnnotationAppStore: ObservableObject {
    static let shared = AnnotationAppStore()
    
    @Published private(set) var rootDirectoryURL: URL?
    @Published private(set) var imageFiles: [URL] = []
    @Published private(set) var selectedImageURL: URL?
    @Published private(set) var documentsByImageURL: [URL: ImageAnnotationDocument] = [:]
    @Published private(set) var dirtyImageURLs: Set<URL> = []
    @Published var sidebarSearchText: String = ""
    @Published var lastErrorMessage: String?
    @Published private(set) var statusMessage: String?
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    var hasRootDirectory: Bool {
        rootDirectoryURL != nil
    }
    
    var hasImages: Bool {
        !imageFiles.isEmpty
    }
    
    var currentImageIndex: Int? {
        guard let selectedImageURL else { return nil }
        return imageFiles.firstIndex(of: selectedImageURL)
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
    
    var unsavedImageFiles: [URL] {
        imageFiles.filter { dirtyImageURLs.contains($0) }
    }
    
    var hasUnsavedChanges: Bool {
        !dirtyImageURLs.isEmpty
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
        do {
            let files = try Self.scanImageFiles(in: url)
            rootDirectoryURL = url
            imageFiles = files
            selectedImageURL = nil
            documentsByImageURL.removeAll()
            dirtyImageURLs.removeAll()
            sidebarSearchText = ""
            lastErrorMessage = nil
            statusMessage = "Loaded \(files.count) image\(files.count == 1 ? "" : "s")"
            
            if let first = files.first {
                selectImage(url: first)
            }
        } catch {
            lastErrorMessage = "Failed to open directory: \(error.localizedDescription)"
        }
    }
    
    func selectImage(url: URL?) {
        guard let url else {
            selectedImageURL = nil
            return
        }
        
        guard imageFiles.contains(url) else {
            return
        }
        
        selectedImageURL = url
        ensureDocumentLoaded(for: url)
    }
    
    func goToPreviousImage() {
        guard let currentImageIndex, currentImageIndex > 0 else { return }
        selectImage(url: imageFiles[currentImageIndex - 1])
    }
    
    func goToNextImage() {
        guard let currentImageIndex, currentImageIndex < imageFiles.count - 1 else { return }
        selectImage(url: imageFiles[currentImageIndex + 1])
    }
    
    @discardableResult
    func saveCurrentAnnotations() -> Bool {
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
    
    func updateObjectsForCurrentImage(_ objects: [AnnotationBoundingBox]) {
        guard let selectedImageURL, var document = documentsByImageURL[selectedImageURL] else { return }
        document.objects = objects
        documentsByImageURL[selectedImageURL] = document
        markDirty(true, for: selectedImageURL)
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
        if let index = imageFiles.firstIndex(of: url) {
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
    
    private func markDirty(_ isDirty: Bool, for imageURL: URL) {
        guard var document = documentsByImageURL[imageURL] else { return }
        document.isDirty = isDirty
        documentsByImageURL[imageURL] = document
        if isDirty {
            dirtyImageURLs.insert(imageURL)
        } else {
            dirtyImageURLs.remove(imageURL)
        }
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
        } catch {
            lastErrorMessage = "Failed to load annotations for \(imageURL.lastPathComponent): \(error.localizedDescription)"
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
            } catch {
                lastErrorMessage = "Failed to load image metadata for \(imageURL.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }
    
    private static func scanImageFiles(in root: URL) throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw AnnotationStoreError.directoryEnumerationFailed(root.path)
        }
        
        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let ext = fileURL.pathExtension.lowercased()
            if ["jpg", "jpeg", "png"].contains(ext) {
                results.append(fileURL)
            }
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
