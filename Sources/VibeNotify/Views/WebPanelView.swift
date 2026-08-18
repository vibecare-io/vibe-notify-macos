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
      var request = URLRequest(url: target)
      // The one line that makes an embed URL work. Without it the player sees
      // no embedder and answers with Error 153; with it, the same URL loads.
      request.setValue(Self.embedderOrigin, forHTTPHeaderField: "Referer")
      view.load(request)
    }
  }

  /// The embedder this claims to be, in the `Referer` of a `.player` load.
  ///
  /// Measured, everything else held equal:
  ///
  ///     Referer            result
  ///     (none)             Error 153, readyState 0
  ///     an https origin    loads fully, readyState 4
  ///
  /// `.invalid` is reserved by RFC 2606 and can never resolve, so this claims
  /// nothing about a real site and cannot be mistaken for one. It is a header
  /// value only — nothing is ever fetched from it, and no document is served
  /// from it. Naming a domain someone owns would be asserting their
  /// endorsement of whatever a caller chooses to embed.
  ///
  /// Internal rather than private so a test can hold the property without a
  /// network.
  static let embedderOrigin = "https://embed.vibenotify.invalid/"

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loaded: URL?
  }
}
