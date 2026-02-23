import SwiftUI

struct ExportCommands: Commands {

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Directory…") {
                AnnotationAppStore.shared.openDirectoryPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        
        CommandGroup(replacing: .importExport) {
            EmptyView()
        }
        
        CommandGroup(after: .saveItem) {
            Button("Save Current Annotation") {
                AnnotationAppStore.shared.saveCurrentAnnotations()
            }
            .keyboardShortcut("s", modifiers: [.command])
            
            Button("Save All Unsaved Annotations") {
                AnnotationAppStore.shared.saveAllUnsavedAnnotations()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            
            Button("Save and Next") {
                AnnotationAppStore.shared.saveCurrentAndAdvance()
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}
