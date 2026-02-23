# Image Annotation Tool: Final AI Requirements (Consolidated)

This document supersedes the earlier planning docs (`001-*`, `002-*`) and incorporates implementation feedback from the full build/review cycle.

Goal: define the final product requirements clearly enough that a new GPT-5.3 Codex session can recreate the app from a blank directory with a high success rate.

## Product Identity

- App name: `ImageAnnotationTool`
- Display name: `Image Annotation Tool`
- Platform: macOS native app
- Primary purpose: annotate images with bounding boxes and export annotations as:
  - Pascal VOC XML (`.xml`) (source of truth)
  - YOLO TXT (`.txt`) (derived from XML/in-memory model)

## Core Functional Requirements

### Directory + File Discovery

- User opens a directory via an `Open Directory…` action.
- App recursively scans for supported image files:
  - `.jpg`, `.jpeg`, `.png` (case-insensitive)
- Do not preload/decode all images into memory.
- Show scan progress/status during large scans.

### Files Sidebar (Tree Navigator)

- Left sidebar contains a `Files` section implemented as a tree navigator (Xcode/Finder-like feel).
- Use built-in macOS tree control behavior (`NSOutlineView` preferred).
- All directories are collapsed by default when a directory is opened.
- Clicking a file selects and loads that image.
- Search/filter:
  - Sidebar search field filters files/folders by name/path.
  - During active search, matching branches should be expanded so results are visible.
  - When search is cleared, return to user-controlled collapsed/expanded state.

### Unsaved Annotations Sidebar

- Sidebar also contains an `Unsaved Annotations` section listing images with unsaved edits.
- Clicking an item restores/selects that image and keeps in-memory unsaved annotations.

### Main Workspace

- Show one image at a time in the main workspace.
- Filename should appear in one place only (top/title area preferred).
- Do not show a duplicate filename header inside the image viewport area.
- The workspace image area should not resize/jump when box selection changes.

### Bounding Box Editing

- Interactive annotation canvas for:
  - draw rectangle (click-drag)
  - select box
  - move box
  - resize box with handles
  - rename selected object label
  - delete selected box
- Cursor behavior should support precise annotation work (crosshair while drawing on image).

### Bounding Box Label Banner (Important)

- The visible object-name banner/title is separate from the actual bounding box geometry.
- The banner should NOT be part of the transparent rectangle recorded in XML.
- XML/YOLO coordinates must reflect only the real bounding rectangle.
- Banner can be rendered above the box (or below if there is no room).
- Banner should be easily readable:
  - substantially larger label text than the initial prototype (roughly 3x or more)

### Selected Box Inspector UI

- Selected box controls (`Object label`, apply/rename, delete) should live in a fixed inspector panel/pane (bottom preferred).
- Selecting/drawing a box must not cause the main image viewport to resize.

## Data + File Format Requirements

### Pascal VOC XML (Source of Truth)

- For each image, load same-basename `.xml` if present.
- If XML is missing, initialize empty annotations.
- Minimum supported Pascal VOC fields:
  - `annotation`
  - `filename`
  - `size/width`
  - `size/height`
  - `size/depth`
  - repeated `object`
  - `object/name`
  - `bndbox/xmin`, `ymin`, `xmax`, `ymax`

### YOLO TXT (Derived)

- On save, generate/update same-basename `.txt` beside the image.
- YOLO format:
  - `class_id x_center y_center width height`
  - normalized to `[0, 1]`
- If no objects exist, write an empty `.txt` file.

### classes.txt

- Maintain `classes.txt` at the selected root directory.
- Add new labels when saving.
- Preserve stable deterministic ordering.
- Zero-based class IDs map to line order.

### Atomic Writes / Safety

- Save XML, YOLO TXT, and `classes.txt` using atomic-ish writes (temp file + replace) where practical.

## Navigation + Save Behavior

- Toolbar should include:
  - Open Directory
  - Previous
  - Save
  - Next
  - Save All Unsaved (recommended)
- Keyboard shortcuts:
  - `Cmd+O`: open directory
  - `Cmd+S`: save current image annotations
  - `Cmd+Shift+S`: save all unsaved annotations
  - `Space`: save current, then move to next (advance only if save succeeds)
  - Left arrow: previous image (no save)
  - Right arrow: next image (no save)

## Unsaved / Prompting Behavior

- Track dirty state per image.
- Unsaved list must remain accurate during edit/save/navigation flows.
- Warn before operations that would abandon a session with unsaved edits:
  - opening a new directory
  - quitting app
- Offer save/discard/cancel style choices.
- Left/right navigation should not implicitly discard in-memory unsaved edits.

## Startup Behavior (Important Product Decision)

- Do NOT auto-restore the last opened directory on launch.
- Always start in an initial state with an open-directory prompt/button visible.
- Rationale: avoid false startup failures like “No supported images were found…” for previously opened valid directories.

## Performance Requirements (Large Datasets)

- Target responsiveness with large datasets (e.g., ~20,000 images total, and folders with 13,000+ files).
- Avoid main-thread stalls when expanding large folders in the file tree.
- Do not use paging/progressive rendering as the primary fix.
- Preferred performance design:
  - AppKit `NSOutlineView` tree
  - precomputed cached tree snapshot/index
  - debounced async search/filter against cached tree
  - targeted row updates for dirty/warning decorations

## UI/Feature Cleanup Requirements

- No “Always on Top” option in UI/menu.
- Remove template/demo naming and placeholders from code, docs, and README.
- Use clear production names (examples):
  - `AnnotationDataStore.swift`
  - `AnnotationWorkspacePane.swift`
  - `AnnotationCanvasView.swift`
  - `AnnotationCanvasNSView.swift`
  - `FilesSidebarSection.swift`
  - `UnsavedAnnotationsSidebarSection.swift`
  - `NavigationCommands.swift`

## Documentation + Licensing Requirements

- README should describe the current app (not the starter template).
- Remove remaining template references from README.
- License remains MIT.
- License and README should credit:
  - `David P. Discher`
- Add a README credit line noting AI assistance, e.g.:
  - “Large parts of this application were developed with assistance from OpenAI Codex.”

## Validation / Deliverables

- Buildable macOS app project
- Manual QA checklist for key workflows
- Small export-validation fixture set (Pascal VOC / YOLO / classes)
- Runnable validation script is acceptable (XCTest optional)

