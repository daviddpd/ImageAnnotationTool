# Final AI Prompt (One-Shot Rebuild): Recreate ImageAnnotationTool from Blank Directory

This is a single prompt intended for a fresh GPT-5.3 Codex session to recreate the app with high confidence. It references the final requirements/architecture docs but is self-contained enough to run directly.

```md
You are building a macOS-native app named `ImageAnnotationTool` (`Image Annotation Tool`) from a blank directory in a new Xcode SwiftUI app project.

Build the app end-to-end (foundation + AppKit canvas + robustness/performance + docs/license cleanup) in one pass if possible.

Primary references (follow these as source of truth):
- `VibeCodingPrompts/101-final-ai-requirements.md`
- `VibeCodingPrompts/102-final-ai-architecture-and-constraints.md`

High-level product:
- Native macOS image annotation tool
- Annotates `.jpg/.jpeg/.png`
- Pascal VOC XML is source of truth
- YOLO TXT is derived
- root `classes.txt` maintained for class mappings

Critical final behaviors to implement (do not miss):

1. App identity + docs/license
- App name `ImageAnnotationTool`, display name `Image Annotation Tool`
- MIT License with `David P. Discher`
- README describes current app (no starter template references)
- README includes OpenAI Codex assistance credit line

2. Startup behavior
- Always start in initial open-directory state
- Do NOT auto-restore last opened directory

3. Directory scanning
- Recursive scan of `.jpg/.jpeg/.png` (case-insensitive)
- Scan progress/status UI
- No image preloading

4. Sidebar layout
- `Files` section + `Unsaved Annotations` section
- Sidebar search field
- Files tree must use AppKit `NSOutlineView` via `NSViewRepresentable` for large folders
- Default collapsed directories
- Search auto-expands matching branches

5. Large-folder performance design (required)
- Precompute cached file tree snapshot/index off main thread after scan
- Maintain full tree snapshot + displayed filtered snapshot
- Debounced async filtering (e.g., ~200ms)
- Separate structure reloads from row decoration updates (dirty/warning)
- Target visible-row refreshes for decorations
- No paging/progressive rendering

6. Main workspace
- Single image view at a time
- Filename/metadata shown in one top location only (no duplicate in image pane)
- Stable image viewport (no resizing/jump when selection changes)
- Fixed-height bottom inspector panel for selected box controls

7. Annotation canvas (AppKit)
- `NSView` canvas bridged into SwiftUI
- Draw/select/move/resize/delete boxes
- Crosshair cursor for drawing
- Large, readable label banner
- Label banner is UI-only and separate from actual box geometry
- Saved XML/YOLO coordinates must reflect only the true rectangle

8. File formats + save pipeline
- Load/write Pascal VOC XML beside image
- Generate YOLO TXT beside image
- Maintain root `classes.txt` (stable deterministic order, zero-based IDs)
- Atomic-ish writes (temp + replace) for XML/TXT/classes
- Dirty state tracked per image

9. Navigation + commands
- Toolbar: Open Directory, Previous, Save, Next, Save All Unsaved
- Shortcuts:
  - `Cmd+O`, `Cmd+S`, `Cmd+Shift+S`
  - `Space` save+next (advance only on save success)
  - Left/Right arrows navigate without saving

10. Unsaved behavior + prompts
- `Unsaved Annotations` list stays accurate
- Clicking unsaved item restores in-memory edits
- Prompt before open-new-directory if unsaved changes exist
- Prompt before quit if unsaved changes exist
- Save/discard/cancel choices

11. Cleanup constraints
- No “Always on Top” option
- No template/demo naming leftovers; use clear final names:
  - `AnnotationDataStore.swift`
  - `AnnotationWorkspacePane.swift`
  - `AnnotationCanvasView.swift`
  - `AnnotationCanvasNSView.swift`
  - `FilesSidebarSection.swift`
  - `UnsavedAnnotationsSidebarSection.swift`
  - `NavigationCommands.swift`

12. Validation deliverables
- `xcodebuild` build success (codesign disabled okay)
- lightweight export validation fixtures + script (Pascal VOC, YOLO, classes merge)
- manual QA checklist

Implementation guidance:
- Use SwiftUI for app shell and layout
- Use AppKit for canvas and file tree (`NSOutlineView`)
- Prefer Apple frameworks first (SwiftUI, AppKit, Foundation, CoreGraphics, ImageIO, UTType)
- Keep code organized in focused files
- Add small comments only where needed

Execution expectations:
- Implement directly (do not stop at planning)
- Run build validation
- Summarize changed files and any remaining gaps
```

