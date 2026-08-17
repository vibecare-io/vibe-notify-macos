import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

@MainActor
struct ConfigurationTests {

  /// `screenDim` defaults to the CGS compositing floor, not to 0 — see the doc
  /// comment on `createBlurWindow` for why 0 is not expressible.
  @Test func screenDimDefaultsToFloor() {
    let configuration = OverlayWindowManager.Configuration()
    #expect(configuration.screenDim == 0.1)
  }

  /// Below the floor is clamped up to it, not down to 0: the caller asked for
  /// "less dim than the floor," and the floor is the least dim that still composites.
  @Test func screenDimBelowFloorClampsToFloor() {
    let configuration = OverlayWindowManager.Configuration(screenDim: 0.0)
    #expect(configuration.screenDim == 0.1)
  }

  /// Above the ceiling is clamped down to it: 1.0 (fully opaque) is no longer a blur.
  @Test func screenDimAboveCeilingClampsToCeiling() {
    let configuration = OverlayWindowManager.Configuration(screenDim: 2.0)
    #expect(configuration.screenDim == 0.95)
  }

  /// `alwaysOnTop` must act as a floor under the requested `windowLevel`, not an
  /// override of it. A caller who explicitly asks for `.screenSaver` — precisely
  /// because they need to sit above another app's full-screen window, which
  /// `.floating` cannot do — must still get `.screenSaver` even with the
  /// (default-true) `alwaysOnTop` set.
  @Test func alwaysOnTopIsAFloorNotAnOverrideOfHigherLevel() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(
        windowLevel: .screenSaver,
        alwaysOnTop: true,
        animatePresentation: false
      )
    ) {
      EmptyView()
    }

    let window = try #require(manager.activeWindows[id])
    #expect(window.level == OverlayWindowManager.WindowLevel.screenSaver.nsWindowLevel)

    manager.dismiss(id: id, animated: false)
  }
}
