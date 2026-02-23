import SwiftUI

struct UnsavedAnnotationsSidebarSection: View {
    
    @ObservedObject private var store = AnnotationAppStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unsaved Annotations")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            
            if store.unsavedImageFiles.isEmpty {
                Text("None")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(store.unsavedImageFiles, id: \.self) { fileURL in
                            Button {
                                store.selectImage(url: fileURL)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.orange)
                                    Text(store.relativePath(for: fileURL))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, idealHeight: 120, maxHeight: 180, alignment: .topLeading)
    }
}

struct UnsavedAnnotationsSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        UnsavedAnnotationsSidebarSection()
    }
}
