import SwiftUI

/// What an `.interrupt` alert puts behind itself: the user's own desktop,
/// blurred and dimmed, or a field this library paints instead.
///
/// The feature this exists for is a product one — staring at your own blurred
/// work for twenty seconds is not restful, and the point of a 20-20-20 break is
/// to look *away* — but the constraint on it is the one this whole library was
/// written to enforce:
///
/// > Text is never rendered over a backdrop whose luminance we do not control.
///
/// The blurred desktop satisfies that the hard way, by dimming an *unknown*
/// surface until white text clears WCAG AA over the worst case (a pure white
/// desktop) — that is `Legibility.safeDim`. A painted backdrop satisfies it the
/// easy way: the surface is entirely ours, fully opaque, and every colour in it
/// is passed through `Legibility.luminanceCapped(...)` on the way in, so no
/// preset — including one added later by someone who never read this comment —
/// can present white text with a surface brighter than
/// `Legibility.maxSafeLuminance`.
///
/// A pale solid or a light gradient is therefore not "a bad idea we chose not
/// to offer"; it is unconstructible. `BackdropFill.Stop` has no public
/// memberwise initializer that skips the cap.
///
/// **Not a colour picker.** A free colour well is precisely the API that would
/// need a runtime "your choice is illegible" error, and an error nobody can act
/// on is worse than a smaller menu. Seven fixed options: today's blurred
/// desktop, three solids, three gradients.
public enum BackdropStyle: String, CaseIterable, Identifiable, Sendable {
  /// The user's own desktop, blurred and dimmed. **The default**, and byte for
  /// byte the behaviour every alert had before this type existed.
  case blurredDesktop
  /// Near-black neutral. The quietest thing that is still not a void.
  case charcoal
  /// Deep blue-violet.
  case midnight
  /// Deep desaturated green.
  case moss
  /// Indigo into plum, top-leading to bottom-trailing.
  case dusk
  /// Navy into deep teal.
  case deepSea
  /// Near-black into a deep warm maroon.
  case ember

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .blurredDesktop: return "Blurred Desktop"
    case .charcoal: return "Charcoal"
    case .midnight: return "Midnight"
    case .moss: return "Moss"
    case .dusk: return "Dusk"
    case .deepSea: return "Deep Sea"
    case .ember: return "Ember"
    }
  }

  /// A one-line description for a settings caption. Deliberately terse: these
  /// end up in a picker, not in prose.
  public var summary: String {
    switch self {
    case .blurredDesktop: return "Your desktop, blurred and dimmed."
    case .charcoal, .midnight, .moss: return "A flat field — your desktop is hidden entirely."
    case .dusk, .deepSea, .ember: return "A soft gradient — your desktop is hidden entirely."
    }
  }

  /// Grouping for a settings UI that wants to present these in sections.
  public enum Family: String, Sendable {
    case desktop, solid, gradient
  }

  public var family: Family {
    switch self {
    case .blurredDesktop: return .desktop
    case .charcoal, .midnight, .moss: return .solid
    case .dusk, .deepSea, .ember: return .gradient
    }
  }

  /// What this library paints, or `nil` for `.blurredDesktop` — which paints
  /// nothing and lets the blur window's dim do the work.
  ///
  /// `nil` is the discriminator every consumer branches on, rather than a
  /// separate `isPainted` flag that could disagree with it.
  public var fill: BackdropFill? {
    switch self {
    case .blurredDesktop:
      return nil
    case .charcoal:
      return .solid(red: 0.13, green: 0.14, blue: 0.16)
    case .midnight:
      return .solid(red: 0.09, green: 0.11, blue: 0.24)
    case .moss:
      return .solid(red: 0.08, green: 0.16, blue: 0.13)
    case .dusk:
      return .gradient(
        from: (red: 0.07, green: 0.08, blue: 0.20),
        to: (red: 0.20, green: 0.09, blue: 0.19))
    case .deepSea:
      return .gradient(
        from: (red: 0.04, green: 0.10, blue: 0.20),
        to: (red: 0.03, green: 0.20, blue: 0.20))
    case .ember:
      return .gradient(
        from: (red: 0.06, green: 0.05, blue: 0.05),
        to: (red: 0.26, green: 0.09, blue: 0.06))
    }
  }
}

/// An opaque field painted behind an alert, as a value: one stop is a solid
/// colour, two are a diagonal gradient.
///
/// Every stop is luminance-capped at construction — see `Stop`. That is what
/// lets `Legibility.Backdrop.painted(_:)` report an `effectiveDim` of 1.0
/// (total coverage by a surface we control) and the renderer skip its local
/// scrim, exactly as it does over the Reduce Transparency black.
public struct BackdropFill: Equatable, Sendable {

  /// One luminance-capped sRGB colour.
  ///
  /// The initializer is the cap: there is no way to build a `Stop` that is too
  /// bright, only one that gets darkened on the way in. `red`/`green`/`blue`
  /// are therefore always the *constrained* values, not what the caller asked
  /// for, and `relativeLuminance` is always `<= Legibility.maxSafeLuminance`.
  public struct Stop: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
      let capped = Legibility.luminanceCapped(red: red, green: green, blue: blue)
      self.red = capped.red
      self.green = capped.green
      self.blue = capped.blue
    }

    public var relativeLuminance: Double {
      Legibility.relativeLuminance(red: red, green: green, blue: blue)
    }

    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
  }

  /// One stop, or two. Never empty: both factories supply their own.
  public let stops: [Stop]

  private init(stops: [Stop]) {
    self.stops = stops
  }

  public static func solid(red: Double, green: Double, blue: Double) -> BackdropFill {
    BackdropFill(stops: [Stop(red: red, green: green, blue: blue)])
  }

  public static func gradient(
    from: (red: Double, green: Double, blue: Double),
    to: (red: Double, green: Double, blue: Double)
  ) -> BackdropFill {
    BackdropFill(stops: [
      Stop(red: from.red, green: from.green, blue: from.blue),
      Stop(red: to.red, green: to.green, blue: to.blue),
    ])
  }

  /// The brightest point of this fill, which is the one the legibility rule is
  /// actually about — a gradient is only as safe as its lightest stop.
  public var peakLuminance: Double {
    stops.map(\.relativeLuminance).max() ?? 0
  }
}

/// Paints a `BackdropFill` full-bleed, and carries the same tap-to-dismiss
/// hook `FullScreenBlurView` does so the two backdrop windows behave
/// identically.
public struct BackdropFillView: View {
  private let fill: BackdropFill
  private let onTap: (() -> Void)?

  public init(fill: BackdropFill, onTap: (() -> Void)? = nil) {
    self.fill = fill
    self.onTap = onTap
  }

  public var body: some View {
    Group {
      if fill.stops.count >= 2 {
        LinearGradient(
          colors: fill.stops.map(\.color),
          startPoint: .topLeading,
          endPoint: .bottomTrailing)
      } else {
        (fill.stops.first?.color ?? .black)
      }
    }
    .ignoresSafeArea()
    .contentShape(Rectangle())
    .onTapGesture { onTap?() }
  }
}
