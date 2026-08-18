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
    view.load(URLRequest(url: panel.url))
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loaded: URL?
  }
}
