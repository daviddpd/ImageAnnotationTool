import AppKit
import SwiftUI

struct AnnotationCanvasView: NSViewRepresentable {
    var image: NSImage
    var imageSize: AnnotationImageSize
    var boxes: [AnnotationBoundingBox]
    var selectedBoxID: UUID?
    var defaultNewLabel: String
    var onBoxesChanged: ([AnnotationBoundingBox]) -> Void
    var onSelectionChanged: (UUID?) -> Void
    var onLabelEditRequested: (UUID) -> Void
    
    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let view = AnnotationCanvasNSView()
        view.configure(
            image: image,
            imageSize: imageSize,
            boxes: boxes,
            selectedBoxID: selectedBoxID,
            defaultNewLabel: defaultNewLabel,
            onBoxesChanged: onBoxesChanged,
            onSelectionChanged: onSelectionChanged,
            onLabelEditRequested: onLabelEditRequested
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
            onBoxesChanged: onBoxesChanged,
            onSelectionChanged: onSelectionChanged,
            onLabelEditRequested: onLabelEditRequested
        )
    }
}
