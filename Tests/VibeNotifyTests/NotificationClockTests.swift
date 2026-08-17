import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

/// Task 7 adds only *types* — `TaskTimer`, `DismissIndicator`, and the
/// `Countdown` pair that Task 6's `show(id:configuration:countdown:content:)`
/// will consume. No clock, no renderer here; this file just pins the shape
/// and the backward-compatible mapping from the old `showProgress: Bool`.
struct NotificationClockTests {

  // MARK: - AutoDismiss backward-compat shim

  /// The deprecated `showProgress: true` spelling must keep meaning "show
  /// something" — mapped onto the new `.bar` indicator so the two existing
  /// renderers (which read `autoDismiss.showProgress`) see no behavior change.
  @Test func autoDismissShowProgressTrueMapsToBarIndicator() {
    let autoDismiss = StandardNotification.AutoDismiss(delay: 3.0, showProgress: true)
    #expect(autoDismiss.indicator == .bar)
  }

  /// `showProgress: false` (and the implicit default) must map onto `.none` —
  /// no indicator at all, matching today's "no progress view" behavior.
  @Test func autoDismissShowProgressFalseMapsToNoneIndicator() {
    let autoDismiss = StandardNotification.AutoDismiss(delay: 3.0, showProgress: false)
    #expect(autoDismiss.indicator == .none)
  }

  /// The default-argument spelling (`showProgress` omitted entirely) is the
  /// most common existing call shape outside this library — it must still
  /// compile and must still mean `.none`.
  @Test func autoDismissDefaultInitOmittingShowProgressMapsToNoneIndicator() {
    let autoDismiss = StandardNotification.AutoDismiss(delay: 3.0)
    #expect(autoDismiss.indicator == .none)
  }

  /// The old `showProgress` reader that both existing renderers use must keep
  /// reporting `true` for `.bar` so `StandardNotificationView` and
  /// `SVGNotificationView` render byte-identically without being touched.
  @Test func autoDismissShowProgressReaderReflectsBarIndicator() {
    let barDismiss = StandardNotification.AutoDismiss(delay: 3.0, showProgress: true)
    #expect(barDismiss.showProgress == true)

    let noneDismiss = StandardNotification.AutoDismiss(delay: 3.0, showProgress: false)
    #expect(noneDismiss.showProgress == false)
  }

  // MARK: - TaskTimer

  /// `TaskTimer` carries the caller's own vocabulary for what it's counting —
  /// the library never infers a unit or completion message.
  @Test func taskTimerStoresCallerSuppliedFields() {
    let timer = TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete")
    #expect(timer.duration == 20)
    #expect(timer.unitLabel == "seconds")
    #expect(timer.completionLabel == "Break complete")
  }

  // MARK: - DismissIndicator

  /// All three indicator cases must exist and be distinguishable — the
  /// engine (next task) switches on this to decide bar vs. hairline ring vs.
  /// nothing.
  @Test func dismissIndicatorHasThreeDistinctCases() {
    let cases: [DismissIndicator] = [.none, .bar, .hairlineRing]
    #expect(Set(cases.map(String.init(describing:))).count == 3)
  }

  // MARK: - Countdown

  /// `Countdown` is the single value Task 6's `show()` accepts; either half
  /// may be nil independently, and both nil means no clock at all.
  @Test func countdownAllowsEitherOrBothHalvesToBeNil() {
    let bothNil = Countdown(task: nil, autoDismiss: nil)
    #expect(bothNil.task == nil)
    #expect(bothNil.autoDismiss == nil)

    let taskOnly = Countdown(
      task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
      autoDismiss: nil
    )
    #expect(taskOnly.task != nil)
    #expect(taskOnly.autoDismiss == nil)

    let autoDismissOnly = Countdown(
      task: nil,
      autoDismiss: StandardNotification.AutoDismiss(delay: 3.0, indicator: .hairlineRing)
    )
    #expect(autoDismissOnly.task == nil)
    #expect(autoDismissOnly.autoDismiss?.indicator == .hairlineRing)
  }

  // MARK: - New non-deprecated AutoDismiss initializer

  /// The new spelling — `indicator:` instead of `showProgress:` — must be
  /// usable directly, including the added `.hairlineRing` case that has no
  /// `Bool` equivalent in the old API.
  @Test func autoDismissNewInitializerAcceptsIndicatorDirectly() {
    let autoDismiss = StandardNotification.AutoDismiss(delay: 5.0, indicator: .hairlineRing)
    #expect(autoDismiss.delay == 5.0)
    #expect(autoDismiss.indicator == .hairlineRing)
  }
}

// MARK: - Test doubles

/// The injectable "now". Every engine test below drives time by mutating this
/// and calling `tick()` explicitly — no `Task.sleep`, no wall-clock races. The
/// only reason the production clock takes a `currentDate` closure at all is to
/// make this possible; production uses the default `{ Date() }`.
@MainActor
final class FakeTime {
  var now: Date

  init(_ now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
    self.now = now
  }

  func advance(_ interval: TimeInterval) {
    now = now.addingTimeInterval(interval)
  }

  /// Handed to `NotificationClock(currentDate:)`.
  var source: @MainActor () -> Date {
    { [self] in self.now }
  }
}

/// Records the `(id, generation)` pairs a clock reports when it decides the
/// window should close. A reference type because the closure escapes.
@MainActor
final class EndRecorder {
  var ends: [(id: UUID, generation: Int)] = []

  var handler: @MainActor (UUID, Int) -> Void {
    { [self] id, generation in self.ends.append((id, generation)) }
  }
}

// MARK: - The clock engine

/// Task 6: the cancellable, sleep-safe clock the window manager owns.
@MainActor
struct NotificationClockEngineTests {

  private func makeClock(
    _ countdown: Countdown,
    time: FakeTime,
    recorder: EndRecorder = EndRecorder(),
    id: UUID = UUID()
  ) throws -> NotificationClock {
    try #require(
      NotificationClock(
        id: id,
        countdown: countdown,
        currentDate: time.source,
        onEnd: recorder.handler
      ))
  }

  // MARK: Sequential phases

  /// The load-bearing semantic: a task timer and an auto-dismiss are two
  /// *phases*, not a race. Earliest-deadline-wins was explicitly rejected —
  /// it lets a caller's habitual 5s ceiling silently kill a 20s eye break at
  /// second five. Total on-screen time must be `duration + delay` (23s), and
  /// at second 5 (the auto-dismiss delay) the alert must still be counting
  /// the task down, not gone.
  @Test func taskAndAutoDismissRunSequentiallyNotAsARace() throws {
    let time = FakeTime()
    let start = time.now
    let recorder = EndRecorder()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3, indicator: .hairlineRing)
      ),
      time: time,
      recorder: recorder
    )

    #expect(clock.phase == .task)
    #expect(clock.deadline == start.addingTimeInterval(20))

    // At second 3 — the auto-dismiss delay — nothing may happen. This is the
    // "not a race" assertion.
    time.advance(3)
    clock.tick()
    #expect(clock.phase == .task, "the auto-dismiss delay must not fire during the task phase")
    #expect(recorder.ends.isEmpty)

    // Task reaches zero: the dismiss clock arms *from that moment*.
    time.advance(17)
    clock.tick()
    #expect(clock.phase == .dismissing)
    #expect(clock.didCompleteTask, "reaching zero on its own is a completion")
    #expect(
      clock.deadline == start.addingTimeInterval(23),
      "total on-screen time must be duration + delay, not min(duration, delay)")
    #expect(recorder.ends.isEmpty, "the window must not close yet")

    // And only now does it end.
    time.advance(3)
    clock.tick()
    #expect(clock.phase == .finished)
    #expect(recorder.ends.count == 1)
    #expect(recorder.ends.first?.id == clock.id)
    #expect(recorder.ends.first?.generation == clock.generation)
  }

  /// During the task phase no dismiss indicator is drawn, even though an
  /// auto-dismiss with a visible indicator is configured — it belongs to the
  /// second phase, and drawing it early tells the user the wrong story.
  @Test func noDismissIndicatorDuringTaskPhase() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3, indicator: .bar)
      ),
      time: time
    )

    #expect(clock.indicator == .none)

    time.advance(20)
    clock.tick()
    #expect(clock.indicator == .bar)
  }

  /// A task timer with no auto-dismiss still ends by itself: reaching zero
  /// holds a completion state for a short beat, then dismisses.
  @Test func taskWithoutAutoDismissHoldsCompletionThenFinishes() throws {
    let time = FakeTime()
    let recorder = EndRecorder()
    let clock = try makeClock(
      Countdown(task: TaskTimer(duration: 5, unitLabel: "seconds", completionLabel: "Done")),
      time: time,
      recorder: recorder
    )

    time.advance(5)
    clock.tick()
    #expect(clock.phase == .dismissing)
    #expect(clock.didCompleteTask)
    #expect(clock.indicator == .none, "no auto-dismiss was configured, so nothing to draw")
    #expect(recorder.ends.isEmpty, "the completion state must be held, not skipped")

    time.advance(NotificationClock.completionHold)
    clock.tick()
    #expect(clock.phase == .finished)
    #expect(recorder.ends.count == 1)
  }

  // MARK: completeTask / cancel

  /// "Done" ends the task phase *now* — and the dismiss delay is measured
  /// from that moment, not from the original deadline.
  @Test func completeTaskMovesTaskPhaseToDismissing() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3)
      ),
      time: time
    )

    time.advance(4)
    let doneAt = time.now
    clock.completeTask()

    #expect(clock.phase == .dismissing)
    #expect(clock.didCompleteTask)
    #expect(clock.deadline == doneAt.addingTimeInterval(3))
  }

  /// Skip / Snooze / ESC / click-away. No completion state, ever — the user
  /// did not do the exercise.
  @Test func cancelProducesNoCompletionState() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3)
      ),
      time: time
    )

    time.advance(4)
    clock.cancel()

    #expect(clock.phase == .cancelled)
    #expect(clock.didCompleteTask == false)

    // A cancelled clock is inert: later time cannot resurrect it into a
    // completion or a second dismissal.
    time.advance(100)
    clock.tick()
    #expect(clock.phase == .cancelled)
    #expect(clock.didCompleteTask == false)
  }

  /// `completeTask()` is only meaningful during the task phase; calling it on
  /// a cancelled clock must not fabricate a completion.
  @Test func completeTaskAfterCancelIsIgnored() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")),
      time: time
    )

    clock.cancel()
    clock.completeTask()

    #expect(clock.phase == .cancelled)
    #expect(clock.didCompleteTask == false)
  }

  // MARK: Sleep safety

  /// `deadline` is a wall-clock `Date` precisely so this case is decidable. A
  /// task timer whose deadline passed while the machine slept must be
  /// cancelled, never finished: the user did not look 20 feet away for 20
  /// seconds, and a surface claiming otherwise is lying. The window must
  /// still close.
  @Test func taskDeadlinePassedWhileAsleepYieldsCancelledNotFinished() throws {
    let time = FakeTime()
    let recorder = EndRecorder()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3)
      ),
      time: time,
      recorder: recorder
    )

    // The lid closed at second 2 and reopened two hours later.
    time.advance(7200)
    clock.handleWake()

    #expect(clock.phase == .cancelled)
    #expect(clock.phase != .finished)
    #expect(clock.didCompleteTask == false, "a slept-through task is not a completed task")
    #expect(recorder.ends.count == 1, "the stale window must still be taken down")
  }

  /// The dismiss phase has no such honesty problem — a notification whose
  /// auto-dismiss elapsed during sleep is simply stale and goes away.
  @Test func dismissDeadlinePassedWhileAsleepFinishes() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(autoDismiss: StandardNotification.AutoDismiss(delay: 5, indicator: .bar)),
      time: time
    )

    #expect(clock.phase == .dismissing)

    time.advance(7200)
    clock.handleWake()
    #expect(clock.phase == .finished)
  }

  /// The other half of sleep safety, and the half with no wake notification to
  /// lean on: `NSWorkspace.didWakeNotification` does not fire for every form of
  /// suspension (App Nap, a wedged main thread), so a tick arriving absurdly
  /// late must be read the same way as a wake. Overshoot 6s against a 0.1s tick
  /// interval is not a late tick, it is a process that was not running.
  ///
  /// Pinning test: this heuristic is one careless edit from silently inverting,
  /// and inverted it reports breaks the user slept through as completed.
  @Test func tickArrivingLongAfterTheDeadlineCancelsTheTaskWithoutAWake() throws {
    let time = FakeTime()
    let recorder = EndRecorder()
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3)
      ),
      time: time,
      recorder: recorder
    )

    // Deadline + 6s, comfortably past `suspensionTolerance` (5s). No wake.
    time.advance(26)
    clock.tick()

    #expect(clock.phase == .cancelled)
    #expect(clock.didCompleteTask == false, "an unobserved deadline is not a completion")
    #expect(recorder.ends.count == 1, "the stale window must still come down")
  }

  /// The complementary bound: just inside the tolerance is an ordinary late
  /// tick — a busy main thread, not a suspended process — and must complete the
  /// task normally. Without this, widening the tolerance to infinity (or
  /// deleting the comparison outright) would go unnoticed.
  @Test func tickArrivingJustInsideTheToleranceCompletesTheTaskNormally() throws {
    let time = FakeTime()
    let start = time.now
    let clock = try makeClock(
      Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        autoDismiss: StandardNotification.AutoDismiss(delay: 3)
      ),
      time: time
    )

    // Deadline + 4.9s, just inside `suspensionTolerance` (5s).
    time.advance(24.9)
    clock.tick()

    #expect(clock.phase == .dismissing)
    #expect(clock.didCompleteTask, "a merely-late tick must not void the exercise")
    #expect(
      clock.deadline == start.addingTimeInterval(23),
      "the dismiss phase still arms from the task's own deadline, not from the late tick")
  }

  /// A wake that lands *before* the deadline changes nothing — waking up is
  /// not a reason to cut a running task short.
  @Test func wakeBeforeDeadlineIsANoOp() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")),
      time: time
    )

    time.advance(5)
    clock.handleWake()
    #expect(clock.phase == .task)
    #expect(clock.remaining == 15)
  }

  /// `remaining` is derived from the wall-clock deadline, not counted down by
  /// ticks, so it stays correct no matter how many ticks were missed.
  @Test func remainingIsDerivedFromWallClockDeadline() throws {
    let time = FakeTime()
    let clock = try makeClock(
      Countdown(task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")),
      time: time
    )

    #expect(clock.remaining == 20)
    time.advance(12.5)
    #expect(clock.remaining == 7.5, "no tick was delivered, yet remaining is still right")
    time.advance(100)
    #expect(clock.remaining == 0, "remaining never goes negative")
  }

  // MARK: Construction

  /// Both halves nil means no clock at all — the manager must not install one,
  /// and nothing must be scheduled.
  @Test func countdownWithBothHalvesNilProducesNoClock() {
    let time = FakeTime()
    let clock = NotificationClock(
      id: UUID(), countdown: Countdown(), currentDate: time.source, onEnd: nil)
    #expect(clock == nil)
  }
}

// MARK: - The manager owns the clock

@MainActor
struct OverlayClockOwnershipTests {

  /// The whole point of moving the clock out of the view body: `dismiss` —
  /// which every dismissal path (button, ESC, click-away, `dismissAll`)
  /// already funnels through — stops it. And it must do so *above* the
  /// `activeWindows` guard, so a half-torn-down id still gets its clock killed
  /// instead of leaving a timer running against a window that no longer exists.
  @Test func dismissCancelsTheClockEvenWhenTheMainWindowIsAlreadyGone() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(animatePresentation: false),
      countdown: Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"))
    ) {
      EmptyView()
    }

    let clock = try #require(manager.clocks[id], "show(countdown:) must install a clock")
    #expect(clock.phase == .task)

    let window = manager.activeWindows[id]
    // Simulate the main window already being gone by the time dismiss runs.
    manager.activeWindows.removeValue(forKey: id)

    manager.dismiss(id: id, animated: false)

    #expect(manager.clocks[id] == nil, "the clock entry must be released")
    #expect(clock.phase == .cancelled, "the clock itself must be stopped, not just forgotten")

    window?.close()
  }

  /// `show` must actually *start* the clock it installs, not merely construct
  /// it. `start()` is split out of `init` so tests can step time by hand, and
  /// that seam puts the one line which makes any of this run in production —
  /// `clock?.start()` — outside every clock-level test: delete it and a suite
  /// that never calls `start()` stays entirely green while no countdown in the
  /// shipping app ever ticks. This test is the tripwire for that line.
  /// (Verified by deleting it: this test, and only this test, fails.)
  @Test func showStartsTheClockItInstalls() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(animatePresentation: false),
      countdown: Countdown(
        task: TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Break complete"))
    ) {
      EmptyView()
    }

    let clock = try #require(manager.clocks[id])
    #expect(clock.isRunning, "show() must start the clock, not just build it")

    manager.dismiss(id: id, animated: false)
    #expect(clock.isRunning == false, "dismiss must stop the ticking, not just drop the reference")
  }

  /// No countdown, no clock — `show`'s existing shape must stay exactly as
  /// cheap as it was.
  @Test func showWithoutCountdownInstallsNoClock() {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(id: id, configuration: .init(animatePresentation: false)) { EmptyView() }
    #expect(manager.clocks[id] == nil)

    manager.dismiss(id: id, animated: false)
  }

  /// Recycled ids are a real pattern here (the consuming client tracks one
  /// active overlay id and reshows). A timer callback from the *previous*
  /// clock must not take down the window that has since claimed the id — the
  /// same class of bug the `animateDismiss` identity check fixed, guarded the
  /// same way, with a monotonic generation token instead of object identity.
  @Test func staleClockGenerationDoesNotDismissARecycledID() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(animatePresentation: false),
      countdown: Countdown(autoDismiss: StandardNotification.AutoDismiss(delay: 5))
    ) {
      EmptyView()
    }
    let staleClock = try #require(manager.clocks[id])
    let staleWindow = try #require(manager.activeWindows[id])
    let staleGeneration = staleClock.generation

    // The id is recycled for a fresh alert.
    _ = manager.show(
      id: id,
      configuration: .init(animatePresentation: false),
      countdown: Countdown(autoDismiss: StandardNotification.AutoDismiss(delay: 5))
    ) {
      EmptyView()
    }
    let freshClock = try #require(manager.clocks[id])
    let freshWindow = try #require(manager.activeWindows[id])

    #expect(freshClock !== staleClock)
    #expect(
      freshClock.generation > staleGeneration, "generations must increase monotonically")
    #expect(
      staleClock.phase == .cancelled,
      "installing a new clock over a recycled id must stop the old one")

    // The stale clock's callback fires late, carrying its own generation.
    manager.clockDidEnd(id: id, generation: staleGeneration)

    #expect(
      manager.activeWindows[id] === freshWindow,
      "a stale generation must not dismiss the window that now owns the id")
    #expect(manager.clocks[id] === freshClock)
    #expect(freshWindow.isVisible)

    // ...and the fresh generation still works. Asserted on the clock entry
    // rather than `activeWindows`, because the window's removal is deferred to
    // the 0.25s fade completion and waiting on that would put a wall-clock
    // sleep in a test that otherwise has none. The clock entry is cleared
    // synchronously at the top of `dismiss`, which is precisely the thing under
    // test here.
    manager.clockDidEnd(id: id, generation: freshClock.generation)
    #expect(manager.clocks[id] == nil, "the live generation must reach dismiss()")
    #expect(freshClock.phase == .cancelled)

    staleWindow.close()
    freshWindow.close()
  }

  // `dismissAll` also reaps clock-only ids (it iterates the union of
  // `activeWindows` and `clocks`, so a clock whose window entry was already
  // dropped cannot outlive it). Deliberately *not* covered by a test here:
  // `OverlayWindowManager` is a process-wide singleton, so a test calling
  // `dismissAll` tears down the windows of every other test running
  // concurrently — it reproducibly broke
  // `staleAnimatedDismissCompletionDoesNotEvictReusedID`, which yields the main
  // actor during its 0.6s sleep. The per-id half of that behavior is covered
  // above by `dismissCancelsTheClockEvenWhenTheMainWindowIsAlreadyGone`, and
  // `dismissAll` is a loop over `dismiss(id:)`.
}
