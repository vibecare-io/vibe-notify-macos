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

  /// How the page is put on screen.
  public enum Presentation: Sendable, Equatable {
    /// Loaded as the web view's own top-level document. Right for anything
    /// that is a page in its own right — a plugin's UI, a webmail, an article.
    case direct
    /// Loaded inside a full-bleed `<iframe>` in a wrapper document whose
    /// origin is the target's own.
    ///
    /// **This exists because YouTube refuses to play otherwise.** Navigating
    /// straight to a `/embed/` URL makes it the top-level document, which
    /// sends no `Referer`; YouTube treats that as an unauthorised embedder and
    /// renders "Error 153 — video player configuration error" instead of the
    /// video. Putting it in an iframe below a real origin is the arrangement
    /// its player expects, and is what every site embedding a video does.
    ///
    /// Not the default, because it is the *wrong* answer for most pages: a
    /// site sending `X-Frame-Options: DENY` — which includes most things worth
    /// logging into — renders a blank frame instead of a refusal you can read.
    case framed
  }

  public let presentation: Presentation

  public static let minimumWidthFraction: CGFloat = 0.3
  public static let maximumWidthFraction: CGFloat = 0.85
  public static let defaultWidthFraction: CGFloat = 0.64

  /// - Parameters:
  ///   - url: rewritten by `Self.embedded(_:)` when it is a YouTube link a
  ///     panel cannot play as-is — see there. `self.url` is what actually
  ///     loads, so a caller reading it back gets the truth rather than what
  ///     they typed.
  ///   - presentation: `nil` (the default) picks it from the URL, which is the
  ///     only way an author who pasted a YouTube link gets a working video
  ///     without having to know why it would not otherwise work. Pass a value
  ///     to override.
  public init(
    url: URL,
    placement: Placement = .leading,
    widthFraction: CGFloat = WebPanel.defaultWidthFraction,
    allowsAutoplay: Bool = false,
    presentation: Presentation? = nil
  ) {
    let resolved = Self.embedded(url)
    self.url = resolved.url
    self.presentation = presentation ?? resolved.presentation
    self.placement = placement
    self.widthFraction = min(
      Self.maximumWidthFraction, max(Self.minimumWidthFraction, widthFraction))
    self.allowsAutoplay = allowsAutoplay
  }

  // MARK: - YouTube

  /// A URL a panel can actually play, and how to present it.
  ///
  /// Three YouTube shapes reach this, and none of them works if handed
  /// unaltered to a top-level `load(_:)`:
  ///
  /// - `youtube.com/watch?v=ID` loads the whole site — a page *about* a video,
  ///   with a sidebar, comments and a cookie wall, in a column meant to hold
  ///   the video.
  /// - `youtu.be/ID` is the same thing after a redirect.
  /// - `youtube.com/embed/ID` is the player alone, and refuses to start with
  ///   Error 153 because a top-level navigation carries no referrer.
  ///
  /// All three become an `/embed/` URL presented `.framed`. Everything else is
  /// returned untouched and `.direct` — this is a YouTube special case and is
  /// not pretending to be a general oEmbed resolver.
  static func embedded(_ url: URL) -> (url: URL, presentation: Presentation) {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let host = comps.host?.lowercased()
    else { return (url, .direct) }

    let identifier: String?
    if host == "youtu.be" {
      identifier = comps.path.split(separator: "/").first.map(String.init)
    } else if Self.isYouTube(host) {
      if comps.path.hasPrefix("/embed/") {
        identifier = comps.path.dropFirst("/embed/".count).split(separator: "/").first.map(
          String.init)
      } else if comps.path == "/watch" {
        identifier = comps.queryItems?.first { $0.name == "v" }?.value
      } else {
        identifier = nil
      }
    } else {
      return (url, .direct)
    }

    guard let identifier, !identifier.isEmpty,
      let embed = URL(string: "https://www.youtube.com/embed/\(identifier)")
    else { return (url, .direct) }
    return (embed, .framed)
  }

  /// Exact host or a true subdomain — never a suffix match.
  ///
  /// `hasSuffix("youtube.com")` alone also matches `evilyoutube.com`, and
  /// while the consequence here is mild (the user would be sent to the real
  /// YouTube rather than the attacker's page) a host check that treats an
  /// unrelated domain as YouTube is wrong on its face and will be copied.
  private static func isYouTube(_ host: String) -> Bool {
    for domain in ["youtube.com", "youtube-nocookie.com"] where
      host == domain || host.hasSuffix("." + domain)
    {
      return true
    }
    return false
  }
}
