# Image Annotation Tool

`Image Annotation Tool` is a macOS app for bounding-box image annotation with Pascal VOC XML as the source of truth and YOLO export as derived output.

# License

This project continues under the MIT License. See `LICENSE` for full terms.

# Overview

Current functionality includes:

- Recursive directory scanning for `.jpg`, `.jpeg`, `.png`
- Collapsible file tree sidebar (collapsed by default)
- Interactive AppKit-backed annotation canvas (draw/select/move/resize boxes)
- Separate overlay label banner for box names (not part of recorded box geometry)
- Pascal VOC XML read/write
- YOLO `.txt` export generation
- Root-level `classes.txt` management with deterministic class IDs
- Unsaved annotations tracking and save-all
- Keyboard shortcuts for open/save/navigation
- Undo/redo for annotation edits
- Scan progress and error/warning reporting for malformed XML/unreadable images

# Credits

- Maintainer: David P. Discher
- Large parts of this app were developed with OpenAI Codex (Codex app).

# QA / Validation

- Manual checklist: `QA/Manual-QA-Checklist.md`
- Stage 005 local validation script: `./Tests/run-stage005-validation.sh`
