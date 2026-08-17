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
