import SwiftUI
import AppKit

/// Full-screen blur overlay that covers the entire screen
public struct FullScreenBlurView: View {
    let material: NSVisualEffectView.Material
    let onTap: (() -> Void)?

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        onTap: (() -> Void)? = nil
    ) {
        self.material = material
        self.onTap = onTap
    }

    public var body: some View {
        BlurBackgroundView(material: material, blendingMode: .behindWindow)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
    }
}
