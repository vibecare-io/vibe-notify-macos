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
  /// Whether the video restarts when it reaches the end.
  ///
  /// Worth having because break lengths and video lengths have no reason to
  /// agree: a 30-second Short under a 60-second countdown otherwise leaves the
  /// user staring at an end card and a grid of thumbnails for the second half
  /// of their break, which is the opposite of resting.
  ///
  /// Only meaningful for an embedded video (`embeddedVideoID != nil`); a plain
  /// page has nothing to loop.
  public let loops: Bool

  /// The YouTube video this panel embeds, or `nil` when the panel is a page
  /// rather than a video.
  ///
  /// Kept because looping needs it: see `loadURL`.
  let embeddedVideoID: String?

  /// The URL the web view is actually given — `url` plus the playback options.
  ///
  /// Separate from `url` because these are *player* parameters, not part of
  /// identifying the video: two panels pointing at the same video with
  /// different autoplay settings should still read as the same video, and
  /// `url` is what a caller inspects to find out what a panel shows.
  ///
  /// **`loop=1` alone does nothing.** On a single video YouTube's player
  /// ignores it unless `playlist` names that same video — the parameter was
  /// designed for playlists and the single-video case is a documented
  /// workaround, not an oversight to be tidied away.
  public var loadURL: URL {
    guard let embeddedVideoID,
      var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return url }

    var items = comps.queryItems ?? []
    if allowsAutoplay {
      // Necessary and not merely helpful: without it the player will not start
      // on its own however permissive the host's media policy is, which is why
      // "Allow media autoplay" appeared to do nothing at all.
      items.append(URLQueryItem(name: "autoplay", value: "1"))
    }
    if loops {
      items.append(URLQueryItem(name: "loop", value: "1"))
      items.append(URLQueryItem(name: "playlist", value: embeddedVideoID))
    }
    comps.queryItems = items.isEmpty ? nil : items
    return comps.url ?? url
  }

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
    loops: Bool = false,
    presentation: Presentation? = nil
  ) {
    let resolved = Self.embedded(url)
    self.url = resolved.url
    self.embeddedVideoID = resolved.videoID
    self.presentation = presentation ?? resolved.presentation
    self.placement = placement
    self.widthFraction = min(
      Self.maximumWidthFraction, max(Self.minimumWidthFraction, widthFraction))
    self.allowsAutoplay = allowsAutoplay
    self.loops = loops
  }

  // MARK: - YouTube

  /// A URL a panel can actually play, and how to present it.
  ///
  /// Three YouTube shapes reach this, and none of them works if handed
  /// unaltered to a top-level `load(_:)`:
  ///
  /// Four YouTube shapes reach this, and none works if handed unaltered to a
  /// top-level `load(_:)`:
  ///
  /// - `youtube.com/watch?v=ID` loads the whole site — a page *about* a video,
  ///   with a sidebar, comments and a cookie wall, in a column meant to hold
  ///   the video.
  /// - `youtu.be/ID` is the same thing after a redirect.
  /// - `youtube.com/shorts/ID` is a vertical feed: it plays the link *and*
  ///   scrolls on to whatever is next, which for a break surface means the
  ///   user is handed an infinite feed at the moment they are meant to stop
  ///   looking at one.
  /// - `youtube.com/embed/ID` is the player alone, and refuses to start with
  ///   Error 153 because a top-level navigation carries no referrer.
  ///
  /// All four become an `/embed/` URL presented `.framed`, carrying any start
  /// offset the link had. Everything else is returned untouched and `.direct`
  /// — this is a YouTube special case, not a general oEmbed resolver.
  static func embedded(_ url: URL) -> (url: URL, presentation: Presentation, videoID: String?) {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let host = comps.host?.lowercased()
    else { return (url, .direct, nil) }

    let identifier: String?
    if host == "youtu.be" {
      identifier = comps.path.split(separator: "/").first.map(String.init)
    } else if Self.isYouTube(host) {
      if let prefix = ["/embed/", "/shorts/", "/live/"].first(where: comps.path.hasPrefix) {
        identifier = comps.path.dropFirst(prefix.count).split(separator: "/").first.map(String.init)
      } else if comps.path == "/watch" {
        identifier = comps.queryItems?.first { $0.name == "v" }?.value
      } else {
        identifier = nil
      }
    } else {
      return (url, .direct, nil)
    }

    guard let identifier, !identifier.isEmpty,
      var embed = URLComponents(string: "https://www.youtube.com/embed/\(identifier)")
    else { return (url, .direct, nil) }

    // A start offset is part of what the author chose, not decoration: a link
    // to a 12-minute routine at `?t=68` is a link to the exercise, and dropping
    // it opens on a minute of introduction the break has no time for. The
    // player spells the parameter `start`, always in whole seconds.
    if let seconds = startSeconds(in: comps), seconds > 0 {
      embed.queryItems = [URLQueryItem(name: "start", value: String(seconds))]
    }

    guard let resolved = embed.url else { return (url, .direct, nil) }
    return (resolved, .framed, identifier)
  }

  /// The start offset in whole seconds, from whichever spelling the link uses.
  ///
  /// YouTube emits `t` on share links and accepts `start` on embeds, and `t`
  /// itself has two forms: bare seconds (`t=68`) and a duration (`t=1m30s`,
  /// occasionally with hours). Both appear in ordinary copied links, so both
  /// are read here.
  private static func startSeconds(in comps: URLComponents) -> Int? {
    guard
      let raw = comps.queryItems?.first(where: { $0.name == "t" || $0.name == "start" })?.value,
      !raw.isEmpty
    else { return nil }

    if let plain = Int(raw) { return plain }

    var total = 0
    var digits = 0
    var sawUnit = false
    for character in raw {
      if let value = character.wholeNumberValue, character.isNumber {
        digits = digits * 10 + value
      } else {
        switch character {
        case "h": total += digits * 3600
        case "m": total += digits * 60
        case "s": total += digits
        // An unrecognised character means this is not a duration at all, and
        // guessing at a number from the fragments would be worse than opening
        // at the start.
        default: return nil
        }
        digits = 0
        sawUnit = true
      }
    }
    // Trailing bare digits after at least one unit ("1m30") are seconds.
    return sawUnit ? total + digits : nil
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
