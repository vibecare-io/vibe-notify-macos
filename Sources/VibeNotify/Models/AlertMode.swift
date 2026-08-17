import AppKit

/// One named axis of presentation *intent*, above `OverlayWindowManager.PresentationMode`'s
/// pure geometry. `PresentationMode` says only where a rectangle lands; `AlertMode` says
/// what the alert *is* — whether it takes over the screen or floats alongside it — and
/// bundles the ~19 `Configuration` knobs (backdrop, chrome, escape routes, window level)
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
  /// needed for that here — `DismissibleWindow.canBecomeKey` already returns `true`
  /// unconditionally, and `OverlayWindowManager.show` already calls
  /// `makeKeyAndOrderFront` on every content window regardless of configuration. This
  /// factory only has to avoid disabling either of those, which it does not touch.
  public static func interrupt(
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil
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
      screenDim: 0.55
    )
  }

  /// A positioned window; the desktop is left untouched. No blur window at all
  /// (`screenBlur: false`), so `screenDim` is inert for this mode — every other window
  /// stays clickable and the desktop keeps its light.
  public static func ambient(
    position: OverlayWindowManager.WindowPosition,
    width: CGFloat? = nil,
    height: CGFloat? = nil,
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
      screen: screen
    )
  }
}
