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
                
                Button {
                    store.goToPreviousImage()
                } label: {
                    Label("Previous Image", systemImage: "chevron.left")
                }
                .disabled(!store.canGoPrevious)
                
                Button {
                    store.saveCurrentAnnotations()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(store.selectedImageURL == nil)
                
                Button {
                    store.goToNextImage()
                } label: {
                    Label("Next Image", systemImage: "chevron.right")
                }
                .disabled(!store.canGoNext)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
