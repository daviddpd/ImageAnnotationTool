import SwiftUI

struct GeneralSidebarSection: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    
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
            } else if store.filteredImageFiles.isEmpty {
                Text("No matching files")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.filteredImageFiles, id: \.self) { fileURL in
                    FileSidebarRow(fileURL: fileURL)
                        .tag(Optional(fileURL))
                }
            }
        }
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
