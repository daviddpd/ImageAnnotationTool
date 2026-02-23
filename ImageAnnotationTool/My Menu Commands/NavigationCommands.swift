import SwiftUI

struct NavigationCommands: Commands {
    
    var body: some Commands {
        CommandMenu("Annotate") {
            Button {
                AnnotationAppStore.shared.goToPreviousImage()
            } label: {
                Text("Previous Image")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Button {
                AnnotationAppStore.shared.goToNextImage()
            } label: {
                Text("Next Image")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }
}
