import AppKit
import SwiftUI

/// Where every "will this be readable?" decision lives, as pure functions of
/// their inputs.
///
/// This type exists because the bug that started this work was a *rendering
/// decision buried in a view body*: `SVGNotificationView` defines
/// `useLightText` as `colorScheme == .dark` (`:17-20`) and branches every
/// colour on it, which is unassertable without a screen and therefore survived
/// five releases. Everything here is a function returning a value, so the
/// decisions are testable even though the pixels are not.
///
/// The invariant the whole file serves:
///
/// > Text is never rendered over a backdrop whose luminance we do not control.
///
/// `.interrupt` satisfies it by dimming the whole screen; `.ambient` by drawing
/// a local feathered scrim under its text block. Text colour then follows the
/// scrim *we drew* — never `@Environment(\.colorScheme)`, which answers a
/// question about the OS rather than about the pixels behind the alert.
public enum Legibility {

  // MARK: - The one derived constant

  /// The smallest backdrop dim at which white text is guaranteed legible over
  /// *any* desktop.
  ///
  /// Derivation, worst case a pure white desktop: compositing black at alpha
  /// `a` over white leaves sRGB `1 − a`. For white text to clear WCAG AA at
  /// 4.5:1 the backdrop's relative luminance must be at most
  /// `1.05/4.5 − 0.05 = 0.1833`, which is sRGB ≈ 0.465, i.e. `a` ≈ 0.535.
  /// Rounded up: 0.55.
  ///
  /// **One number, three uses, derived once**: the `.interrupt` dim
  /// (`Configuration.interrupt`), the feathered scrim's peak opacity
  /// (`FeatheredScrim.peakOpacity`), and the threshold above which a local
  /// scrim is redundant (`scrimStrategy(effectiveDim:reduceTransparency:)`).
  /// Re-deriving it anywhere is how two of the three end up stale.
  public static let safeDim: Double = 0.55

  // MARK: - The scrim selector

  /// Which backdrop, if any, the *renderer itself* must draw under its text
  /// block.
  ///
  /// The selector is the effective backdrop dim, **not a boolean over
  /// `screenBlur`**: `screenBlur == true` is also true for a `.light` blur at
  /// the pinned 0.1, which is not a safe backdrop. A blur preserves local mean
  /// luminance — blurring a white browser half yields a white half — so radius
  /// destroys detail, not light. The bit that matters is the dim.
  ///
  /// - `effectiveDim >= safeDim`: something else already made the whole surface
  ///   legible. Draw nothing: a local scrim over a uniform field is a visible
  ///   rectangle, which is a card arrived at by accident.
  /// - `effectiveDim < safeDim`, **including 0**: the renderer owns the
  ///   backdrop under its own text and must draw it.
  ///
  /// Reduce Transparency only changes *which* local backdrop, never whether one
  /// is needed.
  public static func scrimStrategy(effectiveDim: Double, reduceTransparency: Bool) -> ScrimStrategy
  {
    guard effectiveDim < safeDim else { return .none }
    return reduceTransparency ? .solid : .feathered
  }

  // MARK: - The global backdrop

  /// What the *window* behind the alert should be, given the mode. `nil` means
  /// no backdrop window at all.
  ///
  /// `.ambient` is always `nil`: dimming the desktop for a toast is a category
  /// error, and every other window must stay clickable.
  ///
  /// `.interrupt` under Reduce Transparency drops the blur outright. That costs
  /// nothing — the desktop was already unreadable behind a 0.55 dim and a
  /// 50-point blur — and it has a second benefit worth keeping: the private CGS
  /// blur call (`WindowBlurHelper`) stops being on the legibility path at all,
  /// so if it ever degrades to nothing the alert is still legible, just flatter.
  public static func backdrop(for mode: AlertMode, reduceTransparency: Bool) -> Backdrop? {
    switch mode {
    case .ambient:
      return nil
    case .interrupt:
      return reduceTransparency
        ? .opaque
        : .blurred(dim: safeDim, blurRadius: ScreenBlurIntensity.heavy.radius)
    }
  }

  /// A backdrop window's description, as a value.
  public enum Backdrop: Equatable, Sendable {
    /// Blurred desktop dimmed to `dim`. Dim and radius are independent axes:
    /// radius controls how much of the desktop's *detail* survives, dim how
    /// much of its *light* survives. Folding them together makes both
    /// "heavy blur, no dim" and "light blur, heavy dim" inexpressible.
    case blurred(dim: Double, blurRadius: Int)
    /// Solid black, no blur — Reduce Transparency.
    case opaque

    public var blurRadius: Int {
      switch self {
      case .blurred(_, let radius): return radius
      case .opaque: return 0
      }
    }

    public var isOpaque: Bool { self == .opaque }

    /// What `scrimStrategy` should be handed as `effectiveDim`. An opaque
    /// backdrop is total coverage, so it reads as 1.
    public var effectiveDim: Double {
      switch self {
      case .blurred(let dim, _): return dim
      case .opaque: return 1.0
      }
    }
  }

  // MARK: - Text colour and shadow

  /// Title, message and footnote styles for a mode.
  ///
  /// `colorScheme` is accepted and **deliberately ignored**. It is in the
  /// signature so that the call site reads honestly — this is the decision
  /// that used to consult it — and so a test can assert the two schemes
  /// produce identical output. Both scrims are dark, so both modes render
  /// light text in both system themes.
  public static func textStyles(mode: AlertMode, colorScheme: ColorScheme) -> (
    title: TextStyle, message: TextStyle, footnote: TextStyle
  ) {
    _ = mode
    _ = colorScheme
    return (title: .title, message: .message, footnote: .footnote)
  }

  /// A text colour with the shadow that opposes it.
  ///
  /// Under the invariant the shadow is a second-order safety net, not the
  /// contrast mechanism: it covers the seam where a glyph's antialiased edge
  /// meets an unusually bright patch surviving the scrim. It is expressed as a
  /// general opposition rule — light text takes a dark shadow, dark text a
  /// light one — so it stays correct under any future inversion, and never as
  /// `.clear` (which is no shadow) or as the text's own colour (which is a
  /// glow, and a glow *erases* light text against a light backdrop).
  public struct TextStyle: Equatable, Sendable {
    public let color: Color
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    /// A small *positive* offset, not a symmetric halo: a displaced shadow
    /// reads as separation, a centred one reads as glow.
    public let shadowOffsetY: CGFloat

    public init(color: Color, shadowColor: Color, shadowRadius: CGFloat, shadowOffsetY: CGFloat) {
      self.color = color
      self.shadowColor = shadowColor
      self.shadowRadius = shadowRadius
      self.shadowOffsetY = shadowOffsetY
    }

    public static let title = TextStyle(
      color: .white,
      shadowColor: .black.opacity(0.55),
      shadowRadius: 6,
      shadowOffsetY: 1)

    public static let message = TextStyle(
      color: .white.opacity(0.9),
      shadowColor: .black.opacity(0.45),
      shadowRadius: 4,
      shadowOffsetY: 1)

    public static let footnote = TextStyle(
      color: .white.opacity(0.6),
      shadowColor: .black.opacity(0.45),
      shadowRadius: 4,
      shadowOffsetY: 1)
  }

  // MARK: - Accessibility

  /// The two system settings the rich renderer honours, read live.
  ///
  /// `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is already the
  /// precedent in the consuming client (`PluginInterrupt.swift:75`);
  /// `accessibilityDisplayShouldReduceTransparency` was checked nowhere before
  /// this work.
  public enum Accessibility {
    /// No spring entrance; content appears at final scale.
    ///
    /// The countdown is the deliberate exception and keeps animating: it is
    /// information the user is reading, not decoration. Only its *cadence*
    /// changes, to discrete one-second steps — and the number is never removed.
    @MainActor public static var reduceMotion: Bool {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Trades the feathered scrim for a solid backdrop with a defined edge, and
    /// `.interrupt`'s blur for opaque black. A feathered scrim *is* a
    /// transparency gradient and cannot be made opaque and stay edgeless; given
    /// the choice between a solid backdrop and suppressing ambient alerts
    /// outright, the solid backdrop was chosen.
    @MainActor public static var reduceTransparency: Bool {
      NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
  }
}

/// What the renderer draws behind its own text block.
///
/// Not a `Bool`: there are three answers, and the third one only exists for
/// Reduce Transparency users.
public enum ScrimStrategy: Equatable, Sendable {
  /// A global scrim already covers the surface. Drawing a second one here
  /// would produce a visible rectangle over a uniform field — a card.
  case none
  /// A radial gradient reaching zero *inside* its own rect, so it has no edge
  /// to perceive. See `FeatheredScrim`.
  case feathered
  /// An opaque backdrop with a defined edge. Reduce Transparency only.
  case solid
}
