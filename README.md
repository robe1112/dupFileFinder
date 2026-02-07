# dupFileFinder

A macOS duplicate file finder and remover built with SwiftUI.

## Features

- **Exact duplicates**: Content-based (SHA-256) duplicate detection. Files are grouped by size first, then hashed for accuracy.
- **Similar images**: Vision-based similar image detection. Find images that look alike but differ in format, resolution, or light editing. Sensitivity: Strict / Medium / Loose.
- **Folder selection**: Add one or more folders to scan. Exclusions and filters (minimum size, extensions) in scan options.
- **Results**: Duplicate groups with path, size, and date. Per-group “keep” selection; preview files with default app.
- **Smart selection**: Keep newest, oldest, shortest path, or prefer file in Documents in each group.
- **Safe removal**: Move to Trash by default. Optional backup to a folder before removing. Undo last removal (put back from Trash).
- **Accessibility**: Labels and hints for VoiceOver and keyboard shortcuts (e.g. Cmd+O Add Folders, Cmd+Return Scan).

## Build

Open `dupFileFinder.xcodeproj` in Xcode and build for macOS, or:

```bash
xcodebuild -scheme dupFileFinder -destination 'platform=macOS' build
```

## Requirements

- macOS (SwiftUI, AppKit, Vision, CryptoKit)
- Xcode with macOS SDK


# This is a test