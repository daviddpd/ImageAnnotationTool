# Final AI Prompt (Stage 001): Foundation, Data Model, Formats, and Basic UI

Use this prompt in a new Codex session to build Stage 001 from a blank macOS app project.

```md
You are building a macOS-native app named `ImageAnnotationTool` (`Image Annotation Tool`) from a blank directory / new Xcode project.

Implement Stage 001 only: app foundation, directory scanning, file navigation, XML/YOLO/classes save pipeline, and core UI scaffolding.

Do not implement full interactive box editing yet (Stage 002 handles the AppKit canvas interactions).

Product requirements source:
- `VibeCodingPrompts/101-final-ai-requirements.md`
- `VibeCodingPrompts/102-final-ai-architecture-and-constraints.md`

Stage 001 requirements:

1. Project identity and docs
- App name/display name: `ImageAnnotationTool` / `Image Annotation Tool`
- README should describe the app (not a template) and include:
  - MIT license note
  - credit for `David P. Discher`
  - AI assistance note for OpenAI Codex
- LICENSE should be MIT with `David P. Discher`
- Do not add template references to README/docs.

2. App shell (SwiftUI)
- Create a SwiftUI macOS app shell with:
  - sidebar
  - main workspace pane
  - toolbar
  - command menus
- File/folder names should use final names (no template holdovers), e.g.:
  - `Export/AnnotationDataStore.swift`
  - `Panes/AnnotationWorkspacePane.swift`
  - `Sidebar/Sections/FilesSidebarSection.swift`
  - `Sidebar/Sections/UnsavedAnnotationsSidebarSection.swift`
  - `My Menu Commands/NavigationCommands.swift`

3. Data models and store
- Create models for:
  - `AnnotationBoundingBox` (`xMin`, `yMin`, `xMax`, `yMax`, `label`)
  - `ImageAnnotationDocument`
- Create a central store (`AnnotationAppStore` or equivalent) that manages:
  - root directory URL
  - recursive image file list
  - selected image URL
  - in-memory annotation docs keyed by image URL
  - dirty image set + unsaved list
  - classes list mapping via root `classes.txt`
  - errors/warnings/status messages
- Design it so Stage 002 can plug in an AppKit canvas without refactoring the save pipeline.

4. Directory open + recursive scan
- Add `Open Directory…` action using `NSOpenPanel`
- Recursively enumerate `.jpg`, `.jpeg`, `.png` (case-insensitive)
- Do not preload image pixels into memory
- Show progress/state while scanning
- Startup behavior:
  - DO NOT auto-restore prior directory on app launch
  - Always start with an open-directory prompt/button visible

5. Files sidebar (Stage 001 version)
- Add a `Files` sidebar section that lists discovered images and supports selection.
- It can start as a flat list in Stage 001, but structure the code so Stage 003 can replace it with an `NSOutlineView` tree without rewriting the store.
- Add sidebar search text state in the store (even if Stage 001 filtering is basic).

6. Unsaved Annotations sidebar (foundation)
- Add an `Unsaved Annotations` section showing dirty images.
- Clicking an unsaved item selects that image and uses in-memory state.

7. Main workspace (Stage 001)
- Display the selected image (SwiftUI `Image`/`NSImage` preview is acceptable in Stage 001).
- Show filename/metadata in one top location only (prefer top/title region).
- Do NOT duplicate the filename inside the image pane content area.
- Include placeholder area for future annotation canvas integration (`TODO(Stage 002)`).

8. Pascal VOC XML (source of truth)
- Implement read/write for minimum Pascal VOC fields:
  - `annotation`
  - `filename`
  - `size/width`, `size/height`, `size/depth`
  - repeated `object/name`
  - `bndbox/xmin`, `ymin`, `xmax`, `ymax`
- If XML exists beside image, load it.
- If missing, initialize empty annotations using image size metadata.
- XML is source of truth for loading/saving logic.

9. YOLO TXT generation (derived)
- Generate/update same-basename `.txt` beside each image on save.
- YOLO format: `class_id x_center y_center width height` normalized to `[0,1]`.
- If no objects exist, write empty `.txt`.

10. `classes.txt`
- Maintain root-level `classes.txt`.
- On save, merge in new labels, preserve stable order, zero-based IDs.

11. Toolbar + commands + shortcuts
- Toolbar: Open Directory, Previous, Save, Next
- Commands/shortcuts:
  - `Cmd+O` open
  - `Cmd+S` save current
  - `Space` save then next
  - Left arrow previous (no save)
  - Right arrow next (no save)
- `Space` should only advance if save succeeds.

12. Save safety
- Implement temp-file + replace (atomic-ish) writes for XML/TXT/classes if practical in Stage 001; otherwise leave a clear TODO for Stage 003 and implement then.

13. Exclusions for Stage 001
- No interactive drawing/move/resize yet
- No “Always on Top” feature
- No recent-directory restore feature

At the end:
- Build with `xcodebuild` (codesign disabled is fine)
- Summarize files created/changed
- Note intentional gaps for Stage 002
- Give quick manual test steps
```

