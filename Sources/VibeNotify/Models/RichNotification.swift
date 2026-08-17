import AppKit
import SwiftUI

/// The content model for `RichNotificationView` — a third path added alongside
/// `StandardNotification` and `SVGNotification`, neither of which changes.
///
/// It exists because an illustration and buttons cannot coexist in either
/// existing model: `SVGNotification` has no `buttons` property at all, and
/// `StandardNotification`'s renderer maps SVG and URL icons to `EmptyView()`
/// and pins bitmaps to a hardcoded 48×48. Retrofitting either means preserving
/// the old behaviour behind a flag — a renderer with a "behave like 0.0.5" flag
/// is two renderers wearing one name. This one touches nothing that ships
/// today; if it is wrong, it is deleted.
public struct RichNotification {

  // MARK: - Illustration

  /// Size lives *inside* each case rather than as a sibling property: an SF
  /// Symbol is sized by a point size and a bitmap or SVG by a `CGSize`, and one
  /// shared `CGSize` would force a caller to encode a font size as a square
  /// rectangle. This is also the field that makes the illustration arbitrary —
  /// the fixed 48×48 in `StandardNotificationView` is the defect being escaped.
  ///
  /// All three cases have a named consumer: `.image` for the plugin alert
  /// presenter, which is handed an already-fetched `NSImage` (fetching goes
  /// through core's reverse proxy with a session cookie, so handing VibeNotify
  /// a URL would re-fetch unauthenticated and fail); `.symbol` for the schedule
  /// path's no-SVG fallback; `.svg` for everything else.
  public enum Illustration {
    case svg(SVGSource, size: CGSize)
    case image(NSImage, size: CGSize)
    case symbol(String, pointSize: CGFloat, color: Color?)

    /// The frame this illustration occupies, with a symbol's point size read as
    /// a square. Used for layout and for asserting sizes without a screen.
    public var pixelSize: CGSize {
      switch self {
      case .svg(_, let size), .image(_, let size):
        return size
      case .symbol(_, let pointSize, _):
        return CGSize(width: pointSize, height: pointSize)
      }
    }
  }

  // MARK: - Stored

  public let illustration: Illustration?
  public let title: String?
  public let message: String?
  /// A fifth text slot, pinned below the ring — "Press ESC or click anywhere to
  /// skip". Separate from `message` because it styles differently and because
  /// in `.ambient` it is usually absent.
  public let footnote: String?
  /// Drawn horizontally below the ring and above the footnote, in the caller's
  /// order. `StandardNotification.Button` is reused verbatim: already public,
  /// already `Identifiable`, and already carrying the three-case style a
  /// Done / Snooze / Skip row needs. A parallel type would fork the type the
  /// consuming client's own action model already bridges to.
  public let buttons: [StandardNotification.Button]
  public let taskTimer: TaskTimer?
  public let autoDismiss: StandardNotification.AutoDismiss?
  /// `mode` sits on the model, not only on the window `Configuration`, because
  /// the renderer must read it to choose between the two legibility strategies.
  /// The presenter derives the `Configuration` from the mode so the two cannot
  /// disagree.
  public let mode: AlertMode
  /// What the surface says when Done is pressed *early*. Deliberately not the
  /// timer's `completionLabel`: see `completionState(phase:didCompleteTask:completedEarly:)`.
  public let acknowledgementLabel: String

  public init(
    illustration: Illustration? = nil,
    title: String? = nil,
    message: String? = nil,
    footnote: String? = nil,
    buttons: [StandardNotification.Button] = [],
    taskTimer: TaskTimer? = nil,
    autoDismiss: StandardNotification.AutoDismiss? = nil,
    mode: AlertMode = .ambient,
    acknowledgementLabel: String = "Got it"
  ) {
    self.illustration = illustration
    self.title = title
    self.message = message
    self.footnote = footnote
    self.buttons = buttons
    self.taskTimer = taskTimer
    self.autoDismiss = autoDismiss
    self.mode = mode
    self.acknowledgementLabel = acknowledgementLabel
  }

  // MARK: - Countdown

  /// The `Countdown` to hand `OverlayWindowManager.show(id:configuration:countdown:content:)`,
  /// derived from this model so the renderer and the clock cannot disagree
  /// about what is being timed. `nil` when neither half is set, matching
  /// `NotificationClock.init?` — both nil means no clock at all, not an inert
  /// object carried around.
  public var countdown: Countdown? {
    guard effectiveTaskTimer != nil || autoDismiss != nil else { return nil }
    return Countdown(task: effectiveTaskTimer, autoDismiss: autoDismiss)
  }

  /// The task timer that actually runs, which is not always the one the caller
  /// stored.
  ///
  /// **`.ambient` gets the dismiss indicator only.** A large labelled ring reads
  /// as a task, and in ambient mode there is no task — the number would answer a
  /// question the user did not ask. That rule was prose in the spec and prose in
  /// a doc comment, which is to say it was enforced nowhere: nothing stopped
  /// `RichNotification(taskTimer:, mode: .ambient)` from putting a 148pt ring
  /// with white numerals on a toast that has no scrim under it.
  ///
  /// Enforced here rather than in the renderer so that `countdown` agrees with
  /// what is drawn. If the renderer alone ignored the timer, the clock would
  /// still run a task phase and the toast would sit on screen for
  /// `duration + delay` with nothing drawn to explain why. The caller's stored
  /// `taskTimer` is left untouched — this reinterprets it, it does not rewrite
  /// what they passed.
  public var effectiveTaskTimer: TaskTimer? {
    mode == .ambient ? nil : taskTimer
  }

  // MARK: - Dismiss indicator

  /// What the quiet "this closes in N" indicator should be in `phase`.
  ///
  /// A task timer suppresses it outright while running, even when the caller
  /// configured one: there is exactly one number on screen at a time, and it is
  /// the one the user is meant to obey. The two are sequential phases, never a
  /// race — the task runs first and alone, and the dismiss clock arms the
  /// moment it hits zero.
  ///
  /// This mirrors `NotificationClock.indicator` on purpose rather than calling
  /// it: the clock answers for the *clock's* configuration, and this answers
  /// for the model the renderer was handed, which is what the renderer actually
  /// draws from. They are asserted against the same rule in two test files.
  public func dismissIndicator(in phase: NotificationClock.Phase) -> DismissIndicator {
    switch phase {
    case .task, .finished, .cancelled:
      return .none
    case .dismissing:
      return autoDismiss?.indicator ?? .none
    }
  }

  // MARK: - Completion

  /// What the ring's centre says once the task phase is over.
  ///
  /// The honesty rule, and the reason `completedEarly` is a separate input from
  /// `didCompleteTask`: the user asked for confirmation that a break
  /// *completed*. A surface saying so when seventeen of twenty seconds were
  /// skipped is telling them something false about their own health.
  ///
  /// - Reaching zero → the caller's `completionLabel` ("Break complete").
  /// - Done pressed early → `acknowledgementLabel` ("Got it") and nothing
  ///   claiming a completed break.
  /// - Skip, Snooze, ESC, click-away, or a deadline that elapsed while the
  ///   machine slept → nothing at all. The clock reports
  ///   `didCompleteTask == false` for every one of them.
  public func completionState(
    phase: NotificationClock.Phase,
    didCompleteTask: Bool,
    completedEarly: Bool
  ) -> CompletionState {
    // `effectiveTaskTimer`, not the stored `taskTimer`. Unreachable today —
    // an `.ambient` alert gets no task phase, so `didCompleteTask` cannot
    // become true for one — but the two accessors have already diverged once,
    // and reading the wrong one here is precisely how an ambient toast would
    // come to announce "Break complete" for a break that was never offered.
    // The completion rules exist to stop the surface saying things that are
    // not true; they should not depend on a second property staying in sync.
    guard let timer = effectiveTaskTimer, didCompleteTask, phase != .task, phase != .cancelled
    else { return .none }
    return completedEarly
      ? .acknowledged(label: acknowledgementLabel)
      : .completed(label: timer.completionLabel)
  }

  /// The three things the centre of the ring can say after the task phase.
  public enum CompletionState: Equatable, Sendable {
    case none
    /// Ran to zero. The ring stroke shifts to the success colour.
    case completed(label: String)
    /// Done pressed early. The arc **snaps** to full rather than animating
    /// there — a fast fill reads as "the timer sped up", which is confusing
    /// about what just happened.
    case acknowledged(label: String)

    public var label: String? {
      switch self {
      case .none: return nil
      case .completed(let label), .acknowledged(let label): return label
      }
    }

    /// Only a genuine completion earns the success colour.
    public var isCompletion: Bool {
      if case .completed = self { return true }
      return false
    }
  }

  // MARK: - Button outcomes

  /// What the library does to the clock and the window when a button is
  /// pressed. The caller's closure supplies the *meaning*; this supplies the
  /// *dismissal*, and it always ends in the window coming down — a Snooze that
  /// leaves the interrupt on screen is not a snooze, and a plugin's "Turn off"
  /// must work without the caller holding the window id.
  ///
  /// Done is routed through the clock rather than dismissing inline, which is
  /// the one place this departs from `StandardNotificationView`'s
  /// "`action()` then `onDismiss()`" shape. Dismissing in the same turn as
  /// `completeTask()` would make the acknowledgement state exist for exactly
  /// zero frames, and the acknowledgement is the whole point of pressing Done
  /// rather than Skip. `completeTask()` hands `.task` to `.dismissing` with a
  /// deadline of `completionHold` (or the caller's own auto-dismiss delay), and
  /// the manager tears the window down when that expires — so the guarantee
  /// "every button dismisses" holds either way, one of them just via the clock
  /// that already owns the lifetime.
  public enum ButtonOutcome: Equatable, Sendable {
    /// `clock.completeTask()`, then let the clock's dismiss phase close it.
    case completeTaskThenHold
    /// `clock.cancel()`, then `onDismiss()`. No completion state, immediate fade.
    case cancelAndDismiss
    /// Nothing to complete and no clock to wait on: `onDismiss()` directly, or
    /// the window never comes down.
    case dismiss
  }

  /// Pure so the routing is assertable without pressing anything.
  public static func outcome(
    for style: StandardNotification.Button.ButtonStyle,
    taskPhaseActive: Bool,
    hasClock: Bool
  ) -> ButtonOutcome {
    switch style {
    case .primary:
      return (hasClock && taskPhaseActive) ? .completeTaskThenHold : .dismiss
    case .secondary, .destructive:
      return hasClock ? .cancelAndDismiss : .dismiss
    }
  }
}
