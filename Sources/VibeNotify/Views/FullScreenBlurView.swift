import SwiftUI
import AppKit

/// Full-screen blur overlay that covers the entire screen
public struct FullScreenBlurView: View {
    let material: NSVisualEffectView.Material?
    let intensity: ScreenBlurIntensity?
    let onTap: (() -> Void)?

    /// Initialize with legacy material-based blur (NSVisualEffectView)
    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        onTap: (() -> Void)? = nil
    ) {
        self.material = material
        self.intensity = nil
        self.onTap = onTap
    }

    /// Initialize with new intensity-based blur (CGSSetWindowBackgroundBlurRadius)
    public init(
        intensity: ScreenBlurIntensity,
        onTap: (() -> Void)? = nil
    ) {
        self.material = nil
        self.intensity = intensity
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if let material = material {
                // Legacy NSVisualEffectView-based blur
                BlurBackgroundView(material: material, blendingMode: .behindWindow)
            } else {
                // New CGS-based blur - window handles the blur, we just need a transparent overlay
                Color.clear
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
