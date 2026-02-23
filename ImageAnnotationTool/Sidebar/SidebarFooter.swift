import SwiftUI

struct SidebarFooter: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.rootDirectoryURL?.lastPathComponent ?? "No directory selected")
                .fontWeight(.medium)
                .lineLimit(1)
            Text("\(store.imageFiles.count) images • \(store.unsavedImageFiles.count) unsaved")
                .font(.footnote)
                .foregroundColor(.secondary)
            if store.isScanningDirectory {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(store.scanProgressMessage ?? "Scanning…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            if let status = store.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 60)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(8)
        .padding()
    }
}

struct SidebarFooter_Previews: PreviewProvider {
    static var previews: some View {
        SidebarFooter()
    }
}
