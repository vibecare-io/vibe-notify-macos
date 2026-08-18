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
    case .player:
      view.loadHTMLString(Self.playerDocument(for: target), baseURL: Self.embedderOrigin)
    }
  }

  /// A document holding nothing but the player, edge to edge.
  ///
  /// **This is the arrangement, and it is an iframe on purpose.** A top-level
  /// load with an explicit `Referer` header also gets past Error 153 — that
  /// was measured — but it is not the shape a working embed has anywhere else
  /// on the web, and in practice it does not autoplay. The reference that does
  /// work is the ordinary one every page uses:
  ///
  ///     <iframe src="https://www.youtube.com/embed/ID?autoplay=1&mute=1">
  ///
  /// so this reproduces exactly that, and the only thing added to it is a
  /// `baseURL` — see `embedderOrigin` for why the document needs an origin at
  /// all, and why it must not be YouTube's own.
  ///
  /// `allow="autoplay"` is present only when the caller asked for it. The
  /// attribute is what grants the frame permission, so including it always
  /// would hand every embedded player the right to start regardless of
  /// `allowsAutoplay`. Note it is necessary and not sufficient: the URL must
  /// also carry `autoplay=1&mute=1`, which `WebPanel.loadURL` handles.
  private static func playerDocument(for url: URL) -> String {
    let allow = "autoplay; fullscreen; picture-in-picture"
    // The URL is emitted into an HTML attribute, so its ampersands, quotes and
    // angle brackets have to stop being syntax. A `URL` cannot hold a newline,
    // which leaves these three.
    let escaped = url.absoluteString
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

  /// The origin the player document claims, as a `baseURL`.
  ///
  /// It needs one. Measured against the player, everything else equal:
  ///
  ///     baseURL                     result
  ///     nil (about:blank)           Error 153 — no origin, so no referrer
  ///     https://www.youtube.com/    Error 152 — same-origin as the target
  ///     https://…invalid/           loads, duration reported, no error
  ///
  /// The middle row is the trap and was this file's first answer: giving the
  /// document the *target's* origin looks considerate and is exactly what the
  /// player refuses, because an embed is meant to be cross-origin.
  ///
  /// `.invalid` is reserved by RFC 2606 and can never resolve, so it claims
  /// nothing about a real site, cannot be confused for one, and cannot collide
  /// with a real origin's cookies in the shared data store — a host app's own
  /// `localhost` server included, which is what ruled out `https://localhost/`.
  ///
  /// Internal rather than private so a test can hold the property without a
  /// network.
  static let embedderOrigin = URL(string: "https://embed.vibenotify.invalid/")

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loaded: URL?
  }
}
