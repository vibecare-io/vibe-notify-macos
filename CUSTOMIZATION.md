# VibeNotify Customization Guide

## Overview

VibeNotify provides extensive customization options for positioning, sizing, behavior, and visual effects of notifications.

## Window Positioning

### SwiftDialog-Inspired Positions

Use the `position` parameter to place notifications at 9 predefined locations:

```swift
// 9 available positions
.position(.topLeft)      // Top left corner
.position(.top)          // Top center
.position(.topRight)     // Top right corner
.position(.left)         // Left center
.position(.center)       // Screen center (also .centre)
.position(.right)        // Right center
.position(.bottomLeft)   // Bottom left corner
.position(.bottom)       // Bottom center
.position(.bottomRight)  // Bottom right corner
```

### Examples

```swift
// Centered notification
VibeNotify.shared.show(
    title: "Welcome",
    message: "App started successfully",
    icon: .success,
    position: .center,
    width: 400,
    height: 200
)

// Bottom right notification
VibeNotify.shared.show(
    title: "Update Available",
    message: "Version 2.0 is ready to install",
    icon: .info,
    position: .bottomRight,
    width: 350,
    height: 150
)
```

## Custom Sizing

Override default notification dimensions with `width` and `height` parameters:

```swift
VibeNotify.shared.show(
    title: "Large Notification",
    message: "This notification has custom dimensions",
    icon: .info,
    width: 500,   // Custom width
    height: 300   // Custom height
)
```

### Size Guidelines

- **Small**: 300x150 - Toast/corner notifications
- **Medium**: 400x200 - Standard notifications
- **Large**: 600x400 - Rich content notifications
- **Full Screen**: Use `.presentationMode(.fullScreen)`

## Moveable Windows

Allow users to drag and reposition notifications:

```swift
VibeNotify.shared.show(
    title: "Drag Me!",
    message: "Click and drag to move this notification",
    icon: .info,
    position: .center,
    moveable: true  // Enable dragging
)
```

### Moveable + Builder API

```swift
VibeNotify.builder()
    .title("Moveable Window")
    .message("Reposition as needed")
    .icon(.warning)
    .position(.topLeft)
    .moveable(true)
    .show()
```

## Always On Top

Control whether notifications stay above other windows:

```swift
// Always on top (default)
VibeNotify.shared.show(
    title: "Important",
    message: "This stays on top",
    alwaysOnTop: true
)

// Normal window level
VibeNotify.shared.show(
    title: "Normal",
    message: "Can be covered by other windows",
    alwaysOnTop: false
)
```

## Transparent Backgrounds

Add macOS-native blur effects to notification backgrounds:

```swift
// Basic transparent blur
VibeNotify.shared.show(
    title: "Transparent Effect",
    message: "This notification has a transparent blurred background",
    icon: .success,
    transparent: true
)

// Custom transparent material
VibeNotify.shared.show(
    title: "Custom Transparent",
    message: "Using popover material",
    icon: .info,
    transparent: true,
    transparentMaterial: .popover
)
```

### Available Transparent Materials

```swift
.hudWindow      // Heads-up display style (default)
.popover        // Popover menu style
.sidebar        // Sidebar style
.menu           // Menu style
.selection      // Selection style
.titlebar       // Titlebar style
.underWindowBackground // Under window style
```

### Transparent with Builder API

```swift
VibeNotify.builder()
    .title("Elegant Transparent")
    .message("Beautiful translucent background")
    .icon(.success)
    .transparent(true, material: .hudWindow)
    .position(.center)
    .width(450)
    .height(200)
    .show()
```

## Window Opacity

Control the overall opacity of the notification window (0.0 = fully transparent, 1.0 = fully opaque):

```swift
// Semi-transparent notification
VibeNotify.shared.show(
    title: "Semi-Transparent",
    message: "This notification is 70% opaque",
    icon: .info,
    position: .center,
    width: 400,
    height: 200,
    windowOpacity: 0.7
)

// With builder API
VibeNotify.builder()
    .title("Faded Notice")
    .message("Subtle opacity effect")
    .icon(.info)
    .windowOpacity(0.85)
    .show()
```

## Full Screen Blur

Blur the **entire screen background** behind the notification for maximum focus:

```swift
// Basic screen blur
VibeNotify.shared.show(
    title: "20-20-20 Rule",
    message: "Save your eyes! Look away for 20 seconds.",
    icon: .info,
    position: .center,
    width: 500,
    height: 250,
    blurScreen: true  // Blur entire screen
)

// Custom blur material
VibeNotify.shared.show(
    title: "Focus Mode",
    message: "Everything else is blurred",
    icon: .success,
    position: .center,
    width: 450,
    height: 200,
    blurScreen: true,
    screenBlurMaterial: .underWindowBackground
)

// Dismiss on screen tap
VibeNotify.shared.show(
    title: "Tap to Dismiss",
    message: "Click anywhere outside to close",
    icon: .warning,
    position: .center,
    width: 400,
    height: 180,
    blurScreen: true,
    dismissOnScreenTap: true  // Click background to dismiss
)
```

### Screen Blur + Transparent Notification

Combine both blur types for ultimate focus:

```swift
VibeNotify.builder()
    .title("Ultra Focus Mode")
    .message("Screen and notification both blurred!")
    .icon(.success)
    .position(.center)
    .width(450)
    .height(200)
    .transparent(true, material: .hudWindow)      // Transparent notification background
    .screenBlur(true, material: .underWindowBackground)  // Blur screen background
    .dismissOnScreenTap(true)
    .autoDismiss(after: 5.0)
    .show()
```

### Difference: transparent vs screenBlur

- **`transparent`**: Makes the notification window background transparent with blur material
- **`screenBlur`**: Blurs the entire screen behind the notification

You can use both together for layered blur effects!

## Combining Customizations

### Example 1: Fully Customized Notification

```swift
VibeNotify.builder()
    .title("Fully Customized")
    .message("All customization options enabled!")
    .icon(.warning)
    .position(.topRight)
    .width(500)
    .height(250)
    .moveable(true)
    .alwaysOnTop(true)
    .transparent(true, material: .hudWindow)
    .windowOpacity(0.95)
    .autoDismiss(after: 8.0, showProgress: true)
    .show()
```

### Example 2: Draggable HUD

```swift
VibeNotify.shared.show(
    title: "Draggable HUD",
    message: "Move me anywhere on screen",
    icon: .info,
    position: .bottomLeft,
    width: 350,
    height: 180,
    moveable: true,
    transparent: true,
    transparentMaterial: .hudWindow
)
```

### Example 3: Fixed Position Alert

```swift
VibeNotify.shared.show(
    title: "Critical Alert",
    message: "This notification cannot be moved",
    icon: .error,
    position: .center,
    width: 450,
    height: 200,
    moveable: false,
    alwaysOnTop: true,
    windowLevel: .screenSaver  // Highest priority
)
```

## API Reference

### Function Parameters

```swift
public func show(
    title: String? = nil,
    message: String? = nil,
    icon: StandardNotification.IconType? = nil,
    buttons: [StandardNotification.Button] = [],
    style: StandardNotification.Style = .default,
    presentationMode: OverlayWindowManager.PresentationMode = .banner(edge: .top, height: 120),
    position: OverlayWindowManager.WindowPosition? = nil,
    width: CGFloat? = nil,
    height: CGFloat? = nil,
    windowLevel: OverlayWindowManager.WindowLevel = .floating,
    moveable: Bool = false,
    alwaysOnTop: Bool = true,
    transparent: Bool = false,
    transparentMaterial: NSVisualEffectView.Material = .hudWindow,
    windowOpacity: CGFloat = 1.0,
    screenBlur: Bool = false,
    screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground,
    dismissOnScreenTap: Bool = false,
    autoDismiss: StandardNotification.AutoDismiss? = nil
) -> UUID
```

### Builder API Methods

```swift
.position(_ position: WindowPosition)           // Set window position
.width(_ width: CGFloat)                        // Set custom width
.height(_ height: CGFloat)                      // Set custom height
.moveable(_ moveable: Bool = true)              // Enable/disable dragging
.alwaysOnTop(_ alwaysOnTop: Bool = true)        // Keep on top
.transparent(_ enabled: Bool = true,            // Transparent notification background
             material: NSVisualEffectView.Material = .hudWindow)
.windowOpacity(_ opacity: CGFloat)              // Window opacity (0.0-1.0)
.screenBlur(_ enabled: Bool = true,             // Blur entire screen
            material: NSVisualEffectView.Material = .underWindowBackground)
.dismissOnScreenTap(_ enabled: Bool = true)     // Tap screen to dismiss
```

## Position Priority

When both `position` and `presentationMode` are specified, `position` takes priority:

```swift
// Position overrides presentation mode positioning
VibeNotify.shared.show(
    title: "Positioned",
    presentationMode: .banner(edge: .top, height: 120),  // Ignored
    position: .center,                                    // Used instead
    width: 400,
    height: 200
)
```

## Best Practices

### 1. Moveable Notifications
- Use for non-critical, informational notifications
- Provide sufficient size (min 300x150) for easy dragging
- Consider center or corner positions as starting points

### 2. Transparent Backgrounds
- Works best with semi-transparent content
- Use `.hudWindow` for overlays, `.popover` for menus
- Combine with `alwaysOnTop` for prominence
- Adjust `windowOpacity` for subtle fade effects (0.0-1.0)

### 3. Positioning
- Use `.center` for critical alerts
- Use corners for persistent indicators
- Use `.top` or `.bottom` for banner-style messages

### 4. Custom Sizing
- Ensure readability: min width 300px for text notifications
- Consider screen size: don't exceed 80% of screen dimensions
- Test on different display sizes

## Demo Application

The demo app (`VibeNotifyDemo`) includes a "Customization Options" section showcasing:

- Position examples (center, bottom right)
- Moveable notification
- Transparent background effects
- Window opacity control
- Screen blur effects
- Combined customizations

Run the demo:
```bash
cd VibeNotifyDemo
swift run
```

## Migration Notes

### From Basic Notifications

Before:
```swift
VibeNotify.shared.show(
    title: "Hello",
    message: "World"
)
```

After (with customizations):
```swift
VibeNotify.shared.show(
    title: "Hello",
    message: "World",
    position: .center,
    width: 400,
    height: 200,
    transparent: true
)
```

### From Presentation Modes

Before:
```swift
VibeNotify.shared.show(
    title: "Banner",
    presentationMode: .banner(edge: .top, height: 120)
)
```

After (with position):
```swift
VibeNotify.shared.show(
    title: "Banner",
    position: .top,        // Simpler API
    width: 800,            // Custom width
    height: 120
)
```

## Troubleshooting

### Notification Not Moveable
- Ensure `moveable: true` is set
- Check that notification hasn't auto-dismissed
- Verify window level allows interaction

### Transparent Background Not Showing
- Confirm `transparent: true`
- Check that background color is transparent or semi-transparent
- Try different `transparentMaterial` values

### Position Not Applied
- Ensure both `position` and `width`/`height` are specified
- Position requires explicit size when overriding presentation mode
- Check screen bounds for custom positions

## See Also

- [README.md](README.md) - Main documentation
- [GETTING_STARTED.md](GETTING_STARTED.md) - Quick start guide
- Demo app source code for working examples
