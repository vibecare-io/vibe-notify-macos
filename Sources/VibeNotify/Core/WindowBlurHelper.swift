import AppKit

// MARK: - Private CoreGraphics API declarations
// Used by WezTerm, Kitty, and other macOS apps for window blur

@_silgen_name("CGSDefaultConnectionForThread")
private func CGSDefaultConnectionForThread() -> UnsafeRawPointer

@_silgen_name("CGSSetWindowBackgroundBlurRadius")
private func CGSSetWindowBackgroundBlurRadius(
    _ connection: UnsafeRawPointer,
    _ windowNumber: Int,
    _ radius: Int
) -> Int32

/// Helper for applying blur effects to windows using CoreGraphics private API
@MainActor
enum WindowBlurHelper {
    /// Apply a blur effect to the window background
    /// - Parameters:
    ///   - radius: The blur radius (0-100 recommended)
    ///   - window: The window to apply blur to
    /// - Note: Window must have a non-zero alpha background color for blur to be visible
    static func setBlurRadius(_ radius: Int, for window: NSWindow) {
        let connection = CGSDefaultConnectionForThread()
        _ = CGSSetWindowBackgroundBlurRadius(connection, window.windowNumber, radius)
    }
}
