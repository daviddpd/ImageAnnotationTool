import AppKit

final class AnnotationCanvasNSView: NSView {
    private enum InteractionState {
        case none
        case creating(start: CGPoint)
        case moving(boxID: UUID, original: AnnotationBoundingBox, startImagePoint: CGPoint)
        case resizing(boxID: UUID, handle: ResizeHandle, original: AnnotationBoundingBox, startImagePoint: CGPoint)
    }
    
    private enum ResizeHandle {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    private enum HitRegion {
        case labelBanner
        case body
        case resizeHandle(ResizeHandle)
    }
    
    private struct HitResult {
        let boxID: UUID
        let region: HitRegion
    }
    
    private let canvasInset: CGFloat = 8
    private let handleSize: CGFloat = 8
    private let minBoxDimensionInPixels: CGFloat = 4
    private let labelBannerHeight: CGFloat = 20
    
    private var image: NSImage?
    private var imageSize: AnnotationImageSize = .init(width: 1, height: 1, depth: 3)
    private var boxes: [AnnotationBoundingBox] = []
    private var selectedBoxID: UUID?
    private var defaultNewLabel: String = "object"
    
    private var onBoxesChanged: (([AnnotationBoundingBox]) -> Void)?
    private var onSelectionChanged: ((UUID?) -> Void)?
    private var onLabelEditRequested: ((UUID) -> Void)?
    
    private var interactionState: InteractionState = .none
    private var activeCreateBoxID: UUID?
    private var cursorTrackingArea: NSTrackingArea?
    
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    
    func configure(
        image: NSImage,
        imageSize: AnnotationImageSize,
        boxes: [AnnotationBoundingBox],
        selectedBoxID: UUID?,
        defaultNewLabel: String,
        onBoxesChanged: @escaping ([AnnotationBoundingBox]) -> Void,
        onSelectionChanged: @escaping (UUID?) -> Void,
        onLabelEditRequested: @escaping (UUID) -> Void
    ) {
        self.image = image
        self.imageSize = imageSize
        if self.boxes != boxes {
            self.boxes = boxes
            needsDisplay = true
        }
        if self.selectedBoxID != selectedBoxID {
            self.selectedBoxID = selectedBoxID
            needsDisplay = true
        }
        self.defaultNewLabel = defaultNewLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "object" : defaultNewLabel
        self.onBoxesChanged = onBoxesChanged
        self.onSelectionChanged = onSelectionChanged
        self.onLabelEditRequested = onLabelEditRequested
        window?.invalidateCursorRects(for: self)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        cursorTrackingArea = trackingArea
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        if let imageRect = fittedImageRect() {
            addCursorRect(imageRect, cursor: .crosshair)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        
        guard let image, let imageRect = fittedImageRect() else {
            drawPlaceholderText("No image", in: bounds)
            return
        }
        
        NSColor(calibratedWhite: 0.0, alpha: 0.05).setFill()
        NSBezierPath(roundedRect: imageRect.insetBy(dx: -1, dy: -1), xRadius: 8, yRadius: 8).fill()
        
        image.draw(in: imageRect)
        drawGridBorder(imageRect)
        
        for box in boxes {
            guard let boxRect = viewRect(for: box) else { continue }
            draw(box: box, in: boxRect, selected: box.id == selectedBoxID)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let imageRect = fittedImageRect() else {
            super.mouseDown(with: event)
            return
        }
        
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        
        if let hit = hitTestBox(at: point) {
            selectBox(hit.boxID)
            switch hit.region {
            case .labelBanner:
                onLabelEditRequested?(hit.boxID)
                interactionState = .none
            case .body:
                guard let imagePoint = imagePoint(fromViewPoint: point),
                      let original = boxes.first(where: { $0.id == hit.boxID }) else {
                    interactionState = .none
                    return
                }
                interactionState = .moving(boxID: hit.boxID, original: original, startImagePoint: imagePoint)
            case .resizeHandle(let handle):
                guard let imagePoint = imagePoint(fromViewPoint: point),
                      let original = boxes.first(where: { $0.id == hit.boxID }) else {
                    interactionState = .none
                    return
                }
                interactionState = .resizing(boxID: hit.boxID, handle: handle, original: original, startImagePoint: imagePoint)
            }
            return
        }
        
        if imageRect.contains(point), let imagePoint = imagePoint(fromViewPoint: point) {
            selectBox(nil)
            activeCreateBoxID = nil
            interactionState = .creating(start: imagePoint)
        } else {
            selectBox(nil)
            activeCreateBoxID = nil
            interactionState = .none
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let currentImagePoint = imagePoint(fromViewPoint: point, clampedToImage: true) else {
            return
        }
        
        switch interactionState {
        case .none:
            break
        case .creating(let start):
            let newBox = makeBox(from: start, to: currentImagePoint, label: defaultNewLabel)
            guard let newBox else { return }
            upsertTransientCreatedBox(newBox)
        case .moving(let boxID, let original, let startImagePoint):
            let moved = movedBox(original, deltaFrom: startImagePoint, to: currentImagePoint)
            replaceBox(id: boxID, with: moved, preserveSelection: true)
        case .resizing(let boxID, let handle, let original, let startImagePoint):
            let resized = resizedBox(original, handle: handle, deltaFrom: startImagePoint, to: currentImagePoint)
            replaceBox(id: boxID, with: resized, preserveSelection: true)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        switch interactionState {
        case .creating:
            finalizeTransientCreatedBoxIfTooSmall()
        case .none, .moving, .resizing:
            break
        }
        activeCreateBoxID = nil
        interactionState = .none
    }
    
    private func drawPlaceholderText(_ text: String, in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }
    
    private func drawGridBorder(_ imageRect: CGRect) {
        let path = NSBezierPath(roundedRect: imageRect, xRadius: 8, yRadius: 8)
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
    
    private func draw(box: AnnotationBoundingBox, in rect: CGRect, selected: Bool) {
        let strokeColor = selected ? NSColor.systemBlue : NSColor.systemGreen
        let fillColor = strokeColor.withAlphaComponent(selected ? 0.15 : 0.08)
        let bannerColor = strokeColor.withAlphaComponent(selected ? 0.95 : 0.85)
        
        fillColor.setFill()
        NSBezierPath(rect: rect).fill()
        
        strokeColor.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = selected ? 2 : 1.5
        border.stroke()
        
        let bannerRect = labelBannerRect(forBoxRect: rect)
        bannerColor.setFill()
        NSBezierPath(rect: bannerRect).fill()
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let labelInsetRect = bannerRect.insetBy(dx: 6, dy: 2)
        (box.label as NSString).draw(in: labelInsetRect, withAttributes: labelAttributes)
        
        if selected {
            for handleRect in resizeHandleRects(for: rect).values {
                NSColor.white.setFill()
                NSBezierPath(rect: handleRect).fill()
                strokeColor.setStroke()
                let handlePath = NSBezierPath(rect: handleRect)
                handlePath.lineWidth = 1
                handlePath.stroke()
            }
        }
    }
    
    private func fittedImageRect() -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let available = bounds.insetBy(dx: canvasInset, dy: canvasInset)
        guard available.width > 2, available.height > 2 else { return nil }
        
        let imageAspect = CGFloat(imageSize.width) / CGFloat(imageSize.height)
        let availableAspect = available.width / available.height
        
        let fittedSize: CGSize
        if imageAspect > availableAspect {
            fittedSize = CGSize(width: available.width, height: available.width / imageAspect)
        } else {
            fittedSize = CGSize(width: available.height * imageAspect, height: available.height)
        }
        
        let origin = CGPoint(
            x: available.midX - fittedSize.width / 2,
            y: available.midY - fittedSize.height / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }
    
    private func imagePoint(fromViewPoint point: CGPoint, clampedToImage: Bool = false) -> CGPoint? {
        guard let imageRect = fittedImageRect() else { return nil }
        if !clampedToImage && !imageRect.contains(point) {
            return nil
        }
        
        let localX = clampedToImage ? clamp(point.x, min: imageRect.minX, max: imageRect.maxX) : point.x
        let localY = clampedToImage ? clamp(point.y, min: imageRect.minY, max: imageRect.maxY) : point.y
        
        let normX = (localX - imageRect.minX) / imageRect.width
        let normY = (localY - imageRect.minY) / imageRect.height
        return CGPoint(
            x: clamp(normX, min: 0, max: 1) * CGFloat(imageSize.width),
            y: clamp(normY, min: 0, max: 1) * CGFloat(imageSize.height)
        )
    }
    
    private func viewRect(for box: AnnotationBoundingBox) -> CGRect? {
        guard let imageRect = fittedImageRect() else { return nil }
        let xScale = imageRect.width / CGFloat(imageSize.width)
        let yScale = imageRect.height / CGFloat(imageSize.height)
        
        let x1 = imageRect.minX + CGFloat(min(box.xMin, box.xMax)) * xScale
        let y1 = imageRect.minY + CGFloat(min(box.yMin, box.yMax)) * yScale
        let x2 = imageRect.minX + CGFloat(max(box.xMin, box.xMax)) * xScale
        let y2 = imageRect.minY + CGFloat(max(box.yMin, box.yMax)) * yScale
        return CGRect(x: x1, y: y1, width: max(0, x2 - x1), height: max(0, y2 - y1))
    }
    
    private func hitTestBox(at point: CGPoint) -> HitResult? {
        for box in boxes.reversed() {
            guard let rect = viewRect(for: box), rect.width > 0, rect.height > 0 else { continue }
            
            if box.id == selectedBoxID {
                for (handle, handleRect) in resizeHandleRects(for: rect) {
                    if handleRect.insetBy(dx: -2, dy: -2).contains(point) {
                        return HitResult(boxID: box.id, region: .resizeHandle(handle))
                    }
                }
            }
            
            let bannerRect = labelBannerRect(forBoxRect: rect)
            if bannerRect.contains(point) {
                return HitResult(boxID: box.id, region: .labelBanner)
            }
            
            if rect.contains(point) {
                return HitResult(boxID: box.id, region: .body)
            }
        }
        return nil
    }
    
    private func labelBannerRect(forBoxRect rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(labelBannerHeight, max(12, rect.height))
        )
    }
    
    private func resizeHandleRects(for rect: CGRect) -> [ResizeHandle: CGRect] {
        let half = handleSize / 2
        return [
            .topLeft: CGRect(x: rect.minX - half, y: rect.minY - half, width: handleSize, height: handleSize),
            .topRight: CGRect(x: rect.maxX - half, y: rect.minY - half, width: handleSize, height: handleSize),
            .bottomLeft: CGRect(x: rect.minX - half, y: rect.maxY - half, width: handleSize, height: handleSize),
            .bottomRight: CGRect(x: rect.maxX - half, y: rect.maxY - half, width: handleSize, height: handleSize)
        ]
    }
    
    private func selectBox(_ id: UUID?) {
        guard selectedBoxID != id else { return }
        selectedBoxID = id
        onSelectionChanged?(id)
        needsDisplay = true
    }
    
    private func makeBox(from start: CGPoint, to end: CGPoint, label: String) -> AnnotationBoundingBox? {
        let xMin = min(start.x, end.x)
        let yMin = min(start.y, end.y)
        let xMax = max(start.x, end.x)
        let yMax = max(start.y, end.y)
        guard (xMax - xMin) >= minBoxDimensionInPixels, (yMax - yMin) >= minBoxDimensionInPixels else {
            return nil
        }
        return AnnotationBoundingBox(label: label, xMin: xMin.double, yMin: yMin.double, xMax: xMax.double, yMax: yMax.double)
    }
    
    private func upsertTransientCreatedBox(_ newBox: AnnotationBoundingBox) {
        switch interactionState {
        case .creating:
            if let activeCreateBoxID,
               let index = boxes.firstIndex(where: { $0.id == activeCreateBoxID }) {
                var updated = boxes
                updated[index] = newBox.with(id: activeCreateBoxID)
                boxes = updated
                selectedBoxID = activeCreateBoxID
                onBoxesChanged?(updated)
                onSelectionChanged?(activeCreateBoxID)
            } else {
                let created = newBox
                var updated = boxes
                updated.append(created)
                boxes = updated
                selectedBoxID = created.id
                activeCreateBoxID = created.id
                onBoxesChanged?(updated)
                onSelectionChanged?(created.id)
            }
            needsDisplay = true
        default:
            break
        }
    }
    
    private func finalizeTransientCreatedBoxIfTooSmall() {
        // Creation path only appends after minimum size is exceeded, so nothing to prune here.
    }
    
    private func movedBox(_ original: AnnotationBoundingBox, deltaFrom start: CGPoint, to current: CGPoint) -> AnnotationBoundingBox {
        let dx = current.x - start.x
        let dy = current.y - start.y
        let width = CGFloat(original.xMax - original.xMin)
        let height = CGFloat(original.yMax - original.yMin)
        
        var xMin = CGFloat(original.xMin) + dx
        var yMin = CGFloat(original.yMin) + dy
        xMin = clamp(xMin, min: 0, max: CGFloat(imageSize.width) - width)
        yMin = clamp(yMin, min: 0, max: CGFloat(imageSize.height) - height)
        
        return AnnotationBoundingBox(
            id: original.id,
            label: original.label,
            xMin: xMin.double,
            yMin: yMin.double,
            xMax: (xMin + width).double,
            yMax: (yMin + height).double
        )
    }
    
    private func resizedBox(_ original: AnnotationBoundingBox, handle: ResizeHandle, deltaFrom start: CGPoint, to current: CGPoint) -> AnnotationBoundingBox {
        let dx = current.x - start.x
        let dy = current.y - start.y
        var xMin = CGFloat(original.xMin)
        var yMin = CGFloat(original.yMin)
        var xMax = CGFloat(original.xMax)
        var yMax = CGFloat(original.yMax)
        
        switch handle {
        case .topLeft:
            xMin += dx
            yMin += dy
        case .topRight:
            xMax += dx
            yMin += dy
        case .bottomLeft:
            xMin += dx
            yMax += dy
        case .bottomRight:
            xMax += dx
            yMax += dy
        }
        
        let maxW = CGFloat(imageSize.width)
        let maxH = CGFloat(imageSize.height)
        xMin = clamp(xMin, min: 0, max: maxW)
        xMax = clamp(xMax, min: 0, max: maxW)
        yMin = clamp(yMin, min: 0, max: maxH)
        yMax = clamp(yMax, min: 0, max: maxH)
        
        if xMax - xMin < minBoxDimensionInPixels {
            if handle == .topLeft || handle == .bottomLeft {
                xMin = xMax - minBoxDimensionInPixels
            } else {
                xMax = xMin + minBoxDimensionInPixels
            }
        }
        if yMax - yMin < minBoxDimensionInPixels {
            if handle == .topLeft || handle == .topRight {
                yMin = yMax - minBoxDimensionInPixels
            } else {
                yMax = yMin + minBoxDimensionInPixels
            }
        }
        
        xMin = clamp(xMin, min: 0, max: maxW)
        xMax = clamp(xMax, min: 0, max: maxW)
        yMin = clamp(yMin, min: 0, max: maxH)
        yMax = clamp(yMax, min: 0, max: maxH)
        
        return AnnotationBoundingBox(
            id: original.id,
            label: original.label,
            xMin: min(xMin, xMax).double,
            yMin: min(yMin, yMax).double,
            xMax: max(xMin, xMax).double,
            yMax: max(yMin, yMax).double
        )
    }
    
    private func replaceBox(id: UUID, with updatedBox: AnnotationBoundingBox, preserveSelection: Bool) {
        guard let index = boxes.firstIndex(where: { $0.id == id }) else { return }
        var updated = boxes
        updated[index] = updatedBox
        boxes = updated
        if preserveSelection {
            selectedBoxID = id
        }
        onBoxesChanged?(updated)
        needsDisplay = true
    }
    
    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.max(lower, Swift.min(upper, value))
    }
}

private extension CGFloat {
    var double: Double { Double(self) }
}

private extension AnnotationBoundingBox {
    func with(id: UUID) -> AnnotationBoundingBox {
        AnnotationBoundingBox(id: id, label: label, xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax)
    }
}
