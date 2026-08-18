import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

/// Task 9: the builder's routing decision between the rich renderer and the
/// two 0.0.5 renderers, plus the five carried-forward requirements from
/// earlier reviews that ride along with it (Reduce Transparency's blur
/// window, the double-timer trap, the `.ambient` + task timer trap, the
/// missing public entry point, and the missing "an overlay closed itself"
/// signal).
///
/// Following `LegibilityTests`'s split: the routing *decision* is a pure
/// function of the builder's state (`NotificationBuilder.routesToRichRenderer`,
/// `.richNotification()`), asserted here without a window. Whether `.show()`
/// actually *acts* on that decision is asserted separately, against a real
/// `OverlayWindowManager` window's hosted content type.
@MainActor
struct RoutingTests {

  // MARK: - Helpers

  /// `OverlayWindowManager.show` always wraps its content in
  /// `.environment(\.notificationClock, clock)` — even when there is no
  /// clock — so the window's hosted view is never bare `NSHostingView<X>`,
  /// it is `NSHostingView<ModifiedContent<X, _EnvironmentKeyWritingModifier<...>>>`.
  /// Matching by the mangled type name, rather than an `is` cast against an
  /// exact generic, is what makes this robust to that wrapper regardless of
  /// which renderer `X` actually is.
  ///
  /// Takes the unwrapped `contentView` directly, not `window.contentView`
  /// re-wrapped through an `Any` — `type(of:)` on a value that has crossed
  /// an `Optional<NSView>`-typed boundary reports the static `Optional<NSView>`
  /// metatype instead of the hosting view's dynamic class, which silently
  /// turned this into a check that could never pass.
  private func hostedViewTypeName(_ contentView: NSView?) -> String {
    guard let contentView else { return "<nil>" }
    return String(describing: type(of: contentView))
  }

  // MARK: - The routing decision (pure)

  /// **The bug this task fixes.** Before this change, `.show()` forked on
  /// `useSVG` before buttons ever entered the picture, so `showSVG`'s
  /// parameter list — which has no `buttons:` — silently ate the button.
  /// `.svg(...).button(...)` must now route to the rich renderer, where
  /// `RichNotification.buttons` actually exists, and the button must survive
  /// into the notification that gets built.
  @Test func illustrationWithAButtonRoutesRichAndKeepsTheButton() {
    let builder = VibeNotify.builder()
      .svg("/tmp/eye.svg")
      .button(.init(title: "Done", style: .primary, action: {}))

    #expect(builder.routesToRichRenderer, "an illustration plus a button must route rich")
    #expect(builder.richNotification().buttons.count == 1)
    #expect(builder.richNotification().buttons.first?.title == "Done")
  }

  /// Rule 3 is why rule 1 exists: a bare `.svg(...)` with no buttons and no
  /// rich-only field must render exactly as it did in 0.0.5. This is the
  /// case that makes rule 2 alone unsafe — the client's schedule path sets
  /// `.svg(...)` and never calls `.button(...)`.
  @Test func illustrationAloneWithNoButtonsStaysOnTheOldRenderer() {
    let builder = VibeNotify.builder().svg("/tmp/eye.svg")
    #expect(!builder.routesToRichRenderer)
  }

  /// `.mode(...)` is a rich-only field on its own, regardless of buttons —
  /// this is the opt-in the client uses to keep its schedule path on the old
  /// renderer's pixels until it deliberately asks for the new one.
  @Test func modeAloneRoutesRichEvenWithNoButtons() {
    let builder = VibeNotify.builder().title("Break").mode(.interrupt)
    #expect(builder.routesToRichRenderer)
  }

  /// `.footnote(...)` and `.taskTimer(...)` are the other two rich-only
  /// fields `SVGNotification`/`StandardNotification` cannot express at all.
  @Test func footnoteAloneRoutesRich() {
    #expect(VibeNotify.builder().title("Saved").footnote("ESC to skip").routesToRichRenderer)
  }

  @Test func taskTimerAloneRoutesRich() {
    let timer = TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")
    #expect(VibeNotify.builder().title("Break").taskTimer(timer).routesToRichRenderer)
  }

  /// An `.image`/`.symbol` illustration is a rich-only *kind* — the old SVG
  /// renderer cannot draw either — so it routes rich even with no button.
  /// A plain `.svg` illustration is not: that is rule 3's whole point.
  @Test func imageOrSymbolIllustrationAloneRoutesRich() {
    #expect(
      VibeNotify.builder().illustration(.symbol("eye.fill", pointSize: 40, color: nil))
        .routesToRichRenderer)
    #expect(
      VibeNotify.builder().illustration(.image(NSImage(), size: CGSize(width: 10, height: 10)))
        .routesToRichRenderer)
  }

  /// The new `.illustration(.svg(...))` spelling is equivalent to the legacy
  /// `.svg(path)` for routing purposes: alone it is rule 3, paired with a
  /// button it is rule 2.
  @Test func illustrationSVGCaseFollowsTheSameRulesAsLegacySVG() {
    let alone = VibeNotify.builder().illustration(.svg(.filePath("/tmp/eye.svg"), size: .init(width: 40, height: 40)))
    #expect(!alone.routesToRichRenderer)

    let withButton = VibeNotify.builder()
      .illustration(.svg(.filePath("/tmp/eye.svg"), size: .init(width: 40, height: 40)))
      .button(.init(title: "Done", action: {}))
    #expect(withButton.routesToRichRenderer)
  }

  /// Plain title/message/icon/buttons with nothing rich-only set is the
  /// ordinary standard-notification shape and must stay on 0.0.5 behaviour.
  @Test func plainStandardNotificationStaysOnTheOldRenderer() {
    let builder = VibeNotify.builder().title("Hi").message("There")
      .button(.init(title: "OK", action: {}))
    #expect(!builder.routesToRichRenderer)
  }

  // MARK: - (c) The `.ambient` + task timer trap

  /// A caller who sets `.taskTimer(...)` and never calls `.mode(...)` is
  /// upgraded to `.interrupt` rather than silently landing on `.ambient`,
  /// where `RichNotification.effectiveTaskTimer` would return `nil` and the
  /// alert would show neither a ring nor a clock.
  @Test func taskTimerWithNoExplicitModeUpgradesToInterrupt() {
    let timer = TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")
    let notification = VibeNotify.builder().title("Break").taskTimer(timer).richNotification()

    #expect(notification.mode == .interrupt)
    // And the upgrade actually reaches the model's own enforcement: the ring
    // is real, not merely a mode label.
    #expect(notification.effectiveTaskTimer != nil)
  }

  /// The escape hatch: a caller who explicitly asks for `.ambient` alongside
  /// a task timer keeps it — this reinterprets an *unset* mode, not an
  /// explicit one.
  @Test func explicitAmbientWithATaskTimerIsNotUpgraded() {
    let timer = TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")
    let notification = VibeNotify.builder().title("Break").mode(.ambient).taskTimer(timer)
      .richNotification()

    #expect(notification.mode == .ambient)
    // `RichNotification` itself still applies its own deliberate rule here —
    // this builder-level test is only about which mode reaches the model.
    #expect(notification.effectiveTaskTimer == nil)
  }

  /// Explicit `.interrupt` plus a task timer is untouched either way.
  @Test func explicitInterruptWithATaskTimerIsUnaffected() {
    let timer = TaskTimer(duration: 20, unitLabel: "seconds", completionLabel: "Done")
    let notification = VibeNotify.builder().title("Break").mode(.interrupt).taskTimer(timer)
      .richNotification()
    #expect(notification.mode == .interrupt)
  }

  // MARK: - End to end: `.show()` actually routes where the decision says

  /// The regression test for the bug itself, at the level a real caller would
  /// hit it: the window `.show()` actually creates hosts `RichNotificationView`,
  /// not `SVGNotificationView` — so the button is not just present on a model
  /// nobody renders, it reaches the view that draws it.
  @Test func showRoutesIllustrationPlusButtonToTheRichRenderer() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.builder()
      .svg("/tmp/eye.svg")
      .button(.init(title: "Done", action: {}))
      .show()
    defer { manager.dismiss(id: id, animated: false) }

    let window = try #require(manager.activeWindows[id])
    #expect(hostedViewTypeName(window.contentView).contains("RichNotificationView"))
  }

  /// The control: a bare `.svg(...)` with no button still hosts the
  /// deprecated `SVGNotificationView`, unchanged from 0.0.5.
  @Test func showRoutesBareIllustrationToTheOldRenderer() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.builder()
      .svg("/tmp/eye.svg")
      .show()
    defer { manager.dismiss(id: id, animated: false) }

    let window = try #require(manager.activeWindows[id])
    #expect(hostedViewTypeName(window.contentView).contains("SVGNotificationView"))
  }

  // MARK: - (b) Exactly one timer per notification

  /// Routed rich, `autoDismiss` becomes part of the `RichNotification` the
  /// manager derives a single `Countdown`/`NotificationClock` from — never
  /// handed to the old renderer's own bare, uncancellable `asyncAfter`.
  /// Asserted as "the manager owns a clock for this id", which is only true
  /// on the rich path — the old renderer's timer is private `@State` inside
  /// its own view body and installs nothing in the manager at all.
  @Test func richRoutedAutoDismissIsOwnedByExactlyOneClock() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.builder()
      .svg("/tmp/eye.svg")
      .button(.init(title: "Done", action: {}))
      .autoDismiss(after: 30)
      .show()
    defer { manager.dismiss(id: id, animated: false) }

    #expect(manager.clocks[id] != nil, "the rich path must own a single clock")
  }

  /// The same `autoDismiss` on the old-renderer path installs no clock at
  /// all in the manager — confirming the two paths never both arm a timer
  /// for the same notification.
  @Test func oldRoutedAutoDismissInstallsNoManagerClock() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.builder()
      .svg("/tmp/eye.svg")
      .autoDismiss(after: 30)
      .show()
    defer { manager.dismiss(id: id, animated: false) }

    #expect(manager.clocks[id] == nil, "the old renderer must never gain a manager-owned clock")
  }

  // MARK: - (a) Reduce Transparency suppresses the blur window entirely

  /// The derived configuration, not just `Legibility.Backdrop`: `screenBlur`
  /// must actually be forced off, with every other field carried through
  /// unchanged.
  @Test func suppressingBlurTurnsOffScreenBlurAndPreservesEverythingElse() {
    let original = OverlayWindowManager.Configuration.interrupt(dismissOnScreenTap: true)
    let suppressed = VibeNotify.suppressingBlur(original)

    #expect(original.screenBlur == true, "precondition: .interrupt normally requests a blur window")
    #expect(suppressed.screenBlur == false)
    #expect(suppressed.dismissOnScreenTap == original.dismissOnScreenTap)
    #expect(suppressed.screenDim == original.screenDim)
    #expect(suppressed.presentationMode is OverlayWindowManager.PresentationMode)
    #expect(suppressed.alwaysOnTop == original.alwaysOnTop)
    #expect(suppressed.takesKeyFocus == original.takesKeyFocus)
    #expect(suppressed.animatePresentation == original.animatePresentation)
  }

  /// End to end: under Reduce Transparency, `showRich` for `.interrupt` never
  /// builds the blur window at all — not merely a suppressed-looking one.
  /// `RichNotificationView` already draws the opaque replacement, so a blur
  /// window built anyway would be a live, invisible no-op.
  @Test func showRichUnderReduceTransparencyBuildsNoBlurWindow() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.shared.showRich(
      RichNotification(title: "Break", mode: .interrupt),
      configuration: .interrupt(animatePresentation: false),
      reduceTransparency: true
    )
    defer { manager.dismiss(id: id, animated: false) }

    #expect(manager.blurWindows[id] == nil, "Reduce Transparency must suppress the blur window entirely")
    #expect(manager.activeWindows[id] != nil, "the content window must still exist")
  }

  /// Without Reduce Transparency, the blur window is built as usual.
  @Test func showRichWithoutReduceTransparencyStillBuildsTheBlurWindow() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.shared.showRich(
      RichNotification(title: "Break", mode: .interrupt),
      configuration: .interrupt(animatePresentation: false),
      reduceTransparency: false
    )
    defer { manager.dismiss(id: id, animated: false) }

    #expect(manager.blurWindows[id] != nil)
  }

  // MARK: - (d) The public entry point

  /// `showRich` is a real, usable public entry point: it returns an id the
  /// caller can dismiss, and the window it creates hosts `RichNotificationView`
  /// — a consumer never has to reach into `OverlayWindowManager` the way this
  /// library's own demo harness used to have to.
  @Test func showRichIsAUsablePublicEntryPoint() throws {
    let manager = OverlayWindowManager.shared
    let id = VibeNotify.shared.showRich(
      RichNotification(title: "Saved", message: "Just now", mode: .ambient),
      configuration: .ambient(
        position: .bottomRight, width: 300, height: 150, animatePresentation: false)
    )
    let window = try #require(manager.activeWindows[id])
    #expect(hostedViewTypeName(window.contentView).contains("RichNotificationView"))

    VibeNotify.shared.dismiss(id: id, animated: false)
    #expect(manager.activeWindows[id] == nil)
  }

  // MARK: - (e) A public signal for "an overlay closed itself"

  /// A clock reaching its own deadline tears the window down through
  /// `OverlayWindowManager.clockDidEnd`, which never calls the `onDismiss`
  /// closure baked into `RichNotificationView` — exactly the gap that broke
  /// the demo harness's active-alert counter. `showRich`'s `onEnd` must fire
  /// anyway, reporting `.finished`.
  @Test func onEndFiresWithFinishedWhenTheClockRunsOut() async throws {
    let manager = OverlayWindowManager.shared
    var reported: NotificationClock.Phase??
    let id = VibeNotify.shared.showRich(
      RichNotification(
        title: "Saved",
        autoDismiss: .init(delay: 0.1, indicator: .none),
        mode: .ambient),
      configuration: .ambient(
        position: .bottomRight, width: 300, height: 150, animatePresentation: false),
      onEnd: { phase in reported = .some(phase) }
    )

    // Poll for the outcome instead of sleeping a fixed span and hoping.
    //
    // The work is a 0.1s deadline, up to 0.1s to the next tick, and the
    // manager's own 0.25s dismiss fade — roughly 0.45s. A fixed 1.2s sleep
    // looks like comfortable margin over that and is not: swift-testing runs
    // suites in parallel and every one of them shares the process-wide
    // `OverlayWindowManager.shared`, so this test's main-actor continuations
    // queue behind theirs. Under that contention no fixed margin is safe,
    // which is why this flaked about three runs in six locally before blocking
    // CI outright.
    //
    // Polling is not just a longer sleep: it returns the instant the teardown
    // lands, so the common case is faster than the margin it replaces, and the
    // full budget is only spent when something is genuinely wrong.
    let budget = ContinuousClock.now.advanced(by: .seconds(10))
    while ContinuousClock.now < budget {
      if reported != nil, manager.activeWindows[id] == nil { break }
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(reported == .some(.finished))
    #expect(manager.activeWindows[id] == nil, "the window must actually have come down")
  }

  /// A user-driven dismissal (here simulated the way ESC/a button ultimately
  /// resolve: `VibeNotify.dismiss(id:)`) reports `.cancelled` — the clock was
  /// still running when it was cut short.
  @Test func onEndFiresWithCancelledWhenDismissedEarly() {
    var reported: NotificationClock.Phase??
    let id = VibeNotify.shared.showRich(
      RichNotification(
        title: "Break",
        taskTimer: TaskTimer(duration: 30, unitLabel: "seconds", completionLabel: "Done"),
        mode: .interrupt),
      configuration: .interrupt(animatePresentation: false),
      onEnd: { phase in reported = .some(phase) }
    )

    VibeNotify.shared.dismiss(id: id, animated: false)

    #expect(reported == .some(.cancelled))
  }

  /// An alert with no countdown at all still reports that it ended — just
  /// with no phase to report, since there was never a clock.
  @Test func onEndFiresWithNoPhaseWhenThereWasNoClock() {
    var reported: NotificationClock.Phase??
    let id = VibeNotify.shared.showRich(
      RichNotification(title: "Saved", mode: .ambient),
      configuration: .ambient(
        position: .bottomRight, width: 300, height: 150, animatePresentation: false),
      onEnd: { phase in reported = .some(phase) }
    )

    VibeNotify.shared.dismiss(id: id, animated: false)

    #expect(reported == .some(nil))
  }
}
