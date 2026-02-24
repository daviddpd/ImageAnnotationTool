import AppKit
import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    enum KeyboardCommand {
        case activateFirstObjectEditor
        case focusNextObjectEditor
        case deleteSelectedObject
    }
    
    var image: NSImage
    var imageSize: AnnotationImageSize
    var boxes: [AnnotationBoundingBox]
    var selectedBoxID: UUID?
    var defaultNewLabel: String
    var focusRequestID: UInt64
    var onBoxesChanged: ([AnnotationBoundingBox]) -> Void
    var onSelectionChanged: (UUID?) -> Void
    var onLabelEditRequested: (UUID) -> Void
    var onKeyboardCommand: (KeyboardCommand) -> Void
    
    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let view = AnnotationCanvasNSView()
        view.configure(
            image: image,
            imageSize: imageSize,
            boxes: boxes,
            selectedBoxID: selectedBoxID,
            defaultNewLabel: defaultNewLabel,
            focusRequestID: focusRequestID,
            onBoxesChanged: onBoxesChanged,
            onSelectionChanged: onSelectionChanged,
            onLabelEditRequested: onLabelEditRequested,
            onKeyboardCommand: onKeyboardCommand
        )
        return view
    }
    
    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.configure(
            image: image,
            imageSize: imageSize,
            boxes: boxes,
            selectedBoxID: selectedBoxID,
            defaultNewLabel: defaultNewLabel,
            focusRequestID: focusRequestID,
            onBoxesChanged: onBoxesChanged,
            onSelectionChanged: onSelectionChanged,
            onLabelEditRequested: onLabelEditRequested,
            onKeyboardCommand: onKeyboardCommand
        )
    }
}
