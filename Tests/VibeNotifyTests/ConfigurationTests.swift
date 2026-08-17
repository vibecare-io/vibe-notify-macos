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

  /// `canBecomeKey` (above) is shared by every window `OverlayWindowManager`
  /// produces — it does not distinguish `.interrupt` from `.ambient`. What
  /// actually discriminates the two, and what `show()` reads to decide
  /// between `makeKeyAndOrderFront` and a plain `orderFront`, is
  /// `Configuration.takesKeyFocus`. A toast that steals focus mid-keystroke
  /// is exactly the failure `.ambient` exists to avoid; `.interrupt` must
  /// keep seizing focus unprompted (ESC has to work without a prior click).
  @Test func interruptRequestsKeyFocusButAmbientDoesNot() {
    let interruptConfiguration = OverlayWindowManager.Configuration.interrupt()
    let ambientConfiguration = OverlayWindowManager.Configuration.ambient(
      position: .center, width: 320, height: 160)

    #expect(interruptConfiguration.takesKeyFocus == true)
    #expect(ambientConfiguration.takesKeyFocus == false)
  }

  /// `.ambient` is a positioned window with the desktop left untouched: no
  /// blur window at all, so `screenDim` is inert for this mode. Asserted on
  /// the *produced window*, not the configuration: `position` is a required,
  /// non-optional parameter of `.ambient(position:...)`, so
  /// `configuration.position != nil` is structurally true and would never
  /// catch a regression — which is exactly how a prior version of this
  /// factory shipped an ambient window that was silently the full size of
  /// the screen (nothing ever set `width`/`height`, so `createWindow`'s
  /// frame calculation never shrank past `.fullScreen`'s starting rect,
  /// producing a transparent full-screen click-blocker with
  /// `ignoresMouseEvents == false`). Requiring `width`/`height` on the
  /// factory closes that hole; this test proves it via real `NSWindow.frame`
  /// and `ignoresMouseEvents`, the same way `alwaysOnTopIsAFloorNotAnOverrideOfHigherLevel`
  /// above asserts on real window state rather than the configuration alone.
  @Test func ambientFactoryProducesWindowSizedAndPositionedToItsContent() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()
    let width: CGFloat = 320
    let height: CGFloat = 160

    _ = manager.show(
      id: id,
      configuration: .ambient(
        position: .center, width: width, height: height, animatePresentation: false)
    ) {
      EmptyView()
    }

    let window = try #require(manager.activeWindows[id])
    let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!

    // Tolerance of 1pt, not exact equality: on a screen whose height doesn't
    // divide evenly by 2 (e.g. 1117pt), centering produces a fractional
    // origin.y, and AppKit's backing-store pixel alignment for a borderless
    // window's contentRect can round that into a 1pt difference on the
    // corresponding dimension (confirmed by isolated experiment — a window
    // requested at y: 478.5, height: 160 comes back y: 478, height: 161).
    // That is a legitimate AppKit rounding quirk, not the bug under test —
    // what this test guards is "not screen-sized", not "pixel-exact".
    #expect(abs(window.frame.width - width) <= 1)
    #expect(abs(window.frame.height - height) <= 1)
    #expect(
      window.frame != screen.frame,
      "an ambient window must not cover the whole screen — that swallows every click on the display"
    )
    #expect(
      window.ignoresMouseEvents == false,
      "an ambient window must receive its own clicks, not fall through to whatever is under it")

    let expectedOrigin = CGPoint(
      x: screen.frame.minX + (screen.frame.width - width) / 2,
      y: screen.frame.minY + (screen.frame.height - height) / 2
    )
    #expect(abs(window.frame.origin.x - expectedOrigin.x) <= 1)
    #expect(abs(window.frame.origin.y - expectedOrigin.y) <= 1)

    manager.dismiss(id: id, animated: false)
  }
}
