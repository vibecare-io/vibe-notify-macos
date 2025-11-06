# VibeNotify Documentation

A comprehensive guide to using VibeNotify - a lightweight, customizable notification overlay library for macOS built with SwiftUI.

## Table of Contents

- [Getting Started](#getting-started)
- [Builder API](#builder-api)
- [Customization Options](#customization-options)
- [SVG Support](#svg-support)
- [Advanced Features](#advanced-features)
- [API Reference](#api-reference)
- [Examples](#examples)

---

## Getting Started

### Installation

Add VibeNotify to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/vibecare-io/vibe-notify-macos.git", branch: "main")
]
```

### Quick Start

```swift
import VibeNotify

// Simple success notification
VibeNotify.shared.success(message: "Task completed!")

// Simple error notification
VibeNotify.shared.error(message: "Something went wrong")
```

---

## Builder API

The Builder API provides a declarative, chainable interface for creating notifications. This is the **recommended approach** for most use cases.

### Basic Builder Pattern

```swift
VibeNotify.builder()
    .title("Notification Title")
    .message("Your notification message")
    .icon(.success)
    .show()
```

### Builder with Buttons

```swift
VibeNotify.builder()
    .title("Confirm Action")
    .message("Do you want to proceed?")
    .icon(.warning)
    .button(
        StandardNotification.Button(
            title: "Confirm",
            style: .primary
        ) {
            print("Confirmed!")
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            print("Cancelled")
        }
    )
    .show()
```

### Builder with Auto-Dismiss

```swift
VibeNotify.builder()
    .title("Success")
    .message("Operation completed")
    .icon(.success)
    .autoDismiss(
        after: 3.0,
        showProgress: true
    )
    .show()
```

### Builder with Positioning

```swift
VibeNotify.builder()
    .title("Positioned Notification")
    .message("Located in the top-right corner")
    .icon(.info)
    .position(.topRight)
    .width(400)
    .height(200)
    .show()
```

### Builder with Transparency

```swift
VibeNotify.builder()
    .title("Transparent Effect")
    .message("Beautiful blur effect")
    .icon(.success)
    .transparent(
        true,
        material: .hudWindow
    )
    .position(.center)
    .width(450)
    .height(200)
    .show()
```

### Builder with Screen Blur

```swift
VibeNotify.builder()
    .title("Focus Mode")
    .message("Screen is blurred for focus")
    .icon(.info)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(
        true,
        material: .underWindowBackground
    )
    .dismissOnScreenTap(true)
    .show()
```

### Builder with Moveable Window

```swift
VibeNotify.builder()
    .title("Drag Me!")
    .message("Click and drag to reposition")
    .icon(.info)
    .position(.center)
    .width(400)
    .height(200)
    .moveable(true)
    .show()
```

### Builder with SVG

```swift
VibeNotify.builder()
    .svg(
        "/path/to/icon.svg",
        size: CGSize(width: 200, height: 200),
        interactive: true
    )
    .title("SVG Notification")
    .message("Rendered with SVGView")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 350, height: 400)))
    .show()
```

### Complete Builder Example

```swift
VibeNotify.builder()
    .title("Fully Customized")
    .message("All options enabled!")
    .icon(.warning)
    .position(.topRight)
    .width(500)
    .height(250)
    .moveable(true)
    .alwaysOnTop(true)
    .transparent(
        true,
        material: .hudWindow
    )
    .windowOpacity(0.95)
    .autoDismiss(
        after: 8.0,
        showProgress: true
    )
    .button(
        StandardNotification.Button(
            title: "OK",
            style: .primary
        ) {
            print("OK pressed")
        }
    )
    .show()
```

---

## Customization Options

### Window Positioning

Use 9 predefined positions to place notifications anywhere on screen:

```swift
VibeNotify.builder()
    .title("Positioned")
    .message("Try different positions")
    .icon(.info)
    .position(.center)        // or .topLeft, .top, .topRight
    .width(400)               // .left, .center, .right
    .height(200)              // .bottomLeft, .bottom, .bottomRight
    .show()
```

**Available Positions:**
- `.topLeft`, `.top`, `.topRight`
- `.left`, `.center` (also `.centre`), `.right`
- `.bottomLeft`, `.bottom`, `.bottomRight`

### Custom Sizing

Override default dimensions with custom width and height:

```swift
VibeNotify.builder()
    .title("Custom Size")
    .message("This notification is 600x400")
    .icon(.success)
    .position(.center)
    .width(600)
    .height(400)
    .show()
```

**Size Guidelines:**
- **Small**: 300x150 - Toast notifications
- **Medium**: 400x200 - Standard notifications
- **Large**: 600x400 - Rich content

### Moveable Windows

Allow users to drag notifications to reposition them:

```swift
VibeNotify.builder()
    .title("Drag Me!")
    .message("Click and drag anywhere")
    .icon(.info)
    .position(.topLeft)
    .width(350)
    .height(180)
    .moveable(true)
    .show()
```

### Transparent Backgrounds

Add macOS-native blur materials for beautiful transparent effects:

```swift
VibeNotify.builder()
    .title("Transparent")
    .message("Beautiful blur effect")
    .icon(.success)
    .transparent(
        true,
        material: .hudWindow
    )
    .show()
```

**Available Materials:**
- `.hudWindow` - Heads-up display style (default)
- `.popover` - Popover menu style
- `.sidebar` - Sidebar style
- `.menu` - Menu style
- `.selection` - Selection style
- `.titlebar` - Titlebar style
- `.underWindowBackground` - Under window style

### Window Opacity

Control overall window transparency (0.0 = invisible, 1.0 = opaque):

```swift
VibeNotify.builder()
    .title("Semi-Transparent")
    .message("70% opacity")
    .icon(.info)
    .windowOpacity(0.7)
    .show()
```

### Screen Blur

Blur the **entire screen** behind the notification for maximum focus:

```swift
VibeNotify.builder()
    .title("Focus Mode")
    .message("Everything else is blurred")
    .icon(.success)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(
        true,
        material: .underWindowBackground
    )
    .dismissOnScreenTap(true)
    .show()
```

**Difference:**
- **`transparent`** - Blurs notification background
- **`screenBlur`** - Blurs entire screen behind notification
- **Can use both together** for layered effects!

### Presentation Modes

Alternative to positioning - use predefined layouts:

```swift
// Full screen overlay
VibeNotify.builder()
    .title("Full Screen")
    .message("Covers entire screen")
    .presentationMode(.fullScreen)
    .show()

// Banner at top
VibeNotify.builder()
    .title("Banner")
    .message("Slides from top")
    .presentationMode(.banner(edge: .top, height: 120))
    .show()

// Toast in corner
VibeNotify.builder()
    .title("Toast")
    .message("Corner notification")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))
    .show()
```

---

## SVG Support

VibeNotify includes built-in SVG rendering using SVGView, supporting both local files and remote URLs.

### SVG as Icon

Use an SVG file as the notification icon:

```swift
VibeNotify.builder()
    .title("Custom Icon")
    .message("Using SVG for icon")
    .icon(.svg("/path/to/icon.svg"))
    .show()
```

### SVG Full Notification (Local File)

Display an SVG as the main notification content:

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animation.svg",
        size: CGSize(width: 200, height: 200),
        interactive: true
    )
    .title("Vector Graphics")
    .message("Full SVG notification")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 350, height: 400)))
    .moveable(true)
    .transparent(true)
    .show()
```

### SVG from URL (New!)

Load SVG from remote URLs:

```swift
// Using builder API
VibeNotify.builder()
    .svgURL(
        URL(string: "https://example.com/icon.svg")!,
        size: CGSize(width: 200, height: 200),
        interactive: false
    )
    .title("Remote SVG")
    .message("Loaded from URL")
    .show()

// Using direct API
VibeNotify.shared.showSVG(
    svgURL: URL(string: "https://example.com/icon.svg")!,
    title: "Remote Icon",
    message: "From CDN"
)
```

### SVG with Customization

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animated.svg",
        size: CGSize(width: 300, height: 300),
        interactive: true
    )
    .title("Animated SVG")
    .message("Interactive animation")
    .position(.center)
    .width(600)
    .height(500)
    .moveable(true)
    .transparent(true, material: .hudWindow)
    .screenBlur(true)
    .dismissOnScreenTap(true)
    .show()
```

### SVG with Auto-Dismiss

```swift
VibeNotify.builder()
    .svg(
        "/path/to/loading.svg",
        size: CGSize(width: 200, height: 200)
    )
    .title("Loading...")
    .message("Please wait")
    .position(.center)
    .width(400)
    .height(300)
    .autoDismiss(after: 3.0, showProgress: true)
    .show()
```

---

## Advanced Features

### Auto-Dismiss with Progress

Show a progress bar while counting down to auto-dismiss:

```swift
VibeNotify.builder()
    .title("Auto Dismiss")
    .message("Closes in 5 seconds")
    .icon(.info)
    .autoDismiss(
        after: 5.0,
        showProgress: true
    )
    .show()
```

### Multiple Buttons

Add multiple action buttons with different styles:

```swift
VibeNotify.builder()
    .title("Delete File?")
    .message("This action cannot be undone")
    .icon(.warning)
    .button(
        StandardNotification.Button(
            title: "Delete",
            style: .destructive
        ) {
            // Perform deletion
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            // Cancel action
        }
    )
    .position(.center)
    .width(450)
    .height(200)
    .show()
```

**Button Styles:**
- `.primary` - Blue, primary action
- `.secondary` - Gray, secondary action
- `.destructive` - Red, destructive action

### Keyboard Shortcuts

Notifications support ESC key to dismiss:

```swift
// Press ESC to dismiss
VibeNotify.builder()
    .title("Press ESC")
    .message("Hit ESC key to close")
    .icon(.info)
    .show()
```

### Programmatic Dismissal

```swift
// Dismiss specific notification
let id = VibeNotify.builder()
    .title("Temporary")
    .message("Will be dismissed programmatically")
    .show()

// Later...
VibeNotify.shared.dismiss(id: id)

// Dismiss all notifications
VibeNotify.shared.dismissAll()
```

### Custom SwiftUI Views

Display any custom SwiftUI view as a notification:

```swift
VibeNotify.shared.showCustom(
    presentationMode: .fullScreen,
    windowLevel: .floating
) {
    ZStack {
        Color.black.opacity(0.5)

        VStack(spacing: 20) {
            Text("Custom View")
                .font(.largeTitle)
                .foregroundColor(.white)

            Button("Dismiss") {
                VibeNotify.shared.dismissAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

---

## API Reference

### Builder Methods

All builder methods return `self` for chaining:

```swift
// Content
.title(_ title: String) -> Self
.message(_ message: String) -> Self
.icon(_ icon: StandardNotification.IconType) -> Self

// Buttons
.button(_ button: StandardNotification.Button) -> Self

// Positioning
.position(_ position: WindowPosition) -> Self
.presentationMode(_ mode: PresentationMode) -> Self

// Sizing
.width(_ width: CGFloat) -> Self
.height(_ height: CGFloat) -> Self

// Behavior
.moveable(_ moveable: Bool = true) -> Self
.alwaysOnTop(_ alwaysOnTop: Bool = true) -> Self
.windowLevel(_ level: WindowLevel) -> Self

// Visual Effects
.transparent(
    _ enabled: Bool = true,
    material: NSVisualEffectView.Material = .hudWindow
) -> Self

.windowOpacity(_ opacity: CGFloat) -> Self

.screenBlur(
    _ enabled: Bool = true,
    material: NSVisualEffectView.Material = .underWindowBackground
) -> Self

.dismissOnScreenTap(_ enabled: Bool = true) -> Self

// Auto-Dismiss
.autoDismiss(
    after delay: TimeInterval,
    showProgress: Bool = false
) -> Self

// SVG
.svg(
    _ path: String,
    size: CGSize = CGSize(width: 200, height: 200),
    interactive: Bool = false
) -> Self

// Display
.show() -> UUID
```

### Convenience Methods

```swift
// Quick notifications
VibeNotify.shared.success(
    title: String = "Success",
    message: String,
    autoDismiss: TimeInterval? = 3.0
) -> UUID

VibeNotify.shared.error(
    title: String = "Error",
    message: String,
    buttons: [StandardNotification.Button] = []
) -> UUID

VibeNotify.shared.warning(
    title: String = "Warning",
    message: String,
    autoDismiss: TimeInterval? = 5.0
) -> UUID

VibeNotify.shared.info(
    title: String = "Info",
    message: String,
    autoDismiss: TimeInterval? = 4.0
) -> UUID
```

### Icon Types

```swift
.icon(.success)                              // Green checkmark
.icon(.error)                                // Red X
.icon(.warning)                              // Orange triangle
.icon(.info)                                 // Blue info icon
.icon(.system("star.fill"))                  // Any SF Symbol
.icon(.image(NSImage(named: "icon")!))       // Custom NSImage
.icon(.svg("/path/to/icon.svg"))             // SVG file
```

### Window Positions

```swift
.topLeft, .top, .topRight
.left, .center, .right
.bottomLeft, .bottom, .bottomRight
```

### Presentation Modes

```swift
.fullScreen
.banner(edge: .top, height: 120)
.toast(corner: .topRight, size: CGSize(width: 300, height: 150))
.custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300))
```

---

## Examples

### Example 1: Simple Success Toast

```swift
VibeNotify.builder()
    .title("Success")
    .message("File saved successfully")
    .icon(.success)
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))
    .autoDismiss(after: 3.0, showProgress: true)
    .show()
```

### Example 2: Centered Modal Dialog

```swift
VibeNotify.builder()
    .title("Confirm Delete")
    .message("Are you sure you want to delete this item?")
    .icon(.warning)
    .position(.center)
    .width(450)
    .height(200)
    .screenBlur(true)
    .dismissOnScreenTap(false)
    .button(
        StandardNotification.Button(
            title: "Delete",
            style: .destructive
        ) {
            // Delete action
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            // Cancel
        }
    )
    .show()
```

### Example 3: Transparent Floating HUD

```swift
VibeNotify.builder()
    .title("System Status")
    .message("All services running normally")
    .icon(.success)
    .position(.bottomRight)
    .width(350)
    .height(180)
    .moveable(true)
    .transparent(true, material: .hudWindow)
    .windowOpacity(0.9)
    .autoDismiss(after: 5.0)
    .show()
```

### Example 4: SVG Animation with Blur

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animation.svg",
        size: CGSize(width: 250, height: 250),
        interactive: true
    )
    .title("Loading...")
    .message("Please wait while we process")
    .position(.center)
    .width(500)
    .height(400)
    .transparent(true, material: .hudWindow)
    .screenBlur(true, material: .underWindowBackground)
    .show()
```

### Example 5: Remote SVG from CDN

```swift
VibeNotify.builder()
    .svgURL(
        URL(string: "https://cdn.example.com/icon.svg")!,
        size: CGSize(width: 200, height: 200)
    )
    .title("Remote Resource")
    .message("SVG loaded from CDN")
    .position(.topRight)
    .width(400)
    .height(350)
    .transparent(true)
    .autoDismiss(after: 4.0, showProgress: true)
    .show()
```

### Example 5: Draggable Reminder

```swift
VibeNotify.builder()
    .title("20-20-20 Rule")
    .message("Look away for 20 seconds to rest your eyes")
    .icon(.info)
    .position(.topRight)
    .width(400)
    .height(180)
    .moveable(true)
    .transparent(true, material: .popover)
    .autoDismiss(after: 20.0, showProgress: true)
    .show()
```

### Example 6: Focus Mode Alert

```swift
VibeNotify.builder()
    .title("Focus Mode Active")
    .message("Notifications are paused. Click anywhere to dismiss.")
    .icon(.success)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(true, material: .underWindowBackground)
    .dismissOnScreenTap(true)
    .transparent(true, material: .hudWindow)
    .windowOpacity(0.95)
    .show()
```

---

## Best Practices

### 1. Choose the Right Approach

**Use Builder API for:**
- Complex configurations
- Multiple options
- Readable, maintainable code
- Most production use cases

**Use Convenience Methods for:**
- Quick alerts
- Simple notifications
- Prototyping

### 2. Positioning Strategy

- **`.center`** - Critical alerts, confirmations
- **`.top` / `.bottom`** - Status messages, banners
- **`.topRight` / `.bottomRight`** - Non-intrusive notifications
- **`.topLeft` / `.bottomLeft`** - Persistent indicators

### 3. Transparency & Blur

- Use `.transparent(true)` for elegant, modern look
- Combine with `.screenBlur(true)` for modal dialogs
- Adjust `.windowOpacity()` for subtle effects
- Match material to your app's design language

### 4. Moveable Windows

- Enable for non-critical, informational notifications
- Provide sufficient size (min 300x150) for dragging
- Consider starting position carefully

### 5. Auto-Dismiss

- **Success**: 3-5 seconds
- **Info**: 4-6 seconds
- **Warning**: 5-8 seconds
- **Error**: Manual dismiss (buttons)
- Enable `showProgress` for clarity

---

## Troubleshooting

### Keyboard Input Not Working

If keyboard input goes to terminal instead of the app when using `swift run`:

```swift
// Already fixed in demo app with AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
```

### Notification Not Appearing

- Check window level: try `.windowLevel(.screenSaver)`
- Verify presentation mode or position is correct
- Ensure main thread: all APIs are `@MainActor`

### SVG Not Rendering

- Use absolute file paths
- Verify file exists at the specified path
- Check SVG is valid and not corrupted

### Transparent Background Not Showing

- Confirm `transparent: true` is set
- Try different materials (`.hudWindow`, `.popover`, etc.)
- Ensure background isn't being overridden

---

## Demo Application

The included demo app showcases all features:

```bash
cd VibeNotifyDemo
swift run
```

**Features:**
- 📚 Topic-based exploration
- ⚡️ Quick Start presets
- 🎨 Live customization
- 💻 Generated code examples
- ⌨️ Keyboard shortcuts (⌘P to preview, ⌘D to dismiss all)

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details.

## Credits

Inspired by:
- [swiftDialog](https://github.com/swiftDialog/swiftDialog)
- [SVGView](https://github.com/exyte/SVGView)

Built with ❤️ for the macOS developer community
