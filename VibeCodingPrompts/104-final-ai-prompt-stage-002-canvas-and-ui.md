# Final AI Prompt (Stage 002): AppKit Annotation Canvas + Final UI Behaviors

Use this after Stage 001 to implement the interactive annotation experience and UI refinements.

```md
You are implementing Stage 002 for `ImageAnnotationTool` in a macOS SwiftUI/AppKit hybrid app.

Implement the interactive annotation canvas and UI behavior refinements from the finalized requirements docs:
- `VibeCodingPrompts/101-final-ai-requirements.md`
- `VibeCodingPrompts/102-final-ai-architecture-and-constraints.md`

Stage 002 goals:
- AppKit-backed canvas for box interactions
- stable, non-jumpy workspace layout
- readable overlay labels
- correct separation of label banner UI vs XML rectangle geometry

Required implementation details:

1. AppKit canvas (required)
- Implement `Panes/AnnotationCanvasNSView.swift` as custom `NSView`
- Implement `Panes/AnnotationCanvasView.swift` as `NSViewRepresentable` bridge
- Integrate into `Panes/AnnotationWorkspacePane.swift`

2. Canvas interactions
- Draw new box with click-drag (crosshair cursor when appropriate)
- Select box by clicking
- Move selected box by dragging inside the box
- Resize with corner handles
- Delete selected box
- Keep edits in image-space pixel coordinates
- Update the central store and mark current image dirty after edits

3. Label banner behavior (important)
- Render object-name label banner as a separate overlay element, not part of the actual bounding rectangle
- The banner/title should be outside the real rectangle when possible (above preferred; below if no room)
- XML/YOLO coordinates must continue to represent only the actual rectangle
- Banner hit-testing should support selecting the box / focusing label edit behavior

4. Overlay label readability
- Increase overlay label text substantially (roughly 3x compared to a small prototype)
- Increase banner height/padding to keep the text legible
- Use a clear filled banner style

5. Selected box inspector layout (avoid image resize)
- Place selected-box controls in a fixed-height bottom inspector panel/pane:
  - selected box summary
  - object label text field
  - apply/rename button
  - delete button
- Do NOT inject/remove variable-height controls inline in the main image view area
- The image/canvas viewport size should stay stable when selection changes

6. Main window naming/metadata display cleanup
- Keep filename/metadata in one top location only (preferred top/title region)
- Remove any duplicate in-pane filename header if one exists

7. Undo/redo (optional but recommended if straightforward)
- Wire box edit actions through `UndoManager` where practical
- If not feasible now, leave clean hooks for Stage 003

8. Non-features (do not add)
- Do not add “Always on Top” checkbox/menu feature
- Do not add recent-directory auto-reopen

Validation:
- Build with `xcodebuild`
- Manual test:
  - open directory
  - draw/select/move/resize/delete boxes
  - rename labels
  - verify UI does not resize/jump when selecting boxes
  - save and confirm XML/YOLO use actual box geometry, not the label banner

At the end, summarize:
- files changed
- known limitations intentionally deferred
- quick manual verification checklist
```

