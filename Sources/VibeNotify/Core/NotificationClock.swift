import AppKit
import SwiftUI

/// The countdown engine behind an overlay: one cancellable clock per notification,
/// owned by `OverlayWindowManager` and keyed by the same id as its window.
///
/// It exists because the dismiss timer used to be a bare
/// `DispatchQueue.main.asyncAfter` living *inside* each renderer's view body, which
/// produced three defects at once: it had no cancellation handle (a button tap or
/// ESC could not stop it), it had to be written twice byte-identically in two
/// renderers, and caller-supplied SwiftUI content got no timer at all — which is
/// why the consuming client had to schedule its own `asyncAfter` alongside `show`.
/// Moving it here fixes all three: the manager already owns the window, the ESC
/// handler and the tap-to-dismiss wiring, so it owns the clock too, and injects it
/// into the SwiftUI environment for anything that wants to *draw* the countdown.
///
/// Two design commitments worth not undoing:
///
/// - **Phases, never a race.** A `TaskTimer` and an `AutoDismiss` present together
///   run one after the other: the task runs first and alone, and the dismiss clock
///   arms the instant the task hits zero, its delay measured from that moment
///   (total = `duration + delay`). Earliest-deadline-wins was considered and
///   rejected: it lets a caller's habitual 5-second auto-dismiss ceiling silently
///   kill a 20-second eye break at second five.
/// - **`deadline` is a wall-clock `Date`, not a duration.** `asyncAfter` across a
///   system sleep is not a contract worth relying on; comparing `Date()` against a
///   stored deadline is. See `evaluate(afterWake:)` for what a deadline that
///   elapsed while the machine slept means (spoiler: a task did *not* complete).
@MainActor
public final class NotificationClock: ObservableObject {

  // MARK: - Phase

  public enum Phase: Sendable, Equatable {
    /// Counting down the user-facing exercise (`TaskTimer`). No dismiss
    /// indicator is drawn during this phase — it belongs to the next one.
    case task
    /// Counting down to automatic dismissal. Entered directly when there is no
    /// task timer, or from `.task` the moment the task reaches zero.
    case dismissing
    /// Ran to completion. The window should close.
    case finished
    /// Stopped early — Skip, Snooze, ESC, click-away, teardown, or a task whose
    /// deadline elapsed while the machine was asleep. Never a completion.
    case cancelled

    var isTerminal: Bool { self == .finished || self == .cancelled }
  }

  // MARK: - Tuning

  /// How often the clock re-reads the wall clock. The countdown *value* is
  /// derived from `deadline`, never accumulated from ticks, so this only sets
  /// redraw granularity and worst-case dismissal lateness — not accuracy.
  static let tickInterval: TimeInterval = 0.1

  /// How long a completed task holds its completion state before the window
  /// goes away, when the caller configured no `AutoDismiss` of their own.
  /// Long enough to read "Break complete", short enough not to loiter.
  public static let completionHold: TimeInterval = 1.5

  /// A tick arriving this far past its deadline was not late — the process was
  /// suspended (lid closed, App Nap, a wedged main thread). Treated the same as
  /// an explicit wake notification, because the deadline passed *unobserved*
  /// either way, and `NSWorkspace.didWakeNotification` does not fire for every
  /// form of suspension. Deliberately generous: the cost of being wrong in the
  /// tolerant direction is one late-but-honest dismissal, while being wrong in
  /// the strict direction cancels a task the user actually sat through.
  static let suspensionTolerance: TimeInterval = 5.0

  // MARK: - Identity

  /// The overlay id this clock belongs to.
  public let id: UUID

  /// Monotonically increasing token, minted per clock. Ids get recycled here
  /// (the consuming client tracks a single active overlay id and reshows), so a
  /// timer callback carries `(id, generation)` and the manager no-ops on
  /// mismatch — the same class of guard as the identity check in
  /// `animateDismiss`, which stops a stale fade completion from evicting a
  /// fresher window that has since claimed the id.
  public let generation: Int

  private static var generationCounter: Int = 0

  static func nextGeneration() -> Int {
    generationCounter += 1
    return generationCounter
  }

  // MARK: - Inputs

  public let task: TaskTimer?
  public let autoDismiss: StandardNotification.AutoDismiss?

  // MARK: - State

  @Published public private(set) var phase: Phase

  /// Wall-clock instant the current phase ends. Re-armed when `.task` hands
  /// over to `.dismissing`.
  @Published public private(set) var deadline: Date

  /// True once the task phase ended *on its own terms* — ran to zero, or the
  /// user pressed Done. Stays false for every cancellation, including a task
  /// whose deadline elapsed while the machine slept: the user did not do the
  /// exercise, and a surface claiming otherwise is lying.
  @Published public private(set) var didCompleteTask: Bool = false

  /// Bumped on every tick purely so SwiftUI redraws a view that reads
  /// `remaining` or `progress` (both of which are computed, not published).
  @Published public private(set) var lastTick: Date

  private var phaseStart: Date
  private let currentDate: @MainActor () -> Date
  private let onEnd: (@MainActor (UUID, Int) -> Void)?
  private var timer: Timer?
  private var wakeObserver: (any NSObjectProtocol)?

  // MARK: - Derived

  /// Seconds left in the current phase, derived from the wall-clock deadline —
  /// so it stays correct across missed ticks and system sleep. Never negative.
  public var remaining: TimeInterval {
    guard !phase.isTerminal else { return 0 }
    return max(0, deadline.timeIntervalSince(currentDate()))
  }

  /// Fraction of the current phase elapsed, `0...1`. What a draining bar or a
  /// ring stroke reads.
  public var progress: Double {
    guard !phase.isTerminal else { return 1 }
    let total = deadline.timeIntervalSince(phaseStart)
    guard total > 0 else { return 1 }
    return min(1, max(0, (total - remaining) / total))
  }

  /// What the *dismiss* indicator should draw right now. Deliberately `.none`
  /// during the task phase: the alert is not closing yet, and saying it is
  /// misreads the situation.
  public var indicator: DismissIndicator {
    switch phase {
    case .task, .finished, .cancelled: return .none
    case .dismissing: return autoDismiss?.indicator ?? .none
    }
  }

  // MARK: - Init

  /// Fails when the countdown has neither half — "both nil means no clock at
  /// all", so the manager installs nothing and schedules nothing rather than
  /// carrying an inert object around.
  ///
  /// `currentDate` is the test seam: production takes the default, tests inject
  /// a mutable fake and drive `tick()` by hand, which is why not one test here
  /// sleeps against a real deadline.
  public init?(
    id: UUID,
    countdown: Countdown,
    generation: Int? = nil,
    currentDate: @escaping @MainActor () -> Date = { Date() },
    onEnd: (@MainActor (UUID, Int) -> Void)? = nil
  ) {
    guard countdown.task != nil || countdown.autoDismiss != nil else { return nil }

    self.id = id
    self.generation = generation ?? NotificationClock.nextGeneration()
    self.task = countdown.task
    self.autoDismiss = countdown.autoDismiss
    self.currentDate = currentDate
    self.onEnd = onEnd

    let start = currentDate()
    self.phaseStart = start
    self.lastTick = start

    if let task = countdown.task {
      self.phase = .task
      self.deadline = start.addingTimeInterval(task.duration)
    } else {
      // Non-nil by the guard above.
      self.phase = .dismissing
      self.deadline = start.addingTimeInterval(countdown.autoDismiss?.delay ?? 0)
    }
  }

  // MARK: - Lifecycle

  /// Starts ticking and subscribes to wake. Separate from `init` so tests can
  /// construct a clock and step it deterministically without a live run loop —
  /// and so the manager can start it only once the window is actually on screen.
  func start() {
    guard timer == nil, !phase.isTerminal else { return }

    let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] timer in
      guard let self else {
        // The clock went away without being stopped; don't leave the run loop
        // firing into nothing. Invalidated here rather than inside
        // `assumeIsolated` because `Timer` is not `Sendable` and must not cross
        // the isolation boundary — `invalidate()` on the timer's own run loop is
        // exactly where it belongs anyway.
        timer.invalidate()
        return
      }
      MainActor.assumeIsolated { self.tick() }
    }
    // `.common` so the countdown keeps running during menu tracking / live resize.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer

    // Force a re-evaluation on wake rather than waiting for the next tick: the
    // deadline may be hours in the past by the time the machine comes back.
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.handleWake() }
    }
  }

  /// User-driven stop: Skip, Snooze, ESC, click-away. Produces no completion
  /// state and *does* report the end, so the window comes down with it. Calling
  /// this on an already-terminal clock is a no-op, which is what makes the
  /// `cancel()` → dismiss → `invalidate()` round trip re-entrancy safe.
  public func cancel() {
    terminate(.cancelled, notify: true)
  }

  /// Teardown-driven stop, used by `OverlayWindowManager.dismiss`. Identical to
  /// `cancel()` except it reports nothing — the window is already on its way
  /// out, and telling the manager to dismiss it again would be a loop.
  func invalidate() {
    terminate(.cancelled, notify: false)
  }

  /// "Done" — ends the task phase *now*. The dismiss delay is then measured
  /// from this moment, not from the deadline the task would have had.
  public func completeTask() {
    guard phase == .task else { return }
    endTaskPhase(at: currentDate(), completed: true)
  }

  // MARK: - Evaluation

  /// One step of the clock. Internal rather than private so tests can drive it
  /// against an injected `currentDate` instead of sleeping.
  func tick() {
    evaluate(afterWake: false)
  }

  /// `NSWorkspace.didWakeNotification` handler, also called directly by tests.
  func handleWake() {
    evaluate(afterWake: true)
  }

  private func evaluate(afterWake: Bool) {
    guard !phase.isTerminal else {
      stop()
      return
    }

    let now = currentDate()
    lastTick = now

    guard now >= deadline else { return }

    // Did anyone actually observe this deadline pass, or did the machine skip
    // over it? A wake notification says so outright; an enormous overshoot on
    // an otherwise 0.1s tick says the same thing.
    let elapsedUnobserved = afterWake || now.timeIntervalSince(deadline) > Self.suspensionTolerance

    switch phase {
    case .task:
      if elapsedUnobserved {
        // The user did not do the exercise — they were asleep, or the app was.
        // Take the window down, but never claim a completion.
        terminate(.cancelled, notify: true)
      } else {
        endTaskPhase(at: deadline, completed: true)
      }
    case .dismissing:
      // A stale auto-dismiss has no honesty problem: the alert has outlived its
      // usefulness either way.
      terminate(.finished, notify: true)
    case .finished, .cancelled:
      break
    }
  }

  /// Hands `.task` over to `.dismissing`. `end` is the instant the task phase
  /// ended — its own deadline when it ran to zero (so the total stays exactly
  /// `duration + delay` regardless of tick jitter), or "now" when the user
  /// pressed Done.
  private func endTaskPhase(at end: Date, completed: Bool) {
    didCompleteTask = completed
    phaseStart = end
    phase = .dismissing
    // With no caller-supplied auto-dismiss, a completed task still needs to go
    // away by itself: hold the completion state for a short beat, then close.
    deadline = end.addingTimeInterval(autoDismiss?.delay ?? Self.completionHold)
  }

  private func terminate(_ newPhase: Phase, notify: Bool) {
    stop()
    guard !phase.isTerminal else { return }
    phase = newPhase
    if notify { onEnd?(id, generation) }
  }

  private func stop() {
    timer?.invalidate()
    timer = nil
    if let wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
      self.wakeObserver = nil
    }
  }
}

// MARK: - Environment injection

private struct NotificationClockEnvironmentKey: EnvironmentKey {
  static let defaultValue: NotificationClock? = nil
}

extension EnvironmentValues {
  /// The clock driving the overlay this view is inside, if any.
  ///
  /// `OverlayWindowManager.show(id:configuration:countdown:content:)` injects it
  /// around the hosting view, which is how *caller-supplied* SwiftUI content
  /// inherits a countdown without asking for one — the third of the three
  /// defects this type exists to kill. Optional rather than an
  /// `@EnvironmentObject` on purpose: a missing environment object is a crash,
  /// and "this overlay has no countdown" is an ordinary, expected state.
  public var notificationClock: NotificationClock? {
    get { self[NotificationClockEnvironmentKey.self] }
    set { self[NotificationClockEnvironmentKey.self] = newValue }
  }
}
