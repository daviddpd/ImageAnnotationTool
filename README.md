# Image Annotation Tool

`Image Annotation Tool` is a macOS app project based on the `swift-macos-template` repository (also known as "Sidebar App").

The app-specific functionality is still being defined. For now, this repository keeps the template's SwiftUI macOS app structure and is being renamed/reworked as the foundation for `ImageAnnotationTool`.

# License

This project continues under the MIT License. See `LICENSE` for full terms.

# Overview

This codebase currently includes the original template's macOS SwiftUI scaffolding, including:

- A sidebar-based main window layout.
- A menu bar button with left-click popup and right-click menu behavior.
- Search UI examples in the sidebar and toolbar.
- Drag-and-drop example support in a detail pane.
- A custom About window and Attributions window in SwiftUI.
- Custom app menu commands.
- Export command scaffolding.
- A tabbed settings window.

Template origin screenshot (from the original Sidebar App template):

![Image Annotation Tool template origin screenshot](https://user-images.githubusercontent.com/384210/169694882-42e7bb8c-c576-42a8-a6ac-bb2794c76f95.png)

# Credits

- Original template foundation: Simon Weniger (`swift-macos-template` / "Sidebar App")
- Large parts of this app were developed with OpenAI Codex (Codex app).

# QA / Validation

- Manual checklist: `QA/Manual-QA-Checklist.md`
- Stage 005 local validation script: `./Tests/run-stage005-validation.sh`
