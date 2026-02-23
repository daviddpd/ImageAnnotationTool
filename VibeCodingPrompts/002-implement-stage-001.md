# Image Annotation Tool: Implementation Staging (Stage 001 + Follow-on Stages)

This document is a review-first implementation plan generated from `/Users/dpd/Documents/projects/github/ImageAnnotationTool/VibeCodingPrompts/001-Inital Requirements.md`.

The goal is to stage the work before coding the full app.

## Recommended Technical Approach (Research Summary)

### Best approach for v1 (macOS-native, low dependency risk)

- Use a **hybrid SwiftUI + AppKit** UI.
- Keep the app shell, menus, sidebar, settings, and commands in **SwiftUI** (the current template already provides this).
- Build the annotation surface (image display + zoom/pan + hit-testing + draw/drag/resize boxes) as a **custom AppKit view**, bridged into SwiftUI with `NSViewRepresentable`.

Why this is the best fit for v1:

- SwiftUI is good for the app shell and state-driven lists, but precise mouse interaction for annotation tools is still much easier and more predictable in AppKit.
- AppKit gives direct control over:
  - mouse down/drag/up
  - cursor changes (crosshair, resize handles)
  - coordinate transforms
  - drawing performance for overlays
  - keyboard handling in a focused editor view

### Libraries/APIs to use first (minimal dependencies)

Use Apple frameworks first; avoid third-party libraries in Stage 001:

- `SwiftUI` for app shell, sidebar, toolbar, commands, and panes
- `AppKit` for the annotation canvas and file open panel (`NSOpenPanel`)
- `Foundation` for file IO, models, XML parsing/writing
- `CoreGraphics` for box geometry math
- `ImageIO` for reliable image metadata/dimensions if needed
- `UniformTypeIdentifiers` (`UTType`) for image file filtering

### XML / format strategy (important)

- **Pascal VOC XML is the source of truth** (matches your requirement).
- Internally store annotation boxes in a neutral model (pixel coordinates in image space).
- Generate YOLO `.txt` from that internal model (derived output).
- Maintain `classes.txt` at the selected root directory and assign stable zero-based class IDs.

### XML parser recommendation

For macOS-only app:

- Prefer `Foundation.XMLDocument` for reading/updating/writing Pascal VOC XML in a DOM-style workflow (simpler than a streaming parser for this use case).
- Keep `XMLParser` as fallback/secondary option if you later need strict streaming parsing or compatibility changes.

### UI/interaction strategy for the canvas

- One custom `NSView` (or a small `NSScrollView` + custom document view pair) owns:
  - image rendering
  - overlay drawing
  - selection
  - drag/resize handles
  - new-box creation
- SwiftUI wraps it and binds to app state.

This avoids fighting SwiftUI gesture composition for a precision tool.

## Current Template Mapping (What to Reuse/Replace)

Map the existing template to your requirements:

- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/Sidebar/Sections/GeneralSidebarSection.swift`
  - Replace section title `General` -> `Files`
  - Replace demo links with directory tree / image list UI
- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/Sidebar/Sections/MoreSidebarSection.swift`
  - Replace section title `More` -> `Unsaved Annotations`
  - List images with pending unsaved XML edits
- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/Panes/HelloWorldPane.swift`
  - Replace with main annotation workspace pane
- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/Panes/MoreStuffPane.swift`
  - Reuse drop-target ideas for directory import (optional)
- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/MainScene.swift`
  - Replace toolbar/commands with open directory, save, prev/next, shortcuts
- `/Users/dpd/Documents/projects/github/ImageAnnotationTool/ImageAnnotationTool/Sidebar/SidebarPane.swift`
  - Replace demo pane cases with app-specific navigation cases

## Proposed Implementation Stages

- Stage 001: App shell + data model + directory loading + image navigation + XML/YOLO read/write core (no full interactive box editing yet)
- Stage 002: Annotation canvas (draw/select/move/resize boxes) + label editing UI
- Stage 003: Unsaved annotation queue + autosave/navigation behavior + keyboard shortcuts
- Stage 004: Robustness/polish (error handling, edge cases, perf on large folders)
- Stage 005: QA pass + test fixtures + export validation samples

---

## Stage 001 Prompt (AI execution prompt)

Use the following prompt to implement Stage 001 only.

```md
You are implementing Stage 001 for the macOS SwiftUI app in this repository (`ImageAnnotationTool`).

Goal:
- Convert the current template app into a working foundation for an image annotation tool.
- Do NOT implement full drag/resize annotation editing yet (Stage 002 handles that).
- Focus on app structure, file loading, image navigation, and XML/YOLO/class mapping persistence core.

Requirements (Stage 001):

1. Sidebar restructuring
- Replace the template sidebar sections:
  - `General` -> `Files`
  - `More` -> `Unsaved Annotations`
- Remove demo entries (`Hello, World!`, `What's Up?`, `More Stuff`).
- Add a file browser list for images under a selected root directory (recursive).
- Support `.jpg`, `.jpeg`, `.png` (case-insensitive).
- Add an “Open Directory…” action (toolbar or command menu) using `NSOpenPanel` configured for directory selection.

2. Main workspace pane
- Replace the demo pane with an image viewer workspace pane.
- Display the currently selected image.
- Show basic metadata (filename, index/total, image size if easy to obtain).
    - put this in the "sidebar footer", use apple like styling
    - select and provide some intresting fields from EXIF, if the files has it.
- Provide Next/Previous navigation.

3. Data model foundation
- Add app state/store types for:
  - selected root directory
  - discovered image files (recursive)
  - current image index
  - per-image annotation model (in-memory)
  - unsaved items list
  - classes list / class-to-id map
- Internal box model should use image-space pixel coordinates (`xMin`, `yMin`, `xMax`, `yMax`) and `label`.
- Design the model so Stage 002 can plug in interactive editing without refactoring everything.

4. Pascal VOC XML support (source of truth)
- Implement read/write support for Pascal VOC XML (minimum required fields for v1):
  - `annotation`
  - `filename`
  - `size/width`
  - `size/height`
  - `size/depth` (use available image channels or a default if unknown)
  - repeated `object`
  - `object/name`
  - `bndbox/xmin,ymin,xmax,ymax`
- If XML exists beside the image (same basename, `.xml`), load it.
- If XML does not exist, initialize empty annotations for the image.
- XML is the source of truth in app logic.

5. YOLO TXT generation (derived)
- Implement generation of YOLO `.txt` from the in-memory/Pascal-VOC-derived annotations.
- Output format per line:
  - `class_id x_center y_center width height`
  - normalized to [0,1]
- Generate/update `.txt` next to image using same basename.
- If image has no objects, write empty file

6. `classes.txt` management
- At the selected root directory level, maintain `classes.txt`.
- On save, add any new labels not already present.
- Preserve stable order so IDs remain deterministic.
- IDs are zero-based and correspond to line order in `classes.txt`.

7. Save / navigation behavior (Stage 001 subset)
- Add toolbar buttons for:
  - Previous image
  - Next image
  - Save
- Add keyboard shortcuts:
  - Space: save current XML + YOLO + classes, then move to next image
  - Left arrow: previous image (no save)
  - Right arrow: next image (no save)
- If full keyboard event routing is difficult in Stage 001, implement menu commands with shortcuts and note limitations in comments/TODOs.

8. Unsaved annotations list (foundation only)
- Track dirty state per image in memory.
- Show dirty images in the `Unsaved Annotations` sidebar section.
- Clicking an unsaved item navigates to that image and loads the in-memory unsaved state (not re-read from disk).

9. Codebase cleanup
- Remove or deprecate template/demo-only code paths that are no longer used.
- Preserve buildability.
- Keep changes scoped and staged; do not redesign unrelated template features.

Implementation constraints:
- Prefer Apple frameworks only (SwiftUI/AppKit/Foundation/CoreGraphics/ImageIO).
- Use a hybrid SwiftUI + AppKit approach only if needed in Stage 001; plain SwiftUI image display is acceptable for now.
- Keep the annotation editing canvas interactive features for Stage 002.
- Add small focused types/files rather than large monolithic files.
- Include a short `TODO(Stage 002)` marker where interactive box editing will connect.

Validation:
- Build should succeed (or be very close, if signing prevents it).
- Opening a directory with sample images should populate the sidebar.
- Selecting an image should display it.
- Save should create/update `.xml`, `.txt`, and root `classes.txt`.
- Navigation buttons should move between images.

At the end, summarize:
- files changed
- known gaps left intentionally for Stage 002
- quick manual test steps
```

---

## Stage 002 Prompt (AI execution prompt)

```md
Implement Stage 002 for `ImageAnnotationTool`.

Goal:
- Add an interactive annotation canvas for drawing, selecting, moving, resizing, and relabeling bounding boxes.

Requirements:
- Use a custom AppKit `NSView` bridged with `NSViewRepresentable` for the annotation canvas.
- Display the image and overlay bounding boxes.
- Support:
  - crosshair cursor in draw mode
  - click-drag to create rectangle
  - selection of a box
  - drag box to move
  - drag handles to resize
  - visible label banner at top of box (similar to `/Users/dpd/Documents/projects/github/ImageAnnotationTool/VibeCodingPrompts/bounding-box.png`)
  - clicking label banner to edit label text
- Maintain coordinate transforms correctly for zoom/fit scaling.
- Update dirty state when edits occur.
- Keep Pascal VOC model as source of truth (in-memory model -> save pipeline from Stage 001).

Nice-to-have (only if easy):
- zoom in/out and pan
- multi-select deferred to later

Validation:
- Manual test creating, moving, resizing, relabeling boxes on jpg/png files.
```

---

## Stage 003 Prompt (AI execution prompt)

```md
Implement Stage 003 for `ImageAnnotationTool`.

Goal:
- Make save/autosave/navigation behavior robust and aligned with the product requirements.

Requirements:
- Spacebar: save current image annotations (`.xml`, `.txt`, `classes.txt`) then move next
- Left/Right arrows: move without saving
- Warn on losing unsaved changes when navigating away if behavior would discard in-memory edits
- Unsaved annotations list must remain accurate during all edit/save/navigation paths
- Clicking unsaved item restores in-memory edits for that image
- Add explicit "Save All Unsaved" command
- Ensure XML and YOLO writes are atomic enough to avoid corruption (temp file + replace if practical)

Validation:
- Repro steps for dirty/clean transitions and file outputs.
```

---

## Stage 004 Prompt (AI execution prompt)

```md
Implement Stage 004 for `ImageAnnotationTool`.

Goal:
- Improve UX and robustness for real annotation sessions.

Requirements:
- Handle large directories (thousands of images) without blocking UI:
  - background scan
  - progress indicator or status text
- Better error reporting for malformed XML / unreadable images
- Optional filtering/search in Files sidebar
- Persist recent directory (if feasible)
- Add basic undo/redo integration for annotation edits
- Improve toolbar polish (icons/tooltips/state disabled when unavailable)

Validation:
- Stress test with nested folders and mixed file types.
```

---

## Stage 005 Prompt (AI execution prompt)

```md
Implement Stage 005 for `ImageAnnotationTool`.

Goal:
- Add confidence via tests and fixtures before wider usage.

Requirements:
- Add test fixtures for:
  - Pascal VOC XML parse/write roundtrip
  - YOLO conversion math
  - `classes.txt` deterministic ID mapping
- a small sample dataset folder is not needed. Can use images and XML for testing in `/Users/dpd/Documents/projects/communitycats/imagebyclass` 
- Document manual QA checklist in README or a dedicated QA doc

Validation:
- Tests pass locally.
```

---

## Research Notes / Source Links (for review)

- Apple `NSViewRepresentable` (SwiftUI bridge to AppKit views): https://developer.apple.com/documentation/swiftui/nsviewrepresentable
- Apple `XMLParser` (Foundation XML parsing): https://developer.apple.com/documentation/foundation/xmlparser
- Apple File System Programming Guide (Open/Save Panels, `NSOpenPanel` directory selection): https://developer-mdn.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/UsingtheOpenandSavePanels/UsingtheOpenandSavePanels.html
- Ultralytics YOLO dataset docs (YOLO txt format details, normalized `class x_center y_center width height`): https://docs.ultralytics.com/datasets/detect/
- CVAT Pascal VOC docs (XML-based format overview and filename tag matching expectations): https://docs.cvat.ai/docs/dataset_management/formats/format-voc/

## Suggested Review Focus Before Coding

- Confirm whether Stage 001 should include a simple non-interactive image viewer only (recommended), or a minimal click-to-add-box prototype.
- Confirm desired behavior when an image has zero objects:
  - no `.txt` file
  - or empty `.txt` file
- Confirm whether XML and TXT should be stored next to images (current plan assumes yes).
- Confirm whether to preserve template menu bar button features or remove them early.

