import SwiftUI

struct MainView: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    
    var body: some View {
        NavigationView {
            Sidebar()
            HelloWorldPane()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.openDirectoryPanel()
                } label: {
                    Label("Open Directory", systemImage: "folder")
                }
                .help("Open an image directory (recursive scan)")
                
                Button {
                    store.goToPreviousImage()
                } label: {
                    Label("Previous Image", systemImage: "chevron.left")
                }
                .disabled(!store.canGoPrevious)
                .help("Previous image (Left Arrow)")
                
                Button {
                    store.saveCurrentAnnotations()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canSaveCurrent)
                .help("Save current annotation (Command-S)")
                
                Button {
                    store.saveAllUnsavedAnnotations()
                } label: {
                    Label("Save All", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(!store.canSaveAllUnsaved)
                .help("Save all unsaved annotations (Command-Shift-S)")
                
                Button {
                    store.goToNextImage()
                } label: {
                    Label("Next Image", systemImage: "chevron.right")
                }
                .disabled(!store.canGoNext)
                .help("Next image (Right Arrow)")
            }
            
            ToolbarItem {
                if store.isScanningDirectory {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(store.scanProgressMessage ?? "Scanning…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
