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
    guard context.coordinator.loaded != panel.url else { return }
    context.coordinator.loaded = panel.url

    switch panel.presentation {
    case .direct:
      view.load(URLRequest(url: panel.url))
    case .framed:
      view.loadHTMLString(Self.frame(panel), baseURL: Self.origin(of: panel.url))
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
    let escaped = panel.url.absoluteString
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

  /// The wrapper document's origin — the target's own scheme and host.
  ///
  /// Not `about:blank` and not nil, which is the mistake that leaves the
  /// original problem in place: a wrapper with no real origin sends no usable
  /// referrer either, and the player rejects it for the same reason it
  /// rejected the top-level navigation.
  private static func origin(of url: URL) -> URL? {
    guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    comps.path = "/"
    comps.query = nil
    comps.fragment = nil
    return comps.url
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loaded: URL?
  }
}
