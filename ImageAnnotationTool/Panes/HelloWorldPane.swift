import SwiftUI

struct HelloWorldPane: View {
    @ObservedObject private var store = AnnotationAppStore.shared
    @Environment(\.undoManager) private var undoManager
    
    @State private var selectedBoxID: UUID?
    @State private var labelEditorText = ""
    @FocusState private var isLabelEditorFocused: Bool
    
    var body: some View {
        Pane {
            content
                .padding()
        }
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
                                    .font(.caption)
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
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = store.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if let warningMessage = store.currentImageWarningMessage {
                Text(warningMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(2)
            } else {
                Text(" ")
                    .font(.caption)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170, alignment: .topLeading)
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
                        .font(.subheadline.weight(.semibold))
                    Text(coordinatesSummary(for: selectedBox))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    TextField("Object label", text: $labelEditorText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isLabelEditorFocused)
                        .onSubmit {
                            commitSelectedBoxLabel()
                        }
                    
                    Button("Apply") {
                        commitSelectedBoxLabel()
                    }
                    
                    Button(role: .destructive) {
                        deleteSelectedBox()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
                Text("Click the filled label banner on a box to focus this field and rename it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Click-drag on the image to draw a bounding box. Click a box or its label banner to select it.")
                .font(.caption)
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
        }
    }
    
    private func syncSelectionWithCurrentDocument(resetSelection: Bool) {
        guard let document = store.currentDocument else {
            selectedBoxID = nil
            labelEditorText = ""
            return
        }
        
        if resetSelection {
            selectedBoxID = nil
            labelEditorText = ""
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
    
    private func commitSelectedBoxLabel() {
        guard let document = store.currentDocument,
              let selectedBoxID,
              let index = document.objects.firstIndex(where: { $0.id == selectedBoxID }) else {
            return
        }
        
        let trimmed = labelEditorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            labelEditorText = document.objects[index].label
            return
        }
        
        guard document.objects[index].label != trimmed else {
            return
        }
        
        var updated = document.objects
        updated[index].label = trimmed
        store.updateObjectsForCurrentImage(
            updated,
            undoManager: undoManager,
            actionName: "Rename Bounding Box"
        )
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
        self.selectedBoxID = nil
        labelEditorText = ""
    }
    
    private func coordinatesSummary(for box: AnnotationBoundingBox) -> String {
        "(\(Int(box.xMin.rounded())), \(Int(box.yMin.rounded()))) → (\(Int(box.xMax.rounded())), \(Int(box.yMax.rounded())))"
    }
}

struct HelloWorldPane_Previews: PreviewProvider {
    static var previews: some View {
        HelloWorldPane()
            .frame(width: 700, height: 500)
    }
}
