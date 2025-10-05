# Getting Started with VibeNotify

## Overview

VibeNotify is a lightweight, customizable notification overlay library for macOS 12+. It provides an elegant way to display notifications with:

- Multiple presentation modes (full-screen, banner, toast)
- SwiftDialog-inspired API
- SVG vector graphics support
- Smooth SwiftUI animations
- Extensible architecture for future animation engines (Lottie, Rive)

## Project Structure

```
VibeNotify/
├── Sources/
│   └── VibeNotify/
│       ├── API/
│       │   └── VibeNotify.swift          # Main API with builder pattern
│       ├── Core/
│       │   └── OverlayWindowManager.swift # NSWindow management
│       ├── Models/
│       │   └── NotificationContent.swift  # Data models
│       └── Views/
│           ├── StandardNotificationView.swift  # Standard notification UI
│           └── SVGNotificationView.swift       # SVG-based notification UI
├── VibeNotifyDemo/                       # Demo application
├── Package.swift
└── README.md
```

## Quick Start

### 1. Build the Library

```bash
cd /path/to/VibeNotify
swift build
```

### 2. Add to Your Project

In your `Package.swift`:

```swift
dependencies: [
    .package(path: "/path/to/VibeNotify")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["VibeNotify"]
    )
]
```

### 3. Basic Usage

```swift
import VibeNotify

// Simple success notification
VibeNotify.shared.success(message: "Task completed!")

// Custom notification
VibeNotify.shared.show(
    title: "Welcome",
    message: "Getting started with VibeNotify",
    icon: .success,
    presentationMode: .banner(edge: .top, height: 120)
)
```

## Core Components

### 1. OverlayWindowManager

Manages NSWindow overlays with customizable window levels and presentation modes.

**Key Features:**
- Always-on-top windows (`.floating`, `.popup`, `.screenSaver`)
- Multiple presentation modes
- Transparent/translucent backgrounds
- Smooth fade animations

### 2. VibeNotify API

Main entry point for showing notifications.

**Methods:**
- `show(...)` - Show standard notification
- `showSVG(...)` - Show SVG-based notification
- `showCustom(...)` - Show custom SwiftUI view
- `success(...)`, `error(...)`, `warning(...)`, `info(...)` - Convenience methods
- `builder()` - Declarative builder API

### 3. Presentation Modes

```swift
// Full screen overlay
.presentationMode(.fullScreen)

// Top banner (height: 120)
.presentationMode(.banner(edge: .top, height: 120))

// Bottom banner
.presentationMode(.banner(edge: .bottom, height: 100))

// Toast notification (corner positioning)
.presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))

// Custom positioning
.presentationMode(.custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300)))
```

### 4. Window Levels

Control z-order of notifications:

```swift
.windowLevel(.normal)      // Standard window level
.windowLevel(.floating)    // Above normal (default)
.windowLevel(.popup)       // Above floating
.windowLevel(.screenSaver) // Highest
```

## Examples

### Success Notification with Auto-Dismiss

```swift
VibeNotify.shared.success(
    message: "Operation completed successfully!"
) // Auto-dismisses in 3 seconds
```

### Error with Manual Dismiss

```swift
VibeNotify.shared.error(
    title: "Error",
    message: "Something went wrong",
    buttons: [
        StandardNotification.Button(title: "Retry", style: .primary) {
            retryOperation()
        },
        StandardNotification.Button(title: "Cancel", style: .secondary) {
            // Handle cancel
        }
    ]
)
```

### Builder API

```swift
VibeNotify.builder()
    .title("Confirm Delete")
    .message("Are you sure you want to delete this item?")
    .icon(.warning)
    .button(StandardNotification.Button(title: "Delete", style: .destructive) {
        performDelete()
    })
    .button(StandardNotification.Button(title: "Cancel", style: .secondary) {
        print("Cancelled")
    })
    .presentationMode(.banner(edge: .top, height: 180))
    .show()
```

### Custom SwiftUI View

```swift
VibeNotify.shared.showCustom(
    presentationMode: .fullScreen,
    windowLevel: .floating
) {
    ZStack {
        Color.black.opacity(0.5)

        VStack(spacing: 20) {
            Text("Custom Overlay")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Button("Dismiss") {
                VibeNotify.shared.dismissAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

### SVG Notification

```swift
VibeNotify.shared.showSVG(
    svgPath: "/path/to/icon.svg",
    title: "Vector Graphics",
    message: "Rendered with SVGView",
    svgSize: CGSize(width: 200, height: 200),
    interactive: true,
    presentationMode: .toast(corner: .topRight, size: CGSize(width: 350, height: 400))
)
```

## Customization

### Custom Styles

```swift
let customStyle = StandardNotification.Style(
    backgroundColor: Color.blue.opacity(0.1),
    cornerRadius: 20,
    padding: 30,
    shadow: StandardNotification.Style.Shadow(
        color: .black.opacity(0.3),
        radius: 15,
        x: 0,
        y: 5
    )
)

VibeNotify.shared.show(
    title: "Custom",
    message: "Styled notification",
    style: customStyle
)
```

### Icon Types

```swift
.icon(.success)                          // ✓ Green checkmark
.icon(.error)                            // ✗ Red X
.icon(.warning)                          // ⚠ Orange triangle
.icon(.info)                             // ℹ Blue info
.icon(.system("star.fill"))              // SF Symbol
.icon(.image(NSImage(named: "icon")!))   // Custom NSImage
.icon(.svg("/path/to/icon.svg"))         // SVG file
```

## Architecture Notes

### Thread Safety

All public APIs are `@MainActor` annotated and should be called from the main thread:

```swift
Task { @MainActor in
    VibeNotify.shared.success(message: "Done!")
}
```

### Extensibility

The library uses protocol-based design for future extensibility:

```swift
public protocol NotificationContent {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
```

This makes it easy to add animation engines in the future:

```swift
// Future: Add Lottie support
struct LottieNotification: NotificationContent {
    let animationName: String
    var body: some View {
        LottieView(animation: animationName)
    }
}
```

## Testing

Run the demo application:

```bash
cd VibeNotifyDemo
swift run
```

The demo app showcases all notification types and presentation modes.

## Next Steps

1. **Add Lottie Support**: Integrate Lottie for After Effects animations
2. **Add Rive Support**: Integrate Rive for interactive animations
3. **Sound Effects**: Add audio feedback
4. **Haptic Feedback**: Integrate haptic responses
5. **Gesture Support**: Add swipe-to-dismiss
6. **Queue Management**: Implement notification queuing system

## Troubleshooting

### Build Errors

If you encounter build errors, ensure:
- macOS 12.0+ deployment target
- Swift 5.9+
- Xcode 15.0+

### Window Not Appearing

Check window level and presentation mode:
```swift
// Try higher window level
.windowLevel(.screenSaver)

// Ensure presentation mode is correct
.presentationMode(.fullScreen)
```

### SVGView Issues

Ensure SVG file path is absolute and file exists:
```swift
let svgPath = Bundle.main.path(forResource: "icon", ofType: "svg")!
VibeNotify.shared.showSVG(svgPath: svgPath, ...)
```

## Contributing

See the main README.md for contribution guidelines.

## License

MIT License - See LICENSE file for details.
