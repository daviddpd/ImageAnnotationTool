# App Store Connect Metadata Template (macOS)

Use this file to prepare the values you will enter in App Store Connect for `Image Annotation Tool`.

## App Information

- App Name: `Image Annotation Tool`
- Primary Language: `English (U.S.)` (adjust if needed)
- Bundle ID: `com.yourcompany.image-annotation-tool` (must match Xcode target)
- SKU: `image-annotation-tool-macos` (example)
- Category: `Graphics & Design` (recommended for this app)

## App Store Listing Text

- Subtitle (optional):
  - Example: `Pascal VOC + YOLO image annotation`
- Promotional Text (optional):
  - Example: `Annotate images with native macOS tools and export Pascal VOC XML and YOLO TXT.`
- Description:
  - Draft:
    - `Image Annotation Tool is a native macOS application for bounding-box image annotation.`
    - `Open a folder of JPG/PNG images, draw and edit boxes, and export Pascal VOC XML (source of truth) with YOLO TXT output generated automatically.`
    - `Features include recursive file browsing, an unsaved annotations queue, keyboard-driven navigation, and classes.txt management for stable YOLO class IDs.`
- Keywords:
  - `annotation,images,yolo,pascal voc,bounding box,dataset,computer vision`
- Support URL: `https://...` (required)
- Marketing URL: `https://...` (optional)
- Privacy Policy URL: `https://...` (required for App Store distribution)

## Version Information (for each release)

- Version: `1.0` (match `MARKETING_VERSION`)
- Build: `1` (match `CURRENT_PROJECT_VERSION`)
- What’s New in This Version:
  - Example:
    - `Initial release of Image Annotation Tool for macOS.`
    - `Create and edit bounding boxes, save Pascal VOC XML, and generate YOLO TXT + classes.txt.`

## Screenshots / Media (macOS)

Prepare screenshots for the required Mac display sizes supported by your App Store Connect setup.

Suggested screenshots:
- File tree + canvas view
- Box editing with label banner + bottom inspector
- Unsaved annotations workflow
- Settings (font size control)
- Large dataset tree/search (optional)

## App Privacy / Data Collection

Document what the app collects (if anything).

Current expected answer (if the app remains fully local and no telemetry is added):
- Data Not Collected

Re-check before submission if you add:
- analytics
- crash reporting
- update checks
- network sync

## Export Compliance

Likely answer is typically `No` for standard local annotation tooling with no custom encryption features, but verify at submission time based on your exact dependencies/features.

## Review Notes (recommended)

Include a short note for the reviewer:

- `This app is a local macOS image annotation tool. It operates on user-selected folders and saves annotation files (.xml/.txt/classes.txt) alongside images.`
- `No account login is required.`

## Pre-Submission Checklist

- Bundle ID in Xcode matches App Store Connect app record
- Version/build numbers updated
- App icon displays correctly in Xcode archive/export
- Sandbox enabled with user-selected read/write file access
- Privacy policy URL is valid
- Screenshots prepared and legible
- Release build archived and exported successfully
- Upload validation passes

