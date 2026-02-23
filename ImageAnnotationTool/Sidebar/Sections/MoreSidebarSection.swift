import SwiftUI

struct MoreSidebarSection: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    
    var body: some View {
        Section(header: Text("Unsaved Annotations")) {
            if store.unsavedImageFiles.isEmpty {
                Text("None")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.unsavedImageFiles, id: \.self) { fileURL in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                        Text(store.relativePath(for: fileURL))
                            .lineLimit(1)
                    }
                    .tag(Optional(fileURL))
                }
            }
        }
    }
}

struct MoreSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        List {
            MoreSidebarSection()
        }
    }
}
