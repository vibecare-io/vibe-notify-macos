# Adaptive Theme Support for SVG Notifications

**Date:** November 30, 2025

## Summary

SVG notifications now automatically adapt to the system theme (light/dark mode) for improved readability and visual appeal.

## Changes

### Adaptive Text Colors
- **Dark mode**: White text with subtle white glow
- **Light mode**: Dark text (system primary/secondary colors)

### SVG Glow/Shadow Effects
- **Dark mode**: Green glow around SVG (50% opacity, radius 15)
- **Light mode**: Dark shadow around SVG (50% opacity, radius 15)

### Adjustable Screen Blur Intensity
- New `ScreenBlurIntensity` enum: `.light`, `.medium`, `.heavy`, `.custom(radius:)`
- Uses `CGSSetWindowBackgroundBlurRadius` private API for precise control
- Replaces fixed `NSVisualEffectView` materials

## Usage

```swift
// Screen blur with preset intensity
VibeNotify.builder()
    .title("Focus Mode")
    .message("With medium blur")
    .screenBlur(true, intensity: .medium)
    .show()

// Screen blur with custom radius
VibeNotify.builder()
    .title("Custom Blur")
    .message("Fine-tuned blur level")
    .screenBlur(true, intensity: .custom(radius: 35))
    .show()

// Available presets:
// .light   - radius: 10
// .medium  - radius: 25
// .heavy   - radius: 50
// .custom(radius:) - 0 to 100
```

## Technical Details

- Uses `@Environment(\.colorScheme)` for automatic theme detection
- SVG glow follows actual SVG shape (not a rectangle)
- Text shadows are centered for soft halo effect

## Files Modified

- `Sources/VibeNotify/Views/SVGNotificationView.swift`
- `Sources/VibeNotify/Models/ScreenBlurIntensity.swift` (new)
- `Sources/VibeNotify/Core/WindowBlurHelper.swift` (new)
- `Sources/VibeNotify/Core/OverlayWindowManager.swift`
- `Sources/VibeNotify/API/VibeNotify.swift`
