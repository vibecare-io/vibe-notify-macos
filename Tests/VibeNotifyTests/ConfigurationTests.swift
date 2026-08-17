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

  // MARK: - AlertMode factories

  /// `.interrupt` is the whole-screen scrim: full-screen geometry with no
  /// position/size override, blur on at the 0.55 dim derived in the design
  /// doc (worst-case white-desktop legibility floor for white text), and a
  /// floor — not override — on window level via `alwaysOnTop`.
  @Test func interruptFactoryProducesFullScreenScrimConfiguration() {
    let configuration = OverlayWindowManager.Configuration.interrupt()

    if case .fullScreen = configuration.presentationMode {
      // expected
    } else {
      Issue.record("expected .interrupt to use .fullScreen presentation")
    }
    #expect(configuration.screenBlur == true)
    #expect(configuration.screenDim == 0.55)
    #expect(configuration.position == nil)
    #expect(configuration.width == nil)
    #expect(configuration.height == nil)
    #expect(configuration.alwaysOnTop == true)
  }

  /// `.interrupt` must take key focus without a prior click: ESC has to work
  /// immediately, and stray keystrokes must not land in whatever the user was
  /// typing behind the dim.
  ///
  /// This asserts `canBecomeKey`, the necessary condition, rather than the
  /// emergent `isKeyWindow` OS state: actually becoming the key window is
  /// arbitrated by the WindowServer and requires a running `NSApplication`
  /// event loop (`-[NSApplication run]`), which the bare `swift test` host
  /// process never starts — confirmed by isolated experiment: the same
  /// window reports `isKeyWindow == true` when driven by a real
  /// `NSApp.run()` loop (e.g. the demo app, or the VibeCare client, both of
  /// which do run one) but stays `false` under manual `RunLoop` pumping with
  /// no app loop. `canBecomeKey` is what `.interrupt`'s factory and
  /// `OverlayWindowManager.show`'s unconditional `makeKeyAndOrderFront` call
  /// actually control, and is deterministic here. A borderless `NSWindow`'s
  /// default `canBecomeKey` is `false` — this is exactly what
  /// `DismissibleWindow.canBecomeKey` (`OverlayWindowManager.swift:17-19`)
  /// overrides, and this test is what would have caught it if that override
  /// were ever removed or narrowed to exclude `.interrupt`.
  @Test func interruptFactoryTakesKeyFocus() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .interrupt(animatePresentation: false)
    ) {
      EmptyView()
    }

    let window = try #require(manager.activeWindows[id])
    #expect(window.canBecomeKey, "the .interrupt content window must be key-eligible")

    manager.dismiss(id: id, animated: false)
  }

  /// `.ambient` is a positioned window with the desktop left untouched: no
  /// blur window at all, so `screenDim` is inert for this mode.
  @Test func ambientFactoryProducesPositionedNonBlurConfiguration() {
    let configuration = OverlayWindowManager.Configuration.ambient(position: .center)

    #expect(configuration.screenBlur == false)
    #expect(configuration.position != nil)
  }
}
