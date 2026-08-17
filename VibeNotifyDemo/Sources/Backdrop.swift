import AppKit
import SwiftUI

/// The hostile desktops this harness renders *underneath* the alert, because we
/// cannot control the reviewer's real desktop and the bug this whole library
/// exists to fix only shows up over specific backdrops.
///
/// `.splitBlackWhite` is the one that matters most: a dark terminal filling the
/// left half and a white browser filling the right, which is exactly the
/// desktop that made the old renderer's `useLightText = (colorScheme == .dark)`
/// pick near-black, shadowless text and vanish over the black half. The rest
/// exist to stress the same invariant from other angles: a mid-grey field is
/// the backdrop closest to "average" (where a lazy fixed-alpha scrim most often
/// looks fine by accident), the gradient stands in for a saturated wallpaper or
/// a photo full-screen in a browser, and the busy pattern is what a heavy blur
/// has to actually destroy for the scrim to be doing any work at all.
enum BackdropPattern: String, CaseIterable, Identifiable {
  case splitBlackWhite = "Split Black / White"
  case midGrey = "Mid-Grey Field"
  case gradient = "Saturated Gradient"
  case busyPattern = "Busy High-Frequency Pattern"
  case none = "None (real desktop)"

  var id: String { rawValue }

  var summary: String {
    switch self {
    case .splitBlackWhite:
      return "The flagship case: title/message centred so they straddle the seam."
    case .midGrey:
      return "The backdrop a lazy fixed-alpha scrim most often gets away with."
    case .gradient:
      return "A saturated, photo-like field — stands in for a colourful wallpaper."
    case .busyPattern:
      return "Fine high-frequency detail, to judge what the blur actually removes."
    case .none:
      return "No painted window — judges the alert against whatever is really behind this app."
    }
  }
}

/// Renders one `BackdropPattern`, full-bleed.
struct BackdropView: View {
  let pattern: BackdropPattern

  var body: some View {
    switch pattern {
    case .splitBlackWhite:
      HStack(spacing: 0) {
        Color.black
        Color.white
      }
    case .midGrey:
      Color(white: 0.5)
    case .gradient:
      LinearGradient(
        colors: [
          Color(red: 0.98, green: 0.42, blue: 0.16),
          Color(red: 0.78, green: 0.09, blue: 0.62),
          Color(red: 0.06, green: 0.42, blue: 0.86),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
    case .busyPattern:
      Canvas { context, size in
        let cell: CGFloat = 8
        var x: CGFloat = 0
        var row = 0
        while x < size.width {
          var y: CGFloat = 0
          var col = 0
          while y < size.height {
            let dark = (row + col).isMultiple(of: 2)
            context.fill(
              Path(CGRect(x: x, y: y, width: cell, height: cell)),
              with: .color(dark ? .black : .white))
            y += cell
            col += 1
          }
          x += cell
          row += 1
        }
      }
    case .none:
      Color.clear
    }
  }
}

/// Owns the single full-screen, borderless window the backdrop is painted
/// into.
///
/// **Window level, and why it is not simply `.normal - 1`.** The whole point
/// of this window is to stand in for the reviewer's real desktop — a terminal
/// here, a browser there — which means it has to render *above* whatever real
/// windows are already open behind this app, not just above nothing. Every
/// ordinary application window, including this app's own control panel, sits
/// at `NSWindow.Level.normal`; a level *below* that is below all of them
/// indiscriminately, so the "backdrop" would only ever be visible in the gaps
/// where no other window happened to be. (An earlier version of this file did
/// exactly that, and a screenshot of it shows a real terminal showing through
/// where a solid black/white split should have been.) So this sits one step
/// *above* `.normal` instead — above every ordinary window, including
/// whatever the reviewer had open before launching this tool — and
/// `DemoApp.swift` bumps the control panel's own window one step above *that*,
/// so the stacking a reviewer actually sees is: real desktop, then this
/// backdrop, then this app's controls, then the alert
/// (`OverlayWindowManager`'s content/blur windows, both still comfortably
/// above at `.floating` / `.floating - 1`) on top of all of it.
@MainActor
final class BackdropWindowController {
  /// One step above every ordinary application window. Exposed so
  /// `DemoApp.swift` can position the control panel one step above *this*.
  static let level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

  private var window: NSWindow?

  func show(_ pattern: BackdropPattern, on screen: NSScreen) {
    guard pattern != .none else {
      hide()
      return
    }

    if window == nil {
      let win = NSWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen)
      win.isOpaque = true
      win.hasShadow = false
      win.isReleasedWhenClosed = false
      // Never intercepts a click — this is scenery, not UI. Clicks must reach
      // this app's own windows (sibling `NSWindow`s, unaffected by this flag)
      // and, with no backdrop showing, the real desktop underneath.
      win.ignoresMouseEvents = true
      win.level = BackdropWindowController.level
      win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window = win
    }

    window?.setFrame(screen.frame, display: true)
    window?.contentView = NSHostingView(rootView: BackdropView(pattern: pattern))
    window?.orderFrontRegardless()
  }

  func hide() {
    window?.orderOut(nil)
  }
}
