# VibeNotify

A lightweight, customizable notification overlay library for macOS built with SwiftUI.

## Features

- 🎨 **Multiple Presentation Modes**: Full-screen, banner, toast, and custom positioning
- 🎭 **SwiftDialog-Inspired API**: Familiar configuration options for macOS administrators
- 🎬 **Built-in Animations**: Smooth SwiftUI transitions and spring animations
- 🖼️ **SVG Support**: Render and animate vector graphics using SVGView
- 🔧 **Extensible Architecture**: Protocol-based design ready for Lottie/Rive integration
- 🪟 **Advanced Window Management**: Always-on-top overlays with customizable levels
- 🎯 **Declarative API**: Both functional and builder-style APIs
- ✨ **Rich Customization**: Window positioning, sizing, transparency, blur effects, and opacity control

## Requirements

- macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vibecare-io/vibe-notify-macos.git", branch: "main")
]
```

## Quick Start

### Simple Success Notification

```swift
import VibeNotify

VibeNotify.shared.success(message: "Operation completed successfully!")
```

### Custom Notification

```swift
VibeNotify.shared.show(
    title: "Welcome",
    message: "Getting started with VibeNotify",
    icon: .success,
    presentationMode: .banner(edge: .top, height: 120),
    autoDismiss: StandardNotification.AutoDismiss(delay: 5.0, showProgress: true)
)
```

### Builder API

```swift
VibeNotify.builder()
    .title("Confirm Action")
    .message("Do you want to proceed?")
    .icon(.warning)
    .button(StandardNotification.Button(title: "Confirm", style: .primary) {
        print("Confirmed!")
    })
    .button(StandardNotification.Button(title: "Cancel", style: .secondary) {
        print("Cancelled")
    })
    .presentationMode(.banner(edge: .top, height: 150))
    .show()
```

### Full-Screen Custom View

```swift
VibeNotify.shared.showCustom(presentationMode: .fullScreen) {
    VStack {
        Text("Custom SwiftUI View")
            .font(.largeTitle)
        Button("Dismiss") {
            VibeNotify.shared.dismissAll()
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
    presentationMode: .toast(corner: .topRight, size: CGSize(width: 350, height: 400))
)
```

## Customization

VibeNotify offers extensive customization options including:

- **Window Positioning**: 9 predefined positions (topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight)
- **Custom Sizing**: Set custom width and height for notifications
- **Moveable Windows**: Drag notifications to reposition them
- **Transparent Backgrounds**: macOS-native blur materials (HUD, popover, sidebar, menu, etc.)
- **Window Opacity**: Control transparency from 0.0 to 1.0
- **Screen Blur**: Blur the entire screen background behind notifications
- **Tap to Dismiss**: Click anywhere outside the notification to close it

### Quick Customization Examples

```swift
// Centered notification with custom size
VibeNotify.shared.show(
    title: "Welcome",
    message: "Centered on screen",
    icon: .success,
    position: .center,
    width: 400,
    height: 200
)

// Moveable notification with transparent background
VibeNotify.shared.show(
    title: "Drag Me!",
    message: "Move me anywhere",
    icon: .info,
    position: .topRight,
    width: 350,
    height: 180,
    moveable: true,
    transparent: true,
    transparentMaterial: .hudWindow
)

// Screen blur with custom opacity
VibeNotify.shared.show(
    title: "Focus Mode",
    message: "Full screen blur background",
    icon: .success,
    position: .center,
    width: 450,
    height: 200,
    windowOpacity: 0.95,
    screenBlur: true,
    screenBlurMaterial: .underWindowBackground,
    dismissOnScreenTap: true
)
```

**📖 See [CUSTOMIZATION.md](CUSTOMIZATION.md) for comprehensive customization guide including all materials, positions, and advanced features.**

## Presentation Modes

```swift
.presentationMode(.fullScreen)
.presentationMode(.banner(edge: .top, height: 120))
.presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))
.presentationMode(.custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300)))
```

## Convenience Methods

```swift
// Success (green checkmark, auto-dismisses in 3s)
VibeNotify.shared.success(message: "Task completed")

// Error (red X, requires manual dismiss)
VibeNotify.shared.error(message: "Something went wrong")

// Warning (orange triangle, auto-dismisses in 5s)
VibeNotify.shared.warning(message: "Please review")

// Info (blue info icon, auto-dismisses in 4s)
VibeNotify.shared.info(message: "New features available")
```

## Dismissal

```swift
// Auto-dismiss with progress bar
autoDismiss: StandardNotification.AutoDismiss(delay: 5.0, showProgress: true)

// Dismiss specific notification
let id = VibeNotify.shared.show(title: "Test", message: "Hello")
VibeNotify.shared.dismiss(id: id)

// Dismiss all notifications
VibeNotify.shared.dismissAll()
```

## Architecture

### Extensibility for Future Animation Engines

The library uses protocol-based design to support future animation engines:

```swift
public protocol NotificationContent {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
```

This makes it easy to add Lottie or Rive support in the future:

```swift
// Future: Lottie support
struct LottieNotification: NotificationContent {
    let animationName: String
    var body: some View {
        LottieView(animation: animationName)
    }
}

// Future: Rive support
struct RiveNotification: NotificationContent {
    let rivePath: String
    var body: some View {
        RiveViewModel(fileName: rivePath).view()
    }
}
```

## Demo Application

A demo application is included in the `VibeNotifyDemo` directory. To run:

```bash
cd VibeNotifyDemo
swift run
```

## Dependencies

- [SVGView](https://github.com/exyte/SVGView) - SVG parsing and rendering for SwiftUI

## Roadmap

- [ ] Lottie animation support
- [ ] Rive animation support
- [ ] Sound effects
- [ ] Haptic feedback
- [ ] Notification queue management
- [ ] Swipe-to-dismiss gestures
- [ ] Accessibility improvements
- [ ] Unit tests and UI tests

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See [LICENSE.md](LICENSE.md) file for details

## Credits

Inspired by:
- [swiftDialog](https://github.com/swiftDialog/swiftDialog) - Dialog system for macOS
- [SVGView](https://github.com/exyte/SVGView) - SVG rendering in SwiftUI
- [SwiftDialog](https://github.com/swiftDialog/swiftDialog) - Create user-notifications on macOS with swiftDialog

## Author

Built with ❤️ for the macOS developer community
