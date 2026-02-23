import Foundation

enum SidebarPane {
    
    case files
    case unsavedAnnotations
}

// MARK: - Protocol Conformances

extension SidebarPane: Equatable, Identifiable {
    var id: Self { self }
}
