import AppKit
import SwiftUI

struct AnnotationWorkspacePane: View {
    @ObservedObject private var store = AnnotationAppStore.shared
    @Environment(\.undoManager) private var undoManager
    @AppStorage(ImageAnnotationToolSettingsKeys.bottomInspectorFontScale) private var bottomInspectorFontScale: Double = 1.5
    
    @State private var selectedBoxID: UUID?
    @State private var labelEditorText = ""
    @State private var isLabelEditorFocused = false
    @State private var canvasFocusRequestID: UInt64 = 0
    @State private var workspaceWindow: NSWindow?
    
    var body: some View {
        Pane {
            content
                .padding()
        }
        .background(WindowReflection(window: $workspaceWindow))
        .background(
            WorkspaceWindowKeyMonitor(
                window: workspaceWindow,
                isEnabled: store.currentDocument != nil && store.currentImageNSImage != nil,
                hasSelectedBox: selectedBoxID != nil,
                onEnter: { handlePrimaryKeyboardAction() },
                onDelete: { deleteSelectedBox() }
            )
        )
        .navigationTitle(store.selectedImageURL?.lastPathComponent ?? "Image Annotation Tool")
        .navigationSubtitle(store.selectedImageURL.map { store.metadataSummary(for: $0) } ?? "Open a directory to begin")
        .onAppear {
            syncSelectionWithCurrentDocument(resetSelection: true)
        }
        .onChange(of: store.selectedImageURL) { _ in
            syncSelectionWithCurrentDocument(resetSelection: true)
        }
        .onChange(of: store.currentDocument?.objects) { _ in
            syncSelectionWithCurrentDocument(resetSelection: false)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if !store.hasRootDirectory {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open a directory to begin annotating.")
                    .font(.title3)
                Text("Supported image files: .jpg, .jpeg, .png (recursive scan)")
                    .foregroundColor(.secondary)
                Button {
                    store.openDirectoryPanel()
                } label: {
                    Label("Open Directory…", systemImage: "folder")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if store.isScanningDirectory {
            VStack(spacing: 12) {
                ProgressView()
                Text(store.scanProgressMessage ?? "Scanning directory…")
                    .foregroundColor(.secondary)
                if let root = store.rootDirectoryURL {
                    Text(root.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.imageFiles.isEmpty {
            VStack(spacing: 12) {
                Text("No supported images were found in the selected directory.")
                if let root = store.rootDirectoryURL {
                    Text(root.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let document = store.currentDocument, let image = store.currentImageNSImage {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.04))
                    
                    AnnotationCanvasView(
                        image: image,
                        imageSize: document.imageSize,
                        boxes: document.objects,
                        selectedBoxID: selectedBoxID,
                        defaultNewLabel: effectiveDefaultNewLabel,
                        focusRequestID: canvasFocusRequestID,
                        onBoxesChanged: { updatedBoxes in
                            store.updateObjectsForCurrentImage(
                                updatedBoxes,
                                undoManager: undoManager,
                                actionName: "Edit Bounding Boxes"
                            )
                        },
                        onSelectionChanged: { newSelection in
                            setSelectedBox(newSelection, focusLabelEditor: false)
                        },
                        onLabelEditRequested: { boxID in
                            setSelectedBox(boxID, focusLabelEditor: true)
                        },
                        onKeyboardCommand: { command in
                            handleCanvasKeyboardCommand(command)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    Text("Click-drag to create boxes. Drag inside to move. Drag corner handles to resize.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.windowBackgroundColor).opacity(0.85))
                        .cornerRadius(6)
                        .padding(8)
                }
                
                inspectorPanel(document: document)
            }
        } else if store.selectedImageURL != nil {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading image and annotations…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Select an image from the Files sidebar.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func inspectorPanel(document: ImageAnnotationDocument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            selectedBoxEditor(document: document)
            
            Divider()
            
            if !document.objects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(document.objects) { object in
                            Button {
                                setSelectedBox(object.id, focusLabelEditor: false)
                            } label: {
                                Text(object.label)
                                    .font(inspectorFont(12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((object.id == selectedBoxID ? Color.blue : Color.blue.opacity(0.25)).opacity(object.id == selectedBoxID ? 0.2 : 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(object.id == selectedBoxID ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("No boxes yet")
                    .font(inspectorFont(12))
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = store.lastErrorMessage {
                Text(errorMessage)
                    .font(inspectorFont(12))
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if let warningMessage = store.currentImageWarningMessage {
                Text(warningMessage)
                    .font(inspectorFont(12))
                    .foregroundColor(.orange)
                    .lineLimit(2)
            } else {
                Text(" ")
                    .font(inspectorFont(12))
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: inspectorPanelHeight, maxHeight: inspectorPanelHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func selectedBoxEditor(document: ImageAnnotationDocument) -> some View {
        if let selectedBox = selectedBox(in: document) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Selected box")
                        .font(inspectorFont(13, weight: .semibold))
                    Text(coordinatesSummary(for: selectedBox))
                        .font(inspectorFont(12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    SelectedBoxLabelTextField(
                        text: $labelEditorText,
                        isFocused: $isLabelEditorFocused,
                        font: inspectorNSFont(13),
                        onEnter: {
                            commitSelectedBoxLabel(endEditing: true, dismissSelection: true)
                        },
                        onTab: {
                            handleLabelEditorTab()
                        }
                    )
                    .frame(minHeight: 24)
                    
                    Button("Apply") {
                        commitSelectedBoxLabel(endEditing: true, dismissSelection: true)
                    }
                    .font(inspectorFont(13))
                    
                    Button(role: .destructive) {
                        deleteSelectedBox()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .font(inspectorFont(13))
                }
                
                Text("Click the filled label banner on a box to focus this field and rename it.")
                    .font(inspectorFont(12))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Click-drag on the image to draw a bounding box. Click a box or its label banner to select it.")
                .font(inspectorFont(12))
                .foregroundColor(.secondary)
        }
    }
    
    private var effectiveDefaultNewLabel: String {
        let trimmed = labelEditorText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let current = store.currentDocument,
           let selected = selectedBoxID,
           let box = current.objects.first(where: { $0.id == selected }) {
            let selectedLabel = box.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !selectedLabel.isEmpty {
                return selectedLabel
            }
        }
        return "object"
    }
    
    private func selectedBox(in document: ImageAnnotationDocument) -> AnnotationBoundingBox? {
        guard let selectedBoxID else { return nil }
        return document.objects.first(where: { $0.id == selectedBoxID })
    }
    
    private func setSelectedBox(_ id: UUID?, focusLabelEditor: Bool) {
        selectedBoxID = id
        if let document = store.currentDocument,
           let id,
           let box = document.objects.first(where: { $0.id == id }) {
            labelEditorText = box.label
            if focusLabelEditor {
                DispatchQueue.main.async {
                    isLabelEditorFocused = true
                }
            }
        } else {
            labelEditorText = ""
            isLabelEditorFocused = false
        }
    }
    
    private func syncSelectionWithCurrentDocument(resetSelection: Bool) {
        guard let document = store.currentDocument else {
            selectedBoxID = nil
            labelEditorText = ""
            isLabelEditorFocused = false
            return
        }
        
        if resetSelection {
            selectedBoxID = nil
            labelEditorText = ""
            isLabelEditorFocused = false
            return
        }
        
        guard let selectedBoxID else {
            return
        }
        
        if let selectedBox = document.objects.first(where: { $0.id == selectedBoxID }) {
            if !isLabelEditorFocused {
                labelEditorText = selectedBox.label
            }
        } else {
            self.selectedBoxID = nil
            if !isLabelEditorFocused {
                labelEditorText = ""
            }
        }
    }
    
    private func commitSelectedBoxLabel(endEditing: Bool = false, dismissSelection: Bool = false) {
        guard let document = store.currentDocument,
              let selectedBoxID,
              let index = document.objects.firstIndex(where: { $0.id == selectedBoxID }) else {
            return
        }
        
        let trimmed = labelEditorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            labelEditorText = document.objects[index].label
            finishSelectedBoxLabelEditing(endEditing: endEditing, dismissSelection: dismissSelection)
            return
        }
        
        guard document.objects[index].label != trimmed else {
            finishSelectedBoxLabelEditing(endEditing: endEditing, dismissSelection: dismissSelection)
            return
        }
        
        var updated = document.objects
        updated[index].label = trimmed
        store.updateObjectsForCurrentImage(
            updated,
            undoManager: undoManager,
            actionName: "Rename Bounding Box"
        )

        finishSelectedBoxLabelEditing(endEditing: endEditing, dismissSelection: dismissSelection)
    }
    
    private func deleteSelectedBox() {
        guard let document = store.currentDocument, let selectedBoxID else {
            return
        }
        let updated = document.objects.filter { $0.id != selectedBoxID }
        store.updateObjectsForCurrentImage(
            updated,
            undoManager: undoManager,
            actionName: "Delete Bounding Box"
        )
        setSelectedBox(nil, focusLabelEditor: false)
    }
    
    private func coordinatesSummary(for box: AnnotationBoundingBox) -> String {
        "(\(Int(box.xMin.rounded())), \(Int(box.yMin.rounded()))) → (\(Int(box.xMax.rounded())), \(Int(box.yMax.rounded())))"
    }
    
    private func finishSelectedBoxLabelEditing(endEditing: Bool, dismissSelection: Bool) {
        if endEditing {
            DispatchQueue.main.async {
                isLabelEditorFocused = false
            }
        }
        if dismissSelection {
            DispatchQueue.main.async {
                setSelectedBox(nil, focusLabelEditor: false)
                requestCanvasFocus()
            }
        }
    }
    
    private func handleCanvasKeyboardCommand(_ command: AnnotationCanvasView.KeyboardCommand) {
        switch command {
        case .activateFirstObjectEditor:
            focusFirstObjectLabelEditor()
        case .focusNextObjectEditor:
            focusNextObjectForKeyboardEditing()
        case .deleteSelectedObject:
            deleteSelectedBox()
        }
    }
    
    private func handlePrimaryKeyboardAction() {
        guard let document = store.currentDocument, !document.objects.isEmpty else { return }
        if let selectedBoxID,
           document.objects.contains(where: { $0.id == selectedBoxID }) {
            setSelectedBox(selectedBoxID, focusLabelEditor: true)
        } else {
            focusFirstObjectLabelEditor()
        }
    }
    
    private func focusFirstObjectLabelEditor() {
        guard let firstID = store.currentDocument?.objects.first?.id else { return }
        setSelectedBox(firstID, focusLabelEditor: true)
    }
    
    private func focusNextObjectForKeyboardEditing() {
        guard let document = store.currentDocument,
              document.objects.count > 1,
              let selectedBoxID,
              let currentIndex = document.objects.firstIndex(where: { $0.id == selectedBoxID }) else {
            return
        }
        
        let nextIndex = (currentIndex + 1) % document.objects.count
        setSelectedBox(document.objects[nextIndex].id, focusLabelEditor: true)
    }
    
    private func handleLabelEditorTab() {
        guard let document = store.currentDocument,
              document.objects.count > 1,
              selectedBoxID != nil else {
            // Intentionally no-op: user requested Tab does nothing with <= 1 objects.
            return
        }
        
        commitSelectedBoxLabel(endEditing: false, dismissSelection: false)
        focusNextObjectForKeyboardEditing()
    }
    
    private func requestCanvasFocus() {
        canvasFocusRequestID &+= 1
    }
    
    private var clampedBottomInspectorFontScale: CGFloat {
        CGFloat(min(max(bottomInspectorFontScale, 0.8), 3.0))
    }
    
    private var inspectorPanelHeight: CGFloat {
        // Keep the panel fixed-height (no jumpy resizing) while giving larger fonts enough room.
        170 + ((clampedBottomInspectorFontScale - 1.0) * 100)
    }
    
    private func inspectorFont(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: baseSize * clampedBottomInspectorFontScale, weight: weight)
    }
    
    private func inspectorNSFont(_ baseSize: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .systemFont(ofSize: baseSize * clampedBottomInspectorFontScale, weight: weight)
    }
}

struct AnnotationWorkspacePane_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationWorkspacePane()
            .frame(width: 700, height: 500)
    }
}

private struct SelectedBoxLabelTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    
    let font: NSFont
    let onEnter: () -> Void
    let onTab: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isBordered = true
        textField.isBezeled = true
        textField.isEditable = true
        textField.isSelectable = true
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.placeholderString = "Object label"
        textField.font = font
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.font != font {
            nsView.font = font
        }
        
        if isFocused {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                if nsView.currentEditor() == nil {
                    window.makeFirstResponder(nsView)
                }
            }
        } else if nsView.currentEditor() != nil {
            DispatchQueue.main.async {
                guard let window = nsView.window, nsView.currentEditor() != nil else { return }
                window.makeFirstResponder(nil)
            }
        }
    }
    
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SelectedBoxLabelTextField
        
        init(parent: SelectedBoxLabelTextField) {
            self.parent = parent
        }
        
        func controlTextDidBeginEditing(_ notification: Notification) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }
        
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if parent.text != textField.stringValue {
                parent.text = textField.stringValue
            }
        }
        
        func controlTextDidEndEditing(_ notification: Notification) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard let textField = control as? NSTextField else { return false }
            
            if commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                parent.text = textField.stringValue
                parent.onEnter()
                return true
            }
            
            if commandSelector == #selector(NSResponder.insertTab(_:))
                || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                parent.text = textField.stringValue
                parent.onTab()
                return true
            }
            
            return false
        }
    }
}

private struct WorkspaceWindowKeyMonitor: NSViewRepresentable {
    let window: NSWindow?
    let isEnabled: Bool
    let hasSelectedBox: Bool
    let onEnter: () -> Void
    let onDelete: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.update(
            monitoredWindow: window,
            isEnabled: isEnabled,
            hasSelectedBox: hasSelectedBox,
            onEnter: onEnter,
            onDelete: onDelete
        )
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            monitoredWindow: window ?? nsView.window,
            isEnabled: isEnabled,
            hasSelectedBox: hasSelectedBox,
            onEnter: onEnter,
            onDelete: onDelete
        )
    }
    
    final class Coordinator {
        private weak var monitoredWindow: NSWindow?
        private var isEnabled = false
        private var hasSelectedBox = false
        private var onEnter: (() -> Void)?
        private var onDelete: (() -> Void)?
        private var localMonitor: Any?
        
        init() {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                return handle(event: event)
            }
        }
        
        deinit {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
            }
        }
        
        func update(
            monitoredWindow: NSWindow?,
            isEnabled: Bool,
            hasSelectedBox: Bool,
            onEnter: @escaping () -> Void,
            onDelete: @escaping () -> Void
        ) {
            self.monitoredWindow = monitoredWindow
            self.isEnabled = isEnabled
            self.hasSelectedBox = hasSelectedBox
            self.onEnter = onEnter
            self.onDelete = onDelete
        }
        
        private func handle(event: NSEvent) -> NSEvent? {
            guard isEnabled else { return event }
            guard event.window === monitoredWindow else { return event }
            
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Cmd-D deletes the selected object and is intended to work even while editing
            // the selected-box label field (including selected/highlighted text).
            if flags == [.command],
               hasSelectedBox,
               event.charactersIgnoringModifiers?.lowercased() == "d" {
                onDelete?()
                return nil
            }
            
            // Do not steal other keys while a text editor (e.g. object label field or sidebar search) is active.
            if monitoredWindow?.firstResponder is NSTextView {
                return event
            }
            
            guard flags.isEmpty else { return event }
            
            switch Int(event.keyCode) {
            case 36, 76: // Return / keypad Enter
                onEnter?()
                return nil
            case 51, 117: // Delete / forward delete
                onDelete?()
                return nil
            default:
                return event
            }
        }
    }
}
