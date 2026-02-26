# ImageAnnotationTool – Release Guide

This document summarizes how to finish configuration and ship the app via a notarized DMG on GitHub Releases and to the Mac App Store.

## One-time Xcode setup

1. Open the project in Xcode.
2. Select the macOS app target:
   - General → Display Name: Image Annotation Tool (or desired name)
   - General → Bundle Identifier: set to your reverse-DNS id (e.g. `com.yourcompany.image-annotation-tool`).
   - Signing & Capabilities → Team: select your Apple Developer team.
   - Signing & Capabilities → Add Capability: App Sandbox.
   - In App Sandbox, enable: File Access → User Selected File → Read/Write.
   - Code Signing Entitlements (Build Settings): set to `ImageAnnotationTool.entitlements`.
   - App Icons: ensure the asset catalog contains `Assets.xcassets/AppIcon.appiconset` and the target uses `AppIcon`.
3. If you want a custom icon, place a 1024×1024 PNG somewhere in the repo (e.g. `icon-base-1024.png`). Otherwise, a clean fallback symbol icon will be generated.

## Generate App Icon images (do this now)
You have two ways to actually generate the icon PNGs in `Assets.xcassets/AppIcon.appiconset`.

### Option A — Local (quickest)

- With a custom base image (recommended):
- `./scripts/release/generate-app-iconset.sh /absolute/path/to/icon-base-1024.png`
- The script will resize and populate all required macOS icon PNGs and rewrite `Contents.json`.

### Option B — Generated fallback icon (already supported)

- `./scripts/release/generate-app-iconset.sh`
- This creates a clean built-in fallback icon (annotation-themed) and populates the icon set.

## Release scripts included in this repo

- `scripts/release/generate-app-iconset.sh`
  - Generates all `AppIcon.appiconset` PNGs
- `scripts/release/archive-app.sh`
  - Creates a signed Xcode archive (App Store or Developer ID)
- `scripts/release/export-archive.sh`
  - Exports the archive using `ExportOptions-AppStore.plist` or `ExportOptions-DeveloperID.plist`
- `scripts/release/create-dmg.sh`
  - Packages a `.app` into a DMG
- `scripts/release/notarize-dmg.sh`
  - Submits a DMG to Apple notarization and staples the result
- `scripts/release/upload-github-release.sh`
  - Creates/uploads a GitHub Release asset using `gh`

## Credentials / identifiers you still need

These cannot be completed from this environment:

- Apple Developer Team ID
- App Store Connect app record (Bundle ID / SKU)
- Code signing certificates and private keys
  - `Apple Distribution` (Mac App Store)
  - `Developer ID Application` (GitHub DMG)
- Notarization credentials (either `notarytool` keychain profile or Apple ID + app-specific password)
- Valid Support URL + Privacy Policy URL (for App Store Connect)

## Suggested signing setup in Xcode (before running release scripts)

1. In Xcode, set your `Team` on the target.
2. Set your final Bundle ID.
3. Confirm `Signing Certificate` resolves automatically (or your manual identity if you prefer manual signing).
4. Confirm the app builds and runs signed on your machine.
5. Update version/build numbers (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).

## App Store Connect metadata prep

- Use this template:
  - `docs/release/AppStoreConnect-Metadata-Template.md`
- Prepare screenshots and listing text before archive/upload.

## Build and export (Mac App Store)

Example:

```bash
# Replace placeholders
TEAM_ID=YOURTEAMID
BUNDLE_ID=com.yourcompany.image-annotation-tool

./scripts/release/archive-app.sh app-store "$TEAM_ID" "$BUNDLE_ID"

# Use the resulting .xcarchive path from the script output:
./scripts/release/export-archive.sh app-store /absolute/path/to/ImageAnnotationTool.xcarchive "$TEAM_ID"
```

Notes:
- `ExportOptions-AppStore.plist` contains `TEAMID_PLACEHOLDER`; the export script can patch it when a team ID is provided.
- The App Store export typically produces a signed `.pkg` for upload.

## Upload to App Store Connect

You can upload using Xcode Organizer (recommended) or Apple transport tools after export.

Checklist:
- App record exists in App Store Connect
- Bundle ID matches exactly
- Version/build numbers are new
- Screenshots + metadata are complete
- Privacy info is completed

## Build a signed Developer ID app + DMG (GitHub Release path)

Example:

```bash
TEAM_ID=YOURTEAMID
BUNDLE_ID=com.yourcompany.image-annotation-tool

./scripts/release/archive-app.sh developer-id "$TEAM_ID" "$BUNDLE_ID"
./scripts/release/export-archive.sh developer-id /absolute/path/to/ImageAnnotationTool.xcarchive "$TEAM_ID"

# Then package the exported .app into a DMG
./scripts/release/create-dmg.sh /absolute/path/to/ImageAnnotationTool.app
```

## Notarize + staple the DMG

Option A (keychain profile, recommended):

```bash
export NOTARYTOOL_PROFILE=your-notary-profile
./scripts/release/notarize-dmg.sh /absolute/path/to/ImageAnnotationTool.dmg
```

Option B (Apple ID + app-specific password):

```bash
export APPLE_ID=you@example.com
export TEAM_ID=YOURTEAMID
export APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
./scripts/release/notarize-dmg.sh /absolute/path/to/ImageAnnotationTool.dmg
```

## Upload notarized DMG to GitHub Releases

```bash
./scripts/release/upload-github-release.sh v1.0.0 /absolute/path/to/ImageAnnotationTool.dmg
```

Requires:
- `gh` installed and authenticated (`gh auth login`)

## Final pre-publish checklist

- [ ] App icon is complete and visible in Finder / app bundle
- [ ] Bundle ID + Team ID final
- [ ] Version/build bumped
- [ ] Signed archive succeeds
- [ ] App Store export succeeds
- [ ] Developer ID export succeeds
- [ ] DMG created
- [ ] DMG notarized + stapled
- [ ] GitHub Release uploaded
- [ ] App Store Connect metadata/screenshots complete
- [ ] App Store upload succeeds and passes processing

