# SVG URL Support

**Date:** November 6, 2025
**Type:** Feature Enhancement
**Breaking Changes:** None

## Summary

Added support for loading SVG notifications from remote URLs in addition to local file paths, maintaining full backward compatibility with existing code.

## Changes

### New Features

1. **SVGSource Enum** - Type-safe approach to handle both file paths and URLs
   ```swift
   public enum SVGSource {
       case filePath(String)
       case url(URL)
   }
   ```

2. **URL-based API Methods**
   - `VibeNotify.shared.showSVG(svgURL:...)` - Show SVG from URL
   - `NotificationBuilder.svgURL(_:size:interactive:)` - Builder method for URLs

3. **Multiple Initialization Options**
   - `SVGNotification(svgSource:)` - Primary initializer with enum
   - `SVGNotification(svgURL:)` - Convenience initializer for URLs
   - `SVGNotification(svgPath:)` - Convenience initializer for paths (backward compatible)

### Modified Components

- **Sources/VibeNotify/Models/NotificationContent.swift**
  - Added `SVGSource` enum (lines 138-151)
  - Updated `SVGNotification` to use `svgSource` instead of `svgPath`
  - Added convenience initializers for backward compatibility

- **Sources/VibeNotify/Views/SVGNotificationView.swift**
  - Updated SVG loading to use `notification.svgSource.url` (line 21)

- **Sources/VibeNotify/API/VibeNotify.swift**
  - Added `showSVG(svgURL:...)` method overload (lines 127-180)
  - Updated `NotificationBuilder` with `svgURL` property and method (lines 359, 457-463)
  - Modified builder's `show()` method to handle both paths and URLs (lines 467-514)

## Usage Examples

### Load SVG from URL
```swift
// Direct API
VibeNotify.shared.showSVG(
    svgURL: URL(string: "https://example.com/icon.svg")!,
    title: "Remote Icon",
    message: "Loaded from CDN"
)

// Builder API
VibeNotify.builder()
    .svgURL(URL(string: "https://example.com/icon.svg")!, size: CGSize(width: 200, height: 200))
    .title("Remote Icon")
    .show()
```

### Backward Compatible (Existing Code)
```swift
// Still works exactly as before
VibeNotify.builder()
    .svg("/path/to/local.svg", size: CGSize(width: 200, height: 200))
    .title("Local Icon")
    .show()
```

## Benefits

- ✅ Load SVG from remote URLs (CDNs, APIs, dynamic content)
- ✅ Full backward compatibility - no breaking changes
- ✅ Type-safe implementation using Swift enums
- ✅ Consistent API design across both approaches
- ✅ Flexible initialization options

## Migration Guide

**No migration required!** All existing code continues to work without any changes.

If you want to use the new URL feature:

```swift
// Before (still works)
VibeNotify.builder().svg("/path/to/icon.svg").show()

// New option
VibeNotify.builder().svgURL(URL(string: "https://example.com/icon.svg")!).show()
```

## Testing

- ✅ Build verification passed (`swift build`)
- ✅ Backward compatibility confirmed
- ✅ New API methods compile successfully

## Related Files

- `EXAMPLES_SVG_URL.md` - Comprehensive usage examples and real-world use cases
