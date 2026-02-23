# Manual QA Checklist

## Scope

This checklist covers the current app state through Stage 004/005:

- directory scan and file discovery
- image navigation and selection
- bounding box create/select/move/resize/rename/delete
- save/export behavior (`.xml`, `.txt`, `classes.txt`)
- unsaved change prompts and recovery flows
- robustness on large folders / malformed files

## Preflight

- Build the app successfully in Xcode or via `xcodebuild`.
- Prepare a test folder with nested subfolders containing mixed `jpg`, `jpeg`, `png`, and non-image files.
- Optionally use `/Users/dpd/Documents/projects/communitycats/imagebyclass` for stress testing.

## Core Workflow

- Open a directory and confirm the UI remains responsive while scanning.
- Confirm scan progress/status appears in the toolbar/sidebar/footer during large scans.
- Confirm only supported image types are listed and nested folders are included.
- Select several images and confirm preview updates without duplicate filename headers.
- Draw a new box, move it, resize it, rename it, and delete it.
- Confirm the bottom inspector panel does not resize the image viewport when selection changes.
- Confirm overlay label text is easily readable at normal viewing size.

## Save / Export

- Press `Command-S` and confirm `<image>.xml`, `<image>.txt`, and root `classes.txt` are created/updated.
- Confirm `Space` saves and advances to the next image.
- Confirm left/right arrow navigation moves images without saving.
- Confirm YOLO output uses normalized values and matches labels in `classes.txt`.
- Confirm images with zero boxes produce an empty `.txt` file.

## Unsaved / Recovery

- Make edits and confirm the image appears in `Unsaved Annotations`.
- Click an unsaved item and confirm in-memory edits are restored.
- Use `Command-Shift-S` and confirm all unsaved entries clear.
- Make unsaved edits and open another directory; verify the save/discard/cancel prompt.
- Make unsaved edits and quit the app; verify the quit warning and save/discard behavior.

## Undo / Redo

- Draw or move a box, then use `Edit > Undo` and confirm the change reverts.
- Use `Edit > Redo` and confirm the change reapplies.
- Rename and delete a box, then verify undo/redo also works for those actions.

## Error Handling

- Open/select an image with malformed or partial XML (edit one manually) and confirm the app shows a warning instead of crashing.
- Confirm the file row indicates an annotation warning and the workspace warning text is visible.
- Confirm unreadable or unsupported files do not block the directory scan.

## Stage 005 Validation Script

- Run `./Tests/run-stage005-validation.sh`.
- Confirm it prints pass lines for Pascal VOC roundtrip, YOLO math, and `classes.txt` deterministic merge.
