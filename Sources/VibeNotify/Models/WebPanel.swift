import CoreGraphics
import Foundation

/// A live web page embedded beside an alert's text and countdown, so a break
/// can *be* something — a game, a video, an inbox — rather than only describe
/// one.
///
/// This is a property of `RichNotification` rather than a fourth
/// `Illustration` case. An illustration is centred and sized to fit *within*
/// the stack, capped at `Illustration.maximumHeightFraction`; a web panel is a
/// column that the rest of the alert arranges itself beside. Expressing it as
/// an illustration would mean `fitted(in:)` shrinking a 20-minute video to
/// half the available height and centring it above the title, which is not
/// what any caller asking for this wants.
public struct WebPanel: Sendable, Equatable {

  /// Which side of the surface the *web content* occupies. The text rail takes
  /// whatever is left.
  public enum Placement: Sendable, Equatable {
    case leading
    case trailing
  }

  public let url: URL
  public let placement: Placement
  /// The web column's share of the surface width.
  ///
  /// Clamped in `init` rather than trusted. Below `minimumWidthFraction` the
  /// panel is too narrow to play or watch anything in and the alert would have
  /// been better off without it; above `maximumWidthFraction` the rail loses
  /// the room its countdown and buttons need, and a break with no visible way
  /// to end it is the failure this whole surface exists to avoid.
  public let widthFraction: CGFloat
  /// Whether media may start without the user pressing anything.
  ///
  /// Off by default. A video that starts talking on its own is a worse
  /// interruption than the one the alert was meant to soften, and the caller
  /// asking for a YouTube URL is not necessarily the party who decided the
  /// break should make noise.
  public let allowsAutoplay: Bool

  public static let minimumWidthFraction: CGFloat = 0.3
  public static let maximumWidthFraction: CGFloat = 0.85
  public static let defaultWidthFraction: CGFloat = 0.64

  public init(
    url: URL,
    placement: Placement = .leading,
    widthFraction: CGFloat = WebPanel.defaultWidthFraction,
    allowsAutoplay: Bool = false
  ) {
    self.url = url
    self.placement = placement
    self.widthFraction = min(
      Self.maximumWidthFraction, max(Self.minimumWidthFraction, widthFraction))
    self.allowsAutoplay = allowsAutoplay
  }
}
