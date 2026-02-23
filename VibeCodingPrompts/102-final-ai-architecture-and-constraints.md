# Image Annotation Tool: Final AI Architecture, Constraints, and File Plan

Use this with `101-final-ai-requirements.md` as the implementation reference for a fresh Codex session.

## Recommended Architecture (Final)

Use a hybrid macOS-native architecture:

- `SwiftUI` for:
  - app shell
  - toolbar/menus
  - sidebar container layout
  - bottom inspector UI
  - status/footer UI
- `AppKit` for:
  - annotation canvas (precision mouse interaction + custom drawing)
  - large file tree (`NSOutlineView`) for performance/scalability
- `Foundation` + `CoreGraphics` + `ImageIO` + `UniformTypeIdentifiers` for models and file IO

This is intentionally hybrid because:

- SwiftUI is good for shell/state wiring.
- AppKit is more reliable for precision canvas interactions and very large tree views.

## Key Models (Suggested)

### AnnotationBoundingBox

- Image-space pixel coordinates:
  - `xMin`, `yMin`, `xMax`, `yMax`
- `label`
- This rectangle is the exact geometry saved to Pascal VOC XML.
- The rendered label banner/title is UI-only and separate from the rectangle.

### ImageAnnotationDocument

- `imageURL`
- `filename`
- `imageSize`
- `[AnnotationBoundingBox]`
- `isDirty`
- `loadedFromXML`

### AnnotationAppStore (or equivalent central store)

Responsibilities:

- selected root directory
- recursive image file list
- selected image
- in-memory docs cache keyed by image URL
- dirty set + unsaved image list cache
- load warnings/errors
- file tree snapshots for sidebar
- scan/search/filter tasks
- save pipeline (XML / YOLO / classes.txt)
- navigation and command actions

## File Tree Performance Design (Final)

### Do This

- Build a precomputed tree snapshot after scan completes (off main thread).
- Publish a display snapshot for the UI.
- Keep a separate full snapshot for search/filter operations.
- Debounce search input (e.g., ~200ms) and filter off-main-thread.
- Use version counters/tokens to:
  - reload tree structure only when structure changes
  - refresh visible rows when only decorations change (dirty/warning)

### Avoid

- Rebuilding/grouping/sorting the entire tree inside SwiftUI `body`
- Deep nested SwiftUI `DisclosureGroup` trees for very large folders
- Preloading all images into memory
- Paging as the primary solution (not needed for this app if tree is efficient)

## Files Sidebar UI (NSOutlineView via NSViewRepresentable)

Implement `FilesSidebarSection` roughly as:

- SwiftUI wrapper view with header and search/progress states
- `NSViewRepresentable` wrapper (`FilesOutlineTreeView`)
- `Coordinator` implements `NSOutlineViewDataSource` + `NSOutlineViewDelegate`
- `NSOutlineView` row cell (`NSTableCellView` subclass or custom view)

Behavior:

- default collapsed directories on new load
- preserve user expansion state when possible
- auto-expand matching branches during active search
- file selection syncs with central store
- row decorations show:
  - dirty/unsaved marker
  - warning marker

## Annotation Canvas (AppKit)

Implement canvas using:

- `AnnotationCanvasNSView` (AppKit drawing + mouse handling)
- `AnnotationCanvasView` (`NSViewRepresentable` bridge)
- `AnnotationWorkspacePane` (SwiftUI workspace shell)

Canvas requirements:

- fit-to-view image display
- draw/select/move/resize boxes
- corner handles
- crosshair cursor on image drawing interaction
- hit-testing for:
  - box body
  - resize handles
  - label banner
- label banner drawn outside real box geometry
- large readable banner text

## Workspace Layout (No Jumpy Resizing)

- Title/metadata summary in top area only (toolbar/title bar or top summary region)
- No duplicate filename header in image pane
- Fixed-height bottom inspector panel for selected box controls
- Canvas area remains stable when selection changes

## Save Pipeline Rules

- Pascal VOC XML is source of truth.
- On save:
  1. Ensure in-memory document is loaded
  2. Merge labels into root `classes.txt`
  3. Write XML
  4. Write YOLO TXT derived from current annotations + classes mapping
  5. Clear dirty state only on success
- Prefer atomic writes (temp + replace)
- `Space` should only navigate after successful save

## Startup / Session Rules

- Always launch in “Open Directory…” state
- Do not auto-reopen recent directory
- No “Always on Top” feature exposed

## Suggested Final File Naming (Avoid Template Holdovers)

Use clear names from the start:

- `ImageAnnotationTool.swift`
- `MainScene.swift`
- `MainView.swift`
- `Export/AnnotationDataStore.swift`
- `Export/ExportCommands.swift`
- `Panes/AnnotationWorkspacePane.swift`
- `Panes/AnnotationCanvasView.swift`
- `Panes/AnnotationCanvasNSView.swift`
- `Sidebar/Sidebar.swift`
- `Sidebar/Sections/FilesSidebarSection.swift`
- `Sidebar/Sections/UnsavedAnnotationsSidebarSection.swift`
- `My Menu Commands/NavigationCommands.swift`

## Documentation / Licensing Constraints

- `README.md`
  - describe current functionality (annotation, XML/YOLO/classes)
  - no template references
  - mention large-folder optimized file tree and AppKit canvas (optional)
  - include AI assistance credit line for OpenAI Codex
- `LICENSE`
  - MIT License
  - `Copyright (c) 2026 David P. Discher`

## Validation Targets

- `xcodebuild` macOS build succeeds (codesign disabled okay for CLI validation)
- Manual tests:
  - open dir, recursive listing, selection, draw box, rename, delete
  - save creates XML/TXT/classes
  - save-all
  - quit/open warnings for unsaved
  - large folder expansion responsiveness
- Export validation fixtures/script (Pascal VOC, YOLO, classes merge)

