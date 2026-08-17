import AppKit
import SwiftUI
import VibeNotify

/// Where every configuration this harness can drive is assembled, and the one
/// place that actually calls into `OverlayWindowManager`.
///
/// `VibeNotify.shared` (the `show`/`showSVG` convenience API) has no entry
/// point for `RichNotification` at all — there is no `showRich`. That is not a
/// gap this file works around; it is presenting the rich renderer exactly the
/// way its own tests do (`Tests/VibeNotifyTests/LegibilityTests.swift`): build
/// a `RichNotificationView` and hand it to `OverlayWindowManager.show(id:
/// configuration:countdown:content:)` directly. Both of those are public API,
/// so nothing here is reaching past what a real caller could do — it is worth
/// flagging in the report as the one piece of friction, since a plugin author
/// wiring up a real eye-break reminder would hit the same absence.
@MainActor
final class RichDemoPresenter: ObservableObject {

  /// Ids of everything currently on screen, purely so the control panel can
  /// show a live count and offer "Dismiss All".
  @Published private(set) var activeIDs: [UUID] = []

  private let manager = OverlayWindowManager.shared

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
  static let momoPNGPath = repoRoot.appendingPathComponent("res/img/hungry_momo.png").path

  enum IllustrationChoice: String, CaseIterable, Identifiable {
    case svg = "SVG (eye.svg)"
    case bitmap = "Bitmap (hungry_momo.png)"
    case symbol = "SF Symbol"
    case none = "None"

    var id: String { rawValue }

    @MainActor
    func build() -> RichNotification.Illustration? {
      switch self {
      case .svg:
        return .svg(.filePath(RichDemoPresenter.eyeSVGPath), size: CGSize(width: 220, height: 150))
      case .bitmap:
        guard let image = NSImage(contentsOfFile: RichDemoPresenter.momoPNGPath) else { return nil }
        return .image(image, size: CGSize(width: 180, height: 180))
      case .symbol:
        return .symbol("eye.fill", pointSize: 56, color: nil)
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

    let configuration = OverlayWindowManager.Configuration.interrupt(
      dismissOnScreenTap: dismissOnScreenTap, screen: screen)

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
    let id = UUID()
    let windowsBeforeShow = Set(NSApp.windows.map(ObjectIdentifier.init))

    manager.show(id: id, configuration: configuration, countdown: notification.countdown) { [weak self] in
      RichNotificationView(
        notification: notification,
        reduceMotion: reduceMotion,
        reduceTransparency: reduceTransparency
      ) {
        self?.dismiss(id: id)
      }
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

    // A clock that reaches its own deadline closes the window through
    // `OverlayWindowManager.clockDidEnd` directly — that path never calls the
    // `onDismiss` closure above, which only fires for the *user*-driven exits
    // (click-away, ESC, a button). There is no public signal on this library
    // for "an overlay closed itself" (`OverlayWindowManager.activeWindows` is
    // `internal`, reachable only via `@testable import`), so the only way
    // this counter stays honest for a countdown that simply ran out is to
    // predict its own lifetime and sweep after it — worth flagging in the
    // report as a real gap a production caller doing the same bookkeeping
    // would also hit.
    if let lifetime = Self.expectedLifetime(of: notification) {
      DispatchQueue.main.asyncAfter(deadline: .now() + lifetime + 0.5) { [weak self] in
        self?.activeIDs.removeAll { $0 == id }
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

  /// Mirrors `NotificationClock`'s own phase arithmetic
  /// (`endTaskPhase(at:completed:)`) purely to predict when an unattended
  /// countdown will close its window on its own. `nil` when there is no
  /// countdown at all — such an overlay never self-dismisses, so only
  /// `dismiss(id:)` ever removes it.
  private static func expectedLifetime(of notification: RichNotification) -> TimeInterval? {
    guard let countdown = notification.countdown else { return nil }
    let taskDuration = countdown.task?.duration ?? 0
    let dismissDelay =
      countdown.autoDismiss?.delay ?? (countdown.task != nil ? NotificationClock.completionHold : 0)
    return taskDuration + dismissDelay
  }

  func dismiss(id: UUID) {
    manager.dismiss(id: id)
    activeIDs.removeAll { $0 == id }
  }

  func dismissAll() {
    manager.dismissAll()
    activeIDs.removeAll()
  }
}
