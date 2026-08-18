import AppKit

/// One named axis of presentation *intent*, above `OverlayWindowManager.PresentationMode`'s
/// pure geometry. `PresentationMode` says only where a rectangle lands; `AlertMode` says
/// what the alert *is* — whether it takes over the screen or floats alongside it — and
/// bundles the ~20 `Configuration` knobs (backdrop, chrome, escape routes, window level)
/// that are only ever correct together.
///
/// Deliberately not named `PresentationMode`: that name is already the geometry enum, and
/// the two must stay distinguishable in call sites and diffs.
public enum AlertMode: Sendable {
  /// The whole screen becomes the scrim: a full-attention interrupt (e.g. a scheduled
  /// break). See `OverlayWindowManager.Configuration.interrupt(...)`.
  case interrupt
  /// A positioned window; the desktop stays untouched and every other window stays
  /// clickable. See `OverlayWindowManager.Configuration.ambient(...)`.
  case ambient
}

extension OverlayWindowManager.Configuration {
  /// The whole screen becomes the scrim: full-screen geometry on the target screen
  /// (`position`/`width`/`height` left `nil` so nothing overrides `.fullScreen`), a heavy
  /// blur backdrop dimmed to 0.55 — the smallest dim at which white text clears 4.5:1
  /// contrast over *any* desktop, worst case a pure white one — and always on top.
  ///
  /// Also takes key focus: ESC must work without a prior click, and stray keystrokes
  /// must not land in whatever the user was typing behind the dim. No extra wiring is
  /// needed for the *capability* here — `DismissibleWindow.canBecomeKey` already
  /// returns `true` unconditionally — but `takesKeyFocus: true` is passed explicitly
  /// (it is also the default) so `OverlayWindowManager.show` seizes focus on presentation
  /// rather than merely ordering the window front.
  ///
  /// `backdropStyle` defaults to `.blurredDesktop`, so every call written
  /// before it existed still produces exactly the blurred, 0.55-dimmed desktop
  /// described above. A painted style replaces that surface entirely and makes
  /// `screenDim` inert — the dim exists to bound an *unknown* desktop, and a
  /// painted field is not unknown. See `BackdropStyle`.
  public static func interrupt(
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil,
    backdropStyle: BackdropStyle = .blurredDesktop
  ) -> OverlayWindowManager.Configuration {
    .init(
      presentationMode: .fullScreen,
      position: nil,
      width: nil,
      height: nil,
      backgroundColor: .clear,
      isTransparent: true,
      alwaysOnTop: true,
      screenBlur: true,
      screenBlurIntensity: .heavy,
      dismissOnScreenTap: dismissOnScreenTap,
      animatePresentation: animatePresentation,
      screen: screen,
      // `Legibility.safeDim`, not a literal 0.55: the same number is the
      // feathered scrim's peak opacity and the threshold above which a local
      // scrim is redundant, and re-deriving it in three places is how two of
      // them end up stale.
      screenDim: Legibility.safeDim,
      takesKeyFocus: true,
      backdropStyle: backdropStyle
    )
  }

  /// A positioned window; the desktop is left untouched. No blur window at all
  /// (`screenBlur: false`), so `screenDim` is inert for this mode — every other window
  /// stays clickable and the desktop keeps its light.
  ///
  /// `width`/`height` are required, not optional, deliberately: `Configuration`'s
  /// `presentationMode` defaults to `.fullScreen`, and `createWindow` only ever shrinks
  /// that starting rect if `width`/`height` are non-nil before `position` recenters it —
  /// leaving both `nil` (as an earlier version of this factory did) silently produces a
  /// transparent window the exact size of the screen, swallowing every click on the
  /// display. Requiring a size here, the same way `position` is already required, makes
  /// that shape impossible to construct through this factory.
  ///
  /// Does not take key focus (`takesKeyFocus: false`): `.ambient` is confirmations,
  /// warnings, plugin notices and toasts, and a toast that steals focus mid-keystroke is
  /// exactly the failure this mode exists to avoid. The window stays key-*capable* —
  /// `DismissibleWindow.canBecomeKey` is untouched — so clicking it can still make it key
  /// and ESC still dismisses it; only the unprompted seize on `show()` is suppressed.
  public static func ambient(
    position: OverlayWindowManager.WindowPosition,
    width: CGFloat,
    height: CGFloat,
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil
  ) -> OverlayWindowManager.Configuration {
    .init(
      position: position,
      width: width,
      height: height,
      backgroundColor: .clear,
      isTransparent: true,
      alwaysOnTop: true,
      screenBlur: false,
      dismissOnScreenTap: dismissOnScreenTap,
      animatePresentation: animatePresentation,
      screen: screen,
      takesKeyFocus: false
    )
  }
}
