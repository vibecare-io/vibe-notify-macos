import AppKit
import SwiftUI
import VibeNotify

/// Where every configuration this harness can drive is assembled, and the one
/// place that actually calls into `VibeNotify`.
///
/// Task 9 added the entry point this file used to have to work around:
/// `VibeNotify.shared.showRich(_:configuration:reduceMotion:reduceTransparency:onEnd:)`.
/// Before it existed, presenting a `RichNotification` meant reaching past
/// `VibeNotify` entirely and calling `OverlayWindowManager.show(id:
/// configuration:countdown:content:)` directly — public API, so not a defect
/// exactly, but real friction any other caller of this library would hit the
/// same way. `present(_:configuration:reduceMotion:reduceTransparency:)` below
/// is now a thin wrapper over `showRich`, and its `onEnd` closure is what lets
/// `activeIDs` stay accurate for a countdown that closes its own window —
/// previously worked around here by predicting the countdown's lifetime and
/// sweeping `activeIDs` after a `DispatchQueue.main.asyncAfter`, which is
/// exactly the kind of bookkeeping a real caller should not have to
/// reimplement.
@MainActor
final class RichDemoPresenter: ObservableObject {

  /// Ids of everything currently on screen, purely so the control panel can
  /// show a live count and offer "Dismiss All".
  @Published private(set) var activeIDs: [UUID] = []


  // MARK: - Illustration assets

  /// Resolved from the source file's own location rather than bundled as a
  /// SwiftPM resource: this is a local dev harness reading files that already
  /// live in the repo (`res/img/`), not a shipping artifact, so there is
  /// nothing to gain from resource-bundling them.
  private static let repoRoot: URL = {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // Sources/
      .deletingLastPathComponent()  // VibeNotifyDemo/
      .deletingLastPathComponent()  // simple-alerts/
  }()

  static let eyeSVGPath = repoRoot.appendingPathComponent("res/img/eye.svg").path
  /// White line art, and the **other half** of the illustration-treatment
  /// decision. `eye.svg` is a black silhouette, so with only that asset in the
  /// picker the harness can only ever show the halo branch — and a light halo
  /// behind light artwork is the halo-under-white-text mistake in a new place.
  /// Both branches have to be lookable-at side by side or neither is checked.
  static let outlineSVGPath = repoRoot.appendingPathComponent("res/img/eye-outline.svg").path
  static let momoPNGPath = repoRoot.appendingPathComponent("res/img/hungry_momo.png").path

  enum IllustrationChoice: String, CaseIterable, Identifiable {
    case svg = "SVG, dark ink (eye.svg)"
    case outlineSVG = "SVG, light ink (eye-outline.svg)"
    case bitmap = "Bitmap (hungry_momo.png)"
    case symbol = "SF Symbol"
    case none = "None"

    var id: String { rawValue }

    @MainActor
    func build() -> RichNotification.Illustration? {
      switch self {
      case .svg:
        return .svg(.filePath(RichDemoPresenter.eyeSVGPath), size: CGSize(width: 240, height: 164))
      case .outlineSVG:
        return .svg(
          .filePath(RichDemoPresenter.outlineSVGPath), size: CGSize(width: 240, height: 164))
      case .bitmap:
        guard let image = NSImage(contentsOfFile: RichDemoPresenter.momoPNGPath) else { return nil }
        return .image(image, size: CGSize(width: 190, height: 190))
      case .symbol:
        return .symbol("eye.fill", pointSize: 86, color: nil)
      case .none:
        return nil
      }
    }
  }

  // MARK: - Scenario: the flagship interrupt (20-20-20 eye break)

  /// The single most important case in this harness: `.interrupt` mode, an
  /// illustration, title + message, a running task timer with its ring, a
  /// Done/Snooze/Skip row, and a footnote. `duration` is exposed so the same
  /// scenario can run long enough to watch the ring sweep (~15s) or short
  /// enough to reach the two completion states without waiting around (~4s).
  @discardableResult
  func showFlagshipInterrupt(
    duration: TimeInterval,
    illustration: IllustrationChoice,
    dismissOnScreenTap: Bool,
    backdropStyle: BackdropStyle = .blurredDesktop,
    reduceMotion: Bool?,
    reduceTransparency: Bool?,
    screen: NSScreen?
  ) -> UUID {
    let notification = RichNotification(
      illustration: illustration.build(),
      title: "Time for an eye break",
      message: "Look at something roughly 20 feet away until the ring finishes.",
      footnote: "Press ESC or click anywhere to skip",
      buttons: [
        StandardNotification.Button(title: "Done", style: .primary) {
          print("[demo] Done pressed — early acknowledgement expected")
        },
        StandardNotification.Button(title: "Snooze", style: .secondary) {
          print("[demo] Snooze pressed — cancel, no completion state")
        },
        StandardNotification.Button(title: "Skip", style: .destructive) {
          print("[demo] Skip pressed — cancel, no completion state")
        },
      ],
      taskTimer: TaskTimer(
        duration: duration, unitLabel: "seconds", completionLabel: "Break complete"),
      mode: .interrupt,
      acknowledgementLabel: "Got it")

    // The chosen break backdrop travels on the `Configuration`, which is also
    // what `showRich` reads to tell the renderer what is behind it — one value,
    // one owner. Judge this against a hostile pattern above: a painted backdrop
    // is opaque, so the pattern should disappear entirely rather than show
    // through, and that is what makes "the desktop is hidden" checkable rather
    // than asserted.
    let configuration = OverlayWindowManager.Configuration.interrupt(
      dismissOnScreenTap: dismissOnScreenTap, screen: screen, backdropStyle: backdropStyle)

    return present(
      notification, configuration: configuration, reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency)
  }

  // MARK: - Scenario: the web panel

  /// `.interrupt` with a live page in one column and the usual chrome in the
  /// other. The interesting thing to judge here is not the page — it is
  /// whether the rail still works beside one: the ring, the buttons and the
  /// text have to stay legible with a bright, arbitrary rectangle sitting next
  /// to them.
  ///
  /// Note there is no "dismiss on screen tap" knob. `RichNotificationView`
  /// suppresses the full-bleed tap target whenever a web panel is present —
  /// clicking into a game must not cancel the break.
  @discardableResult
  func showWebPanel(
    url: URL,
    placement: WebPanel.Placement,
    widthFraction: CGFloat,
    allowsAutoplay: Bool,
    loops: Bool = false,
    duration: TimeInterval,
    backdropStyle: BackdropStyle = .blurredDesktop,
    reduceMotion: Bool?,
    reduceTransparency: Bool?,
    screen: NSScreen?
  ) -> UUID {
    let notification = RichNotification(
      webPanel: WebPanel(
        url: url,
        placement: placement,
        widthFraction: widthFraction,
        allowsAutoplay: allowsAutoplay,
        loops: loops),
      title: "Rest your eyes",
      message: "Play until the ring finishes. Blink whenever you like — that is the point.",
      footnote: "Press ESC to skip",
      buttons: [
        StandardNotification.Button(title: "Done", style: .primary) {
          print("[demo] Done pressed — early acknowledgement expected")
        },
        StandardNotification.Button(title: "Skip", style: .destructive) {
          print("[demo] Skip pressed — cancel, no completion state")
        },
      ],
      taskTimer: TaskTimer(
        duration: duration, unitLabel: "seconds", completionLabel: "Break complete"),
      mode: .interrupt,
      acknowledgementLabel: "Got it")

    let configuration = OverlayWindowManager.Configuration.interrupt(
      dismissOnScreenTap: false, screen: screen, backdropStyle: backdropStyle)

    return present(
      notification, configuration: configuration, reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency)
  }

  // MARK: - Scenario: ambient, corner-positioned, multi-line

  /// `.ambient` mode with a title, a message deliberately long enough to wrap
  /// into several lines of varying width, and a dismiss indicator — the
  /// hardest case for the feathered scrim, since its ellipse has to reach zero
  /// alpha inside its own rect regardless of how tall or narrow the text block
  /// ends up being. No task timer: the dismiss clock arms immediately, so the
  /// indicator is visible the instant the window appears.
  @discardableResult
  func showAmbient(
    position: OverlayWindowManager.WindowPosition,
    indicator: DismissIndicator,
    dismissDelay: TimeInterval,
    reduceMotion: Bool?,
    reduceTransparency: Bool?,
    screen: NSScreen?
  ) -> UUID {
    let notification = RichNotification(
      title: "Synced to iCloud",
      message:
        "Your changes were saved just now. This pass also folded in two duplicate entries that were created earlier today while this Mac was offline.",
      autoDismiss: StandardNotification.AutoDismiss(delay: dismissDelay, indicator: indicator),
      mode: .ambient,
      acknowledgementLabel: "Got it")

    let configuration = OverlayWindowManager.Configuration.ambient(
      position: position, width: 380, height: 210, dismissOnScreenTap: true, screen: screen)

    return present(
      notification, configuration: configuration, reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency)
  }

  // MARK: - Presentation plumbing

  private func present(
    _ notification: RichNotification,
    configuration: OverlayWindowManager.Configuration,
    reduceMotion: Bool?,
    reduceTransparency: Bool?
  ) -> UUID {
    let windowsBeforeShow = Set(NSApp.windows.map(ObjectIdentifier.init))

    // `id` is reassigned from `showRich`'s return value immediately below;
    // the placeholder only exists so the `onEnd` closure — which cannot run
    // until at least the next run-loop turn, since it fires from a dismissal
    // and nothing dismisses synchronously inside `showRich` itself — has a
    // variable to close over. By the time it can possibly run, `id` already
    // holds the real value.
    var id = UUID()
    id = VibeNotify.shared.showRich(
      notification,
      configuration: configuration,
      reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency
    ) { [weak self] _ in
      // Fires however this overlay ended — a button, ESC, click-away, or the
      // countdown reaching its own end — which is what makes `activeIDs`
      // accurate without the lifetime-prediction workaround this used to
      // need (see the type's doc comment).
      self?.activeIDs.removeAll { $0 == id }
    }
    activeIDs.append(id)

    // WORKAROUND, not a fix: see `RichDemoPresenter.correctConstrainedFrame`
    // just below for what this is compensating for and why it lives here
    // instead of in the library. Only fixed-size windows are affected
    // visibly — `.interrupt` passes `width`/`height` as `nil` on purpose
    // (`AlertMode.interrupt`), so it never hits this branch.
    if let width = configuration.width, let height = configuration.height,
      let position = configuration.position
    {
      let screen = configuration.screen ?? NSScreen.main
      if let screen {
        correctConstrainedFrame(
          newlyCreatedAmong: windowsBeforeShow, position: position,
          size: CGSize(width: width, height: height), screen: screen)
      }
    }

    return id
  }

  // MARK: - Frame-blowup workaround (see task-8 report for the write-up)

  /// **A library defect, reproduced here, not fixed here.** `RichNotificationView`
  /// is the only one of the three renderers whose body calls `.ignoresSafeArea()`
  /// (`StandardNotificationView`, side by side, has no such call). Hosted as a
  /// raw `NSHostingView` content view of a fixed-size, `.borderless`
  /// `NSWindow` — exactly what `OverlayWindowManager.createWindow` builds for
  /// `.ambient` — that combination makes AppKit's Auto Layout resolve the
  /// window to a wildly different frame than the one it was created with,
  /// shortly after `contentView` is set. Measured directly against a
  /// `.ambient` window created at `(1328, 20, 380, 210)`: it settles at
  /// `(1328, -2084, 380, 2314)` — height off by roughly 10x, top edge held in
  /// place while the window balloons downward off-screen. `.interrupt` is
  /// built with `width`/`height` left `nil` on purpose (`AlertMode.interrupt`),
  /// so the same distortion likely still happens there, it is just invisible:
  /// the window already intends to cover the whole screen.
  ///
  /// This is exactly the gap between `Tests/VibeNotifyTests/LegibilityTests.swift`
  /// and real usage: `RichRendererLayoutTests` measures
  /// `NSHostingView.fittingSize` directly, never inside an actual `NSWindow`
  /// with a caller-supplied frame — so this defect has no failing test and
  /// was invisible until something (this harness) put the view in a real,
  /// size-constrained window.
  ///
  /// The workaround: after `OverlayWindowManager.show` returns, find the
  /// window it just created (the one absent from `windowsBeforeShow`) and
  /// stomp its frame back to the position `AlertMode.ambient`'s own
  /// `calculateFrameForPosition` would have produced, replicated here since
  /// that method is `private` to the library. Two passes, since the exact
  /// moment the layout pass corrupts the frame was not pinned down further —
  /// whichever one lands after it wins.
  private func correctConstrainedFrame(
    newlyCreatedAmong windowsBeforeShow: Set<ObjectIdentifier>,
    position: OverlayWindowManager.WindowPosition,
    size: CGSize,
    screen: NSScreen
  ) {
    let target = Self.intendedFrame(for: position, size: size, on: screen)
    func stomp() {
      guard
        let window = NSApp.windows.first(where: {
          !windowsBeforeShow.contains(ObjectIdentifier($0)) && $0.level == .floating
        })
      else { return }
      if window.frame != target {
        window.setFrame(target, display: true)
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: stomp)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: stomp)
  }

  /// `OverlayWindowManager.calculateFrameForPosition`, reproduced verbatim
  /// (same 20pt padding) for the four corners this demo's ambient picker
  /// offers, since the original is `private`.
  private static func intendedFrame(
    for position: OverlayWindowManager.WindowPosition, size: CGSize, on screen: NSScreen
  ) -> CGRect {
    let screenFrame = screen.frame
    let padding: CGFloat = 20
    let x: CGFloat
    let y: CGFloat
    switch position {
    case .topLeft:
      x = screenFrame.minX + padding
      y = screenFrame.maxY - size.height - padding
    case .topRight:
      x = screenFrame.maxX - size.width - padding
      y = screenFrame.maxY - size.height - padding
    case .bottomLeft:
      x = screenFrame.minX + padding
      y = screenFrame.minY + padding
    case .bottomRight:
      x = screenFrame.maxX - size.width - padding
      y = screenFrame.minY + padding
    default:
      x = screenFrame.midX - size.width / 2
      y = screenFrame.midY - size.height / 2
    }
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  func dismiss(id: UUID) {
    VibeNotify.shared.dismiss(id: id)
    activeIDs.removeAll { $0 == id }
  }

  func dismissAll() {
    VibeNotify.shared.dismissAll()
    activeIDs.removeAll()
  }
}
