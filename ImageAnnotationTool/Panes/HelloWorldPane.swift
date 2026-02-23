import SwiftUI

struct HelloWorldPane: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
        
    var body: some View {
        Pane {
            content
                .padding()
        }
        .navigationTitle(store.selectedImageURL?.lastPathComponent ?? "Image Annotation Tool")
        .navigationSubtitle(store.selectedImageURL.map { store.metadataSummary(for: $0) } ?? "Open a directory to begin")
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
        } else if store.selectedImageURL != nil {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.04))
                    
                    if let image = store.currentImageNSImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(8)
                    } else {
                        Text("Unable to load image preview")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Text("TODO(Stage 002): Replace this preview with an interactive annotation canvas (draw/select/move/resize bounding boxes).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if let document = store.currentDocument, !document.objects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(document.objects) { object in
                                Text(object.label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                if let errorMessage = store.lastErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        } else {
            Text("Select an image from the Files sidebar.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct HelloWorldPane_Previews: PreviewProvider {
    static var previews: some View {
        HelloWorldPane()
            .frame(width: 700, height: 500)
    }
}
