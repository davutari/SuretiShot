# SuretiShot

Ultra-fast macOS menu bar screenshot and screen recording app with OCR-based smart naming.

## Features

- **Screenshot Modes**
  - Full screen capture
  - Selected area capture
  - Active window capture

- **Screen Recording**
  - Start/stop via keyboard shortcuts
  - High-quality H.264 encoding
  - Saves as .mov files

- **Smart Naming (OCR-Based)**
  - Vision framework text recognition
  - Automatic app detection
  - Semantic hints (login, error, code, invoice, etc.)
  - Deterministic filename format: `YYYY-MM-DD_HH-MM_AppName_Hint.png`

- **Built-in Gallery**
  - Beautiful grid view with thumbnails
  - Quick preview for images and videos
  - Search, filter, and sort
  - Reveal in Finder, copy, rename, delete

- **Customizable Shortcuts**
  - Global hotkeys for all capture modes
  - Conflict detection with macOS system shortcuts

- **Privacy-First**
  - All text recognition happens on-device (Apple Vision framework)
  - No cloud calls
  - Security-scoped bookmarks for folder access

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)

## Building

### Option 1: Using XcodeGen

1. Install XcodeGen:
```bash
brew install xcodegen
```

2. Generate Xcode project:
```bash
cd SuretiShot
xcodegen generate
```

3. Open and build:
```bash
open SuretiShot.xcodeproj
```

### Option 2: Manual Xcode Project

1. Open Xcode
2. Create new macOS App project named "SuretiShot"
3. Copy all source files from `SuretiShot/` folder
4. Configure the target:
   - Set deployment target to macOS 13.0
   - Add `LSUIElement = YES` to Info.plist
   - Add required entitlements
   - Add privacy descriptions

## Project Structure

```
SuretiShot/
├── SuretiShotApp.swift          # App entry point
├── App/
│   ├── AppDelegate.swift        # Main app delegate
│   ├── MenuBarController.swift  # NSStatusItem management
│   └── GalleryWindowController.swift
├── Models/
│   ├── CaptureType.swift        # Capture mode enums
│   ├── MediaItem.swift          # Gallery item model
│   ├── ShortcutConfiguration.swift
│   └── SemanticHint.swift       # AI hint definitions
├── Services/
│   ├── CaptureService.swift     # Screenshot logic
│   ├── ScreenRecordingService.swift
│   ├── ShortcutManager.swift    # Global hotkeys
│   ├── FolderAccessManager.swift # Security-scoped bookmarks
│   ├── GalleryService.swift     # File management
│   ├── ThumbnailProvider.swift  # QuickLook thumbnails
│   ├── FolderWatcher.swift      # DispatchSource monitoring
│   ├── TextAnalyzer.swift       # Vision OCR
│   └── FileNamingEngine.swift   # Deterministic naming
├── ViewModels/
│   ├── SettingsViewModel.swift
│   └── GalleryViewModel.swift
├── Views/
│   ├── SettingsView.swift
│   ├── ShortcutRecorderView.swift
│   ├── GalleryView.swift
│   ├── GalleryGridView.swift
│   └── MediaPreviewView.swift
├── Utilities/
│   ├── Constants.swift
│   └── PermissionManager.swift
└── Resources/
    └── Assets.xcassets/
```

## Architecture

The app follows MVVM architecture:

- **Models**: Data structures and enums
- **Services**: Business logic, isolated and testable
- **ViewModels**: State management with `@Published` properties
- **Views**: SwiftUI views, declarative UI

### Key Services

| Service | Responsibility |
|---------|---------------|
| `CaptureService` | Screenshots using ScreenCaptureKit |
| `ScreenRecordingService` | Video recording with AVAssetWriter |
| `ShortcutManager` | Global hotkeys via Carbon Events |
| `FolderAccessManager` | Security-scoped bookmarks |
| `GalleryService` | File operations and indexing |
| `ThumbnailProvider` | QuickLookThumbnailing integration |
| `FolderWatcher` | DispatchSource file monitoring |
| `TextAnalyzer` | Vision framework OCR |
| `FileNamingEngine` | Deterministic filename generation |

## Permissions

The app requires:

1. **Screen Recording** - For capturing screenshots and recordings
2. **Accessibility** (optional) - For global keyboard shortcuts

These are requested automatically on first use.

## Sandbox Compliance

The app is fully sandbox-compliant:

- Uses security-scoped bookmarks for folder access
- Persists user folder selection across launches
- No hardcoded paths

## Keyboard Shortcuts (Default)

| Action | Shortcut |
|--------|----------|
| Full Screen | ⇧⌘1 |
| Selected Area | ⇧⌘2 |
| Active Window | ⇧⌘3 |
| Start Recording | ⇧⌘5 |
| Stop Recording | ⇧⌘6 |

All shortcuts are customizable in Settings.

## Privacy

- **No cloud calls**: All text recognition uses Apple's on-device Vision framework
- **No data collection**: Screenshots never leave your device
- **Transparent storage**: Files saved only to your selected folder

## Technical Notes

### Screen Capture

Uses `ScreenCaptureKit` (macOS 12.3+) for:
- High-performance capture
- Proper handling of HDR/wide color
- Retina display support

### OCR Analysis

Uses `VNRecognizeTextRequest` with:
- Accurate recognition level
- Language correction enabled
- Multi-language support (English, Turkish)

### Thumbnail Generation

Uses `QLThumbnailGenerator` for:
- Consistent thumbnails across file types
- Background generation
- Memory-efficient caching

### File Monitoring

Uses `DispatchSource.makeFileSystemObjectSource` for:
- Low-overhead monitoring
- Automatic gallery refresh
- Debounced updates

## License

MIT License - See LICENSE file for details.
