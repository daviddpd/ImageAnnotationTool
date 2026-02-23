# Final AI Prompt (Stage 003): Robustness, Large-Tree Performance, QA, and Final Cleanup

Use this after Stage 002 to finish behavior, scalability, validation assets, and documentation cleanup.

```md
You are implementing the final stabilization stage for `ImageAnnotationTool`.

Focus on:
- save/navigation robustness
- large-directory performance
- startup behavior correctness
- validation fixtures/scripts
- README/license cleanup
- naming cleanup (no template holdovers)

Follow:
- `VibeCodingPrompts/101-final-ai-requirements.md`
- `VibeCodingPrompts/102-final-ai-architecture-and-constraints.md`

Requirements:

1. Save/navigation robustness
- Add/verify commands:
  - `Save All Unsaved` (`Cmd+Shift+S`)
- `Space` = save current then next, but advance only if save succeeds
- Left/Right arrows = navigate without saving
- Dirty state and `Unsaved Annotations` list must remain correct across edits/saves/navigation
- Clicking an unsaved item must restore/select the in-memory unsaved annotations

2. Unsaved-protection prompts
- Warn when opening a new directory if there are unsaved changes:
  - save all + continue
  - discard + continue
  - cancel
- Warn on app quit if there are unsaved changes:
  - save all + quit
  - discard + quit
  - cancel

3. Atomic save writes
- Use temp file + replace pattern for XML, YOLO TXT, and `classes.txt` writes
- Clear dirty state only after successful writes

4. Startup behavior (important final choice)
- Disable recent-directory restore / auto-reopen on launch
- App should always start in “Open Directory…” state
- Reason: avoid false startup “No supported images were found...” issues on otherwise valid directories

5. Remove unwanted UI features
- Remove any “Always on Top” UI/menu option and main-window hook if present

6. Large-directory performance: Files tree
- Replace any SwiftUI `DisclosureGroup` tree with AppKit `NSOutlineView` via `NSViewRepresentable`
- This is required for large folder performance (e.g., 13,000+ files in one folder)
- Default all directories collapsed on load
- Preserve expansion state during normal use
- During active search, auto-expand matching branches

7. File tree data performance (do both, no paging)
- Precompute cached file-tree snapshot/index after directory scan (off main thread)
- Keep a full tree snapshot and a displayed (possibly filtered) snapshot
- Debounce search/filter (e.g., 200ms) and filter off main thread
- Publish filtered results back on main thread
- Add cheap versioning or equivalent so tree structure reloads are separated from decoration updates
- Decor updates (dirty/warning markers) should refresh visible rows only, not rebuild the whole tree
- Do NOT implement paging/progressive rendering
- Do NOT preload all images

8. Additional polish / correctness
- Ensure overlay label banner remains separate from actual box geometry in saved XML
- Ensure selected-box controls live in a fixed panel and do not resize the image viewport
- Ensure filename is shown in one top location only (no duplicate pane header)

9. Naming cleanup (template holdouts)
- Rename leftover template-ish files/types/functions to descriptive names
- If working in a Git repo and renaming existing files, use `git mv` so history is retained
- Update all references + Xcode project file entries

10. Documentation + license finalization
- README:
  - no remaining references to the original starter template
  - current features and usage
  - MIT license section
  - `David P. Discher` credit
  - OpenAI Codex assistance credit line
- LICENSE:
  - MIT
  - `David P. Discher`

11. Validation assets (Stage 005 style)
- Add lightweight fixture-based export validation (script is acceptable, XCTest optional):
  - Pascal VOC parse/write roundtrip
  - YOLO conversion math fixture
  - `classes.txt` deterministic merge fixture
- Add a manual QA checklist covering:
  - open directory
  - tree expand/search
  - canvas box editing
  - save/save-all
  - quit/open prompts
  - large folder behavior

12. Build + verification
- Run `xcodebuild` macOS build (codesign disabled okay)
- Run the validation script
- Summarize:
  - files changed
  - performance rationale
  - known remaining gaps
  - manual test steps
```

