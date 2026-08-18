import SwiftUI
import WebKit

/// The `WKWebView` behind `WebPanel`.
///
/// **On the data store, which is the whole reason authenticated URLs work.**
/// This uses `WKWebViewConfiguration`'s default `websiteDataStore` — the
/// persistent, process-wide `WKWebsiteDataStore.default()` — and not an
/// ephemeral one. VibeNotify is linked into its host application, so that jar
/// is the *same* jar the host's own web views write to. A host that has
/// already exchanged a token for a session cookie in one of its web views has
/// already authenticated this one, and a signed-in webmail stays signed in
/// between alerts. An ephemeral store would be the more cautious default in a
/// browser; here it would mean every break surface opening on a login page.
struct WebPanelView: NSViewRepresentable {

  let panel: WebPanel

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    if panel.allowsAutoplay {
      configuration.mediaTypesRequiringUserActionForPlayback = []
    }

    let view = WKWebView(frame: .zero, configuration: configuration)
    // The panel draws its own backing behind this, so the page's own
    // unpainted areas must not come through as system white — that is the
    // flash a dark alert would show for as long as the page takes to load.
    // `underPageBackgroundColor` is the supported API for it; the
    // `setValue(_:forKey: "drawsBackground")` KVC commonly used instead is
    // undocumented and can throw at runtime.
    view.underPageBackgroundColor = .clear
    // Rubber-banding past the end of a page reveals the window behind a
    // rounded corner and reads as the panel coming loose.
    view.enclosingScrollView?.verticalScrollElasticity = .none
    context.coordinator.loaded = nil
    return view
  }

  func updateNSView(_ view: WKWebView, context: Context) {
    // SwiftUI calls this on every parent redraw, and this view's parent
    // redraws on the alert's entrance animation. Reloading each time would
    // restart the video, or the game, several times a second.
    // `loadURL`, not `url`: the playback options live there, and keying the
    // reload guard on the bare `url` would make a change of autoplay or loop
    // silently fail to take effect.
    let target = panel.loadURL
    guard context.coordinator.loaded != target else { return }
    context.coordinator.loaded = target

    switch panel.presentation {
    case .direct:
      view.load(URLRequest(url: target))
    case .framed:
      view.loadHTMLString(Self.frame(panel), baseURL: Self.embedderOrigin)
    }
  }

  /// A wrapper document holding nothing but the target, edge to edge.
  ///
  /// `allow="autoplay"` is present only when the caller asked for it: the
  /// attribute is what grants the iframe permission, so including it
  /// unconditionally would hand every embedded player the right to start
  /// talking regardless of `allowsAutoplay`.
  private static func frame(_ panel: WebPanel) -> String {
    let allow = panel.allowsAutoplay ? "autoplay; fullscreen; picture-in-picture" : "fullscreen"
    // The URL is emitted into an HTML attribute, so its quotes and angle
    // brackets have to stop being syntax. `URL` cannot hold a newline, which
    // leaves these three.
    let escaped = panel.loadURL.absoluteString
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "<", with: "&lt;")
    return """
      <!doctype html>
      <html><head><meta charset="utf-8">
      <style>
        html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
        iframe{border:0;display:block;width:100%;height:100%}
      </style></head>
      <body><iframe src="\(escaped)" allow="\(allow)" allowfullscreen></iframe></body></html>
      """
  }

  /// The origin the wrapper document claims — a **third party** to whatever it
  /// embeds, and deliberately one that can never resolve.
  ///
  /// All three plausible choices were measured against YouTube's IFrame API,
  /// which reports the player's own verdict rather than a guess at it:
  ///
  ///     baseURL                     result
  ///     nil (about:blank)           ERROR:153 — no referrer at all
  ///     https://www.youtube.com/    ERROR:152 — same-origin as the target
  ///     https://…invalid/           onReady, duration loaded, no error
  ///
  /// The middle row is the trap, and it was this file's first answer: giving
  /// the wrapper the *target's* origin looks like the considerate thing to do
  /// and is precisely what the player refuses. An embed is meant to be
  /// cross-origin — that is the whole arrangement it checks for — so a
  /// document claiming to be youtube.com while framing youtube.com is a shape
  /// the real web never produces.
  ///
  /// `.invalid` is reserved by RFC 2606 and guaranteed never to resolve, so
  /// this cannot collide with a real site's cookies or storage in the shared
  /// data store — including a `localhost` server belonging to the host app,
  /// which is the near-miss that ruled out the obvious `https://localhost/`.
  /// Nothing is ever fetched from it; it exists only to be an origin.
  /// Internal rather than private so a test can assert the property that
  /// matters — that this is never the host it embeds — without a network.
  static let embedderOrigin = URL(string: "https://embed.vibenotify.invalid/")

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loaded: URL?
  }
}
