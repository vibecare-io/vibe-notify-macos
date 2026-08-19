import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

/// The decisions behind the rich renderer, extracted from the view bodies so
/// they can be asserted without a screen.
///
/// Everything here is a pure function of its inputs. What is *not* here —
/// whether the feathered scrim's edge is genuinely invisible, whether the arc's
/// timing feels right — cannot be asserted without an eye, and a test that
/// builds a `RichNotificationView` and checks it is non-nil would assert
/// nothing at all. The rule this file follows: if a rendering decision matters,
/// it is a function; if it is a function, it is tested here.
@MainActor
struct LegibilityTests {

  // MARK: - Helpers

  /// Relative luminance of a resolved colour, ignoring alpha. Used to assert
  /// "the shadow opposes the text" without pinning exact `Color` literals —
  /// the rule is directional, and a future restyle that keeps the direction
  /// should not have to edit this file.
  private func luminance(_ color: Color) -> Double {
    guard let resolved = NSColor(color).usingColorSpace(.sRGB) else {
      Issue.record("colour \(color) has no sRGB representation")
      return .nan
    }
    return 0.2126 * Double(resolved.redComponent)
      + 0.7152 * Double(resolved.greenComponent)
      + 0.0722 * Double(resolved.blueComponent)
  }

  private func alpha(_ color: Color) -> Double {
    Double(NSColor(color).usingColorSpace(.sRGB)?.alphaComponent ?? 0)
  }

  private func timer(_ duration: TimeInterval = 20) -> TaskTimer {
    TaskTimer(duration: duration, unitLabel: "seconds", completionLabel: "Break complete")
  }

  // MARK: - The scrim selector

  /// The selector is the *effective backdrop dim*, not a boolean over
  /// `screenBlur`: a `.light` blur at the pinned 0.1 is "blur is on" and is
  /// still not a safe backdrop. At or above the safe dim something else has
  /// already made the whole surface legible, and a local scrim on top of a
  /// uniform field is a visible rectangle — a card arrived at by accident.
  @Test func aBackdropAtOrAboveTheSafeDimNeedsNoLocalScrim() {
    #expect(Legibility.scrimStrategy(effectiveDim: 0.55, reduceTransparency: false) == .none)
    #expect(Legibility.scrimStrategy(effectiveDim: 0.7, reduceTransparency: false) == .none)
    #expect(Legibility.scrimStrategy(effectiveDim: 1.0, reduceTransparency: false) == .none)
  }

  /// Below the safe dim — *including zero*, which is what `.ambient` always
  /// is — the renderer owns the backdrop under its own text and must draw it.
  /// Zero is called out explicitly because "no blur" is the case a boolean
  /// selector got wrong.
  @Test func aBackdropBelowTheSafeDimDrawsTheFeatheredScrim() {
    #expect(Legibility.scrimStrategy(effectiveDim: 0.0, reduceTransparency: false) == .feathered)
    #expect(Legibility.scrimStrategy(effectiveDim: 0.1, reduceTransparency: false) == .feathered)
    #expect(Legibility.scrimStrategy(effectiveDim: 0.54, reduceTransparency: false) == .feathered)
  }

  /// Reduce Transparency: a feathered scrim *is* a transparency gradient and
  /// cannot be made opaque and stay edgeless. The decision taken was "give
  /// them a solid backdrop with a defined edge" over suppressing ambient
  /// alerts entirely.
  @Test func reduceTransparencyTradesTheFeatherForASolidBackdrop() {
    #expect(Legibility.scrimStrategy(effectiveDim: 0.0, reduceTransparency: true) == .solid)
    #expect(Legibility.scrimStrategy(effectiveDim: 0.1, reduceTransparency: true) == .solid)
  }

  /// Reduce Transparency does not *add* a backdrop where a global one already
  /// exists — that would be the accidental card again, this time opaque.
  @Test func reduceTransparencyAddsNothingWhereAGlobalScrimAlreadyExists() {
    #expect(Legibility.scrimStrategy(effectiveDim: 0.55, reduceTransparency: true) == .none)
  }

  /// The feather must complete *inside* the rect it is drawn in. If alpha
  /// reaches zero exactly at the boundary, the boundary is where the gradient
  /// stops — which is an edge, which is a card. `EllipticalGradient`'s
  /// `endRadiusFraction` of 0.5 is precisely "touches the edge midpoints", so
  /// anything at or above 0.5 fails this.
  @Test func theFeatheredScrimReachesZeroStrictlyInsideItsRect() {
    #expect(FeatheredScrim.endRadiusFraction < 0.5)
    #expect(FeatheredScrim.peakOpacity == Legibility.safeDim)
  }

  // MARK: - The interrupt backdrop

  /// `.interrupt` under Reduce Transparency drops the blur entirely: the
  /// desktop was already unreadable behind a 0.55 dim and a 50-point blur, so
  /// honouring the setting costs nothing and buys a genuinely opaque backdrop.
  @Test func interruptUnderReduceTransparencyIsOpaqueBlackAtRadiusZero() {
    let backdrop = Legibility.backdrop(for: .interrupt, reduceTransparency: true)
    #expect(backdrop == .opaque)
    #expect(backdrop?.blurRadius == 0)
    #expect(backdrop?.isOpaque == true)
    // Total coverage, so no local scrim is drawn on top of it either.
    #expect(
      Legibility.scrimStrategy(
        effectiveDim: backdrop?.effectiveDim ?? 0, reduceTransparency: true) == .none)
  }

  /// Without it, the blur stays and the dim is the derived constant.
  @Test func interruptWithoutReduceTransparencyIsBlurredAtTheSafeDim() {
    let backdrop = Legibility.backdrop(for: .interrupt, reduceTransparency: false)
    #expect(
      backdrop == .blurred(dim: Legibility.safeDim, blurRadius: ScreenBlurIntensity.heavy.radius))
    #expect(backdrop?.isOpaque == false)
    #expect(backdrop?.effectiveDim == Legibility.safeDim)
  }

  /// `.ambient` builds no blur window at all, so it has no backdrop to
  /// describe — the desktop keeps its light and every other window stays
  /// clickable. Dimming the whole desktop for a toast is a category error, and
  /// Reduce Transparency does not change that: what it changes is the *local*
  /// backdrop, asserted above.
  @Test func ambientHasNoGlobalBackdropEitherWay() {
    #expect(Legibility.backdrop(for: .ambient, reduceTransparency: false) == nil)
    #expect(Legibility.backdrop(for: .ambient, reduceTransparency: true) == nil)
  }

  /// 0.55 is one derived number used in three places. This pins that the
  /// `.interrupt` factory reads it rather than carrying its own literal, so a
  /// future adjustment to the contrast derivation cannot leave two of the
  /// three sites behind.
  @Test func theSafeDimIsOneConstantNotThreeLiterals() {
    #expect(OverlayWindowManager.Configuration.interrupt().screenDim == Legibility.safeDim)
    #expect(FeatheredScrim.peakOpacity == Legibility.safeDim)
    // The threshold: the smallest dim at which no local scrim is needed is the
    // same number as the dim `.interrupt` supplies.
    #expect(Legibility.scrimStrategy(effectiveDim: Legibility.safeDim, reduceTransparency: false) == .none)
    #expect(
      Legibility.scrimStrategy(effectiveDim: Legibility.safeDim.nextDown, reduceTransparency: false)
        == .feathered)
  }

  // MARK: - Text colour and shadow

  /// The regression guard for `SVGNotificationView.swift:17-20`
  /// (`useLightText = colorScheme == .dark`). Both scrims are dark, so both
  /// modes render light text in *both* system themes. The system theme answers
  /// a question about the OS, not about the pixels behind the alert.
  @Test func textIsLightInBothColorSchemes() {
    for scheme in [ColorScheme.light, .dark] {
      let styles = Legibility.textStyles(colorScheme: scheme)
      #expect(luminance(styles.title.color) > 0.9, "title must be light under \(scheme)")
      #expect(luminance(styles.message.color) > 0.9)
      #expect(luminance(styles.footnote.color) > 0.9)
    }
  }

  /// The colour scheme must not reach the palette at all — asserted as
  /// equality of the whole style triple, so adding a scheme-dependent branch
  /// anywhere in it fails here.
  @Test func theColorSchemeDoesNotReachThePalette() {
    let light = Legibility.textStyles(colorScheme: .light)
    let dark = Legibility.textStyles(colorScheme: .dark)
    #expect(light.title == dark.title)
    #expect(light.message == dark.message)
    #expect(light.footnote == dark.footnote)
  }

  /// Kills both halves of the old bug at once: the `.clear` shadow under dark
  /// text in light mode (`SVGNotificationView.swift:47`) and the *white* glow
  /// under white text in dark mode (`:47`, `:56`). A shadow opposes its text
  /// or it is not doing anything.
  @Test func everyShadowOpposesItsTextAndIsNeverClear() {
    let styles = Legibility.textStyles(colorScheme: .dark)
    for style in [styles.title, styles.message, styles.footnote] {
      #expect(alpha(style.shadowColor) > 0, "a .clear shadow is not a shadow")
      #expect(
        luminance(style.shadowColor) < luminance(style.color),
        "the shadow must be the opposite pole from the text, never its own colour")
      #expect(style.shadowRadius > 0)
      #expect(
        style.shadowOffsetY > 0,
        "a displaced shadow reads as separation; a centred one reads as glow")
    }
  }

  // MARK: - Dismiss indicator suppression

  /// There is exactly one number on screen at a time, and it is the one the
  /// user is meant to obey. A task timer suppresses the dismiss indicator
  /// outright while it runs, even though the caller configured one.
  @Test func aTaskTimerSuppressesTheDismissIndicator() {
    let notification = RichNotification(
      title: "Look away",
      taskTimer: timer(),
      autoDismiss: .init(delay: 5, indicator: .bar),
      mode: .interrupt
    )
    #expect(notification.dismissIndicator(in: .task) == DismissIndicator.none)
  }

  /// Once the task hands over, the configured indicator is exactly what draws —
  /// the suppression is scoped to the task phase, not permanent.
  @Test func theDismissPhaseDrawsTheConfiguredIndicator() {
    let notification = RichNotification(
      title: "Look away",
      taskTimer: timer(),
      autoDismiss: .init(delay: 5, indicator: .bar),
      mode: .interrupt
    )
    #expect(notification.dismissIndicator(in: .dismissing) == .bar)
    #expect(notification.dismissIndicator(in: .finished) == DismissIndicator.none)
    #expect(notification.dismissIndicator(in: .cancelled) == DismissIndicator.none)
  }

  /// With no task timer there is nothing to suppress and the toast shows its
  /// quiet "this closes in N" from the start.
  @Test func withoutATaskTimerTheIndicatorDrawsImmediately() {
    let notification = RichNotification(
      message: "Saved",
      autoDismiss: .init(delay: 5, indicator: .hairlineRing),
      mode: .ambient
    )
    #expect(notification.dismissIndicator(in: .dismissing) == .hairlineRing)
  }

  // MARK: - Completion honesty

  /// Reaching zero is the only thing that may claim the caller's
  /// `completionLabel`.
  @Test func reachingZeroShowsTheCompletionLabel() {
    let notification = RichNotification(taskTimer: timer(), mode: .interrupt)
    let state = notification.completionState(
      phase: .dismissing, didCompleteTask: true, completedEarly: false)
    #expect(state == .completed(label: "Break complete"))
  }

  /// Pressing Done at second three must not say "Break complete" — a surface
  /// claiming a completed break when seventeen seconds were skipped is lying
  /// to the user about their own health. It acknowledges instead.
  @Test func doneEarlyAcknowledgesRatherThanClaimingCompletion() {
    let notification = RichNotification(taskTimer: timer(), mode: .interrupt)
    let early = notification.completionState(
      phase: .dismissing, didCompleteTask: true, completedEarly: true)
    let full = notification.completionState(
      phase: .dismissing, didCompleteTask: true, completedEarly: false)

    #expect(early == .acknowledged(label: notification.acknowledgementLabel))
    #expect(early != full)
    #expect(early.label != full.label)
    #expect(early.label != notification.taskTimer?.completionLabel)
  }

  /// Skip, Snooze, ESC and click-away produce no completion state and no
  /// acknowledgement — the clock reports `didCompleteTask == false` for all of
  /// them, including a task whose deadline elapsed while the machine slept.
  @Test func cancellationProducesNeitherCompletionNorAcknowledgement() {
    let notification = RichNotification(taskTimer: timer(), mode: .interrupt)
    #expect(
      notification.completionState(phase: .cancelled, didCompleteTask: false, completedEarly: false)
        == .none)
    #expect(
      notification.completionState(phase: .cancelled, didCompleteTask: false, completedEarly: true)
        == .none)
  }

  /// The task phase itself has no completion state: nothing has happened yet.
  @Test func theTaskPhaseShowsNoCompletionState() {
    let notification = RichNotification(taskTimer: timer(), mode: .interrupt)
    #expect(
      notification.completionState(phase: .task, didCompleteTask: false, completedEarly: false)
        == .none)
  }

  /// No task timer, no completion claim — an ambient toast that simply expired
  /// did not complete anything.
  @Test func anAlertWithNoTaskTimerNeverClaimsCompletion() {
    let notification = RichNotification(message: "Saved", mode: .ambient)
    #expect(
      notification.completionState(phase: .finished, didCompleteTask: true, completedEarly: false)
        == .none)
  }

  // MARK: - Button outcomes

  /// Done while the task is running hands the dismissal to the clock:
  /// `completeTask()` ends the phase now, and the acknowledgement is held for
  /// the completion beat before the window goes. Dismissing the window in the
  /// same turn would make the acknowledgement unobservable — the state would
  /// exist for exactly zero frames.
  @Test func doneDuringTheTaskHandsDismissalToTheClock() {
    #expect(
      RichNotification.outcome(for: .primary, taskPhaseActive: true, hasClock: true)
        == .completeTaskThenHold)
  }

  /// Every other button cancels and takes the window down immediately. A
  /// Snooze that leaves the alert on screen is not a snooze.
  @Test func snoozeAndSkipCancelAndDismissImmediately() {
    #expect(
      RichNotification.outcome(for: .secondary, taskPhaseActive: true, hasClock: true)
        == .cancelAndDismiss)
    #expect(
      RichNotification.outcome(for: .destructive, taskPhaseActive: true, hasClock: true)
        == .cancelAndDismiss)
    #expect(
      RichNotification.outcome(for: .secondary, taskPhaseActive: false, hasClock: true)
        == .cancelAndDismiss)
  }

  /// With no clock — or with the task phase already over — Done has nothing to
  /// complete and nothing to hold for, so it must dismiss directly or the
  /// window never comes down.
  @Test func donePressedWithNothingToCompleteDismissesDirectly() {
    #expect(
      RichNotification.outcome(for: .primary, taskPhaseActive: false, hasClock: true) == .dismiss)
    #expect(
      RichNotification.outcome(for: .primary, taskPhaseActive: true, hasClock: false) == .dismiss)
    #expect(
      RichNotification.outcome(for: .primary, taskPhaseActive: false, hasClock: false) == .dismiss)
  }

  // MARK: - The model

  /// The countdown the window manager is handed is derived from the model, so
  /// the renderer and the clock cannot disagree about what is being timed.
  @Test func theCountdownIsDerivedFromTheModel() throws {
    let both = RichNotification(
      taskTimer: timer(30), autoDismiss: .init(delay: 4, indicator: .bar), mode: .interrupt)
    let countdown = try #require(both.countdown)
    #expect(countdown.task?.duration == 30)
    #expect(countdown.autoDismiss?.delay == 4)

    // Neither half means no clock at all, matching `NotificationClock.init?`.
    #expect(RichNotification(title: "Hi", mode: .ambient).countdown == nil)
  }

  /// `.ambient` gets the dismiss indicator only — enforced on the model rather
  /// than left as prose, so the clock and the renderer cannot disagree. A large
  /// labelled ring reads as a task, and in ambient mode there is no task.
  @Test func ambientReinterpretsATaskTimerAsNoTaskAtAll() throws {
    let ambient = RichNotification(
      taskTimer: timer(), autoDismiss: .init(delay: 5, indicator: .bar), mode: .ambient)

    #expect(ambient.effectiveTaskTimer == nil)
    // The stored value is left exactly as the caller passed it: this
    // reinterprets, it does not rewrite.
    #expect(ambient.taskTimer != nil)

    // And the clock agrees, which is the point of enforcing it here rather than
    // in the renderer — otherwise a task phase would run with nothing drawn to
    // explain why the toast is still up.
    let countdown = try #require(ambient.countdown)
    #expect(countdown.task == nil)
    #expect(countdown.autoDismiss?.delay == 5)

    #expect(RichNotification(taskTimer: timer(), mode: .interrupt).effectiveTaskTimer != nil)
  }

  /// `completionState` must read `effectiveTaskTimer`, not the stored
  /// `taskTimer`.
  ///
  /// Unreachable through the renderer today — an `.ambient` alert gets no task
  /// phase, so `didCompleteTask` cannot become true for one — which is exactly
  /// why the guard is easy to get wrong and why nothing caught it: every other
  /// `completionState` test uses `.interrupt`, where the two accessors agree.
  /// Reverting the guard to `taskTimer` leaves the rest of the suite green and
  /// lets an ambient toast announce "Break complete" for a break that was never
  /// offered.
  @Test func anAmbientAlertNeverClaimsCompletionForATimerItNeverRan() {
    let ambient = RichNotification(taskTimer: timer(), mode: .ambient)

    #expect(
      ambient.completionState(phase: .dismissing, didCompleteTask: true, completedEarly: false)
        == .none)
    #expect(
      ambient.completionState(phase: .dismissing, didCompleteTask: true, completedEarly: true)
        == .none)
    // The same model in `.interrupt` does claim it — so the assertion above is
    // about the mode, not about `completionState` being inert.
    #expect(
      RichNotification(taskTimer: timer(), mode: .interrupt)
        .completionState(phase: .dismissing, didCompleteTask: true, completedEarly: false)
        == .completed(label: "Break complete"))
  }

  // MARK: - Illustration fitting

  /// An illustration too large for its window is scaled down, preserving aspect
  /// ratio, rather than evicting everything else. Measured consequence of not
  /// doing this: a 600×500 image in a 380×210 ambient window rendered zero
  /// inked pixels.
  @Test func anOversizedIllustrationIsScaledDownPreservingAspect() {
    let natural = CGSize(width: 600, height: 500)
    let fitted = RichNotification.Illustration
      .image(NSImage(size: natural), size: natural)
      .fitted(in: CGSize(width: 380, height: 210))
      .pixelSize

    #expect(fitted.width < natural.width)
    #expect(fitted.height <= 210 * RichNotification.Illustration.maximumHeightFraction)
    #expect(fitted.width <= 380 - RichNotification.Illustration.horizontalInset)
    // Aspect ratio preserved.
    #expect(abs(fitted.width / fitted.height - natural.width / natural.height) < 0.01)
    // And it leaves room for the rest of the alert, which is the entire point.
    #expect(fitted.height < 210 * 0.75)
  }

  /// It never scales **up**. A small illustration in a large window is what the
  /// caller asked for, and enlarging it would silently override a deliberate
  /// choice — so an interrupt on a big screen renders exactly what was passed.
  @Test func anIllustrationThatAlreadyFitsIsLeftAlone() {
    let small = RichNotification.Illustration.symbol("eye", pointSize: 48, color: nil)
    #expect(small.fitted(in: CGSize(width: 1728, height: 1117)).pixelSize.width == 48)

    let plate = CGSize(width: 220, height: 150)
    let svg = RichNotification.Illustration.svg(.filePath("/tmp/eye.svg"), size: plate)
    #expect(svg.fitted(in: CGSize(width: 1728, height: 1117)).pixelSize == plate)
  }

  /// A degenerate proposed size (a view measured before layout) must not
  /// collapse the illustration to nothing.
  @Test func anUnknownAvailableSizeLeavesTheIllustrationUntouched() {
    let plate = CGSize(width: 220, height: 150)
    let svg = RichNotification.Illustration.svg(.filePath("/tmp/eye.svg"), size: plate)
    #expect(svg.fitted(in: .zero).pixelSize == plate)
  }

  /// An ambient alert with *only* a task timer has nothing left to time, so it
  /// gets no clock rather than an inert one.
  @Test func anAmbientAlertWithOnlyATaskTimerGetsNoClock() {
    #expect(RichNotification(taskTimer: timer(), mode: .ambient).countdown == nil)
  }

  // MARK: - The Reduce Motion arc

  /// Under Reduce Motion the arc steps once a second, quantized off the same
  /// whole-second count the numeral shows, so the two can never disagree.
  @Test func theSteppedArcTracksWholeSecondsRemaining() {
    #expect(CountdownRing.steppedArc(phase: .task, secondsRemaining: 20, duration: 20) == 0)
    #expect(CountdownRing.steppedArc(phase: .task, secondsRemaining: 15, duration: 20) == 0.25)
    #expect(CountdownRing.steppedArc(phase: .task, secondsRemaining: 0, duration: 20) == 1)
  }

  /// Reaching zero or an early Done closes the arc; **cancelling does not**.
  ///
  /// A filled arc says the break finished. Skip at second fifteen finished
  /// nothing, and the non-Reduce-Motion path already got this right by leaving
  /// the arc alone — this is the branch that used to return 1 and fill it on
  /// the way out, which is the same lie as an early Done claiming a completed
  /// break.
  @Test func cancellingDoesNotCompleteTheArc() {
    #expect(CountdownRing.steppedArc(phase: .cancelled, secondsRemaining: 15, duration: 20) == 0.25)
    #expect(CountdownRing.steppedArc(phase: .cancelled, secondsRemaining: 15, duration: 20) != 1)
    // The phases that *are* an ending do close it.
    #expect(CountdownRing.steppedArc(phase: .dismissing, secondsRemaining: 15, duration: 20) == 1)
    #expect(CountdownRing.steppedArc(phase: .finished, secondsRemaining: 15, duration: 20) == 1)
  }

  /// The illustration carries its own size per case: an SF Symbol is sized by
  /// a point size, a bitmap or an SVG by a `CGSize`. One shared `CGSize` would
  /// force a caller to encode a font size as a square rectangle.
  @Test func eachIllustrationCaseCarriesItsOwnSize() {
    let svg = RichNotification.Illustration.svg(
      .filePath("/tmp/eye.svg"), size: CGSize(width: 220, height: 150))
    let symbol = RichNotification.Illustration.symbol("eye", pointSize: 64, color: nil)

    #expect(svg.pixelSize == CGSize(width: 220, height: 150))
    #expect(symbol.pixelSize == CGSize(width: 64, height: 64))
  }
}

// MARK: - Renderer consumption

/// The tests above assert that `Legibility` makes the right decisions. These
/// assert that `RichNotificationView` **consumes** them — which is a separate
/// claim, and the one that was missing.
///
/// The gap was demonstrable: with only the pure tests in place, the renderer
/// could be mutated to draw `.primary` text with `.clear` shadows, use the
/// explicitly-forbidden `PrimaryButtonStyle` card chrome, and drop both
/// `.scrimmed(...)` calls — reinstating the entire original bug — and the whole
/// suite still passed. Pure tests cannot see a renderer that ignores them.
///
/// So these render the view into a bitmap and measure the pixels that come out.
/// The assertions are deliberately coarse and differential (this mode versus
/// that mode, this ratio above that ratio) rather than pinned to exact colours
/// or counts, so a restyle that keeps the *properties* does not break them
/// while a regression that loses the properties does.
@MainActor
struct RichRendererPixelTests {

  /// What a rendered surface is made of.
  ///
  /// **All areas are in square *points*, not pixels.** Every count is divided
  /// by the square of the backing scale factor actually used for the render, so
  /// a threshold written here means the same thing on a 2x Retina display, a 1x
  /// external monitor and a headless CI machine. Before this normalisation the
  /// ring assertion passed with a margin of 4267 against a threshold of 2000 on
  /// a 2x machine and would have failed at 1067 on a 1x one — a suite that
  /// breaks on other people's hardware, which is worse than no suite.
  struct Areas {
    /// Backing scale actually used, reported so a failure message can say
    /// whether the harness rendered at the resolution it expected.
    var scale: Double = 1
    var total = 0.0
    /// Alpha > 0.5 — a genuinely solid pixel.
    var opaque = 0.0
    /// Alpha > 0.3 — anything drawn firmly enough to read as content rather
    /// than as the tail of a gradient or a shadow.
    var ink = 0.0
    /// `ink` that is also light (luminance > 0.85).
    ///
    /// The alpha floor is 0.3 rather than 0.9 deliberately: the palette's
    /// message is `white.opacity(0.9)` and its footnote `white.opacity(0.6)`,
    /// so a stricter floor would score correct light text as absent. What is
    /// being distinguished here is *light versus dark*, not opaque versus
    /// translucent.
    var light = 0.0
    /// Light *and* essentially opaque (alpha > 0.9). Distinguishes a solid
    /// light fill from a translucent one — `white.opacity(0.55)` scores as
    /// `light` but not as this.
    var solidLight = 0.0
    /// Dark *and* partially transparent. Given light content over nothing, the
    /// only thing that produces these is a drop shadow.
    var darkHalo = 0.0
    /// Total ink laid down, however faint. A scrim moves this a lot.
    var alphaSum = 0.0

    var lightFraction: Double { ink == 0 ? 0 : light / ink }
    var opaqueFraction: Double { total == 0 ? 0 : opaque / total }
  }

  /// Renders at a fixed size with the system appearance **forced to light**.
  ///
  /// The forced appearance is the point of the whole harness: `.primary`
  /// resolves to black under `.aqua`, so a renderer that went back to
  /// consulting the system theme produces dark text here and the luminance
  /// assertions fail. Under the correct implementation nothing in the renderer
  /// reads the appearance at all and the result is identical either way.
  func render(
    _ notification: RichNotification,
    size: CGSize = CGSize(width: 400, height: 220),
    reduceTransparency: Bool = false,
    reduceMotion: Bool = true,
    clock: NotificationClock? = nil
  ) -> Areas {
    let host = NSHostingView(
      rootView: RichNotificationView(
        notification: notification,
        reduceMotion: reduceMotion,
        reduceTransparency: reduceTransparency,
        onDismiss: {}
      ).environment(\.notificationClock, clock))
    host.appearance = NSAppearance(named: .aqua)
    host.frame = CGRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()

    var areas = Areas()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
      Issue.record("the host view produced no bitmap representation")
      return areas
    }
    host.cacheDisplay(in: host.bounds, to: rep)

    // Measured from the representation rather than assumed: the harness must
    // not care whether it is running on Retina, on a 1x external display, or
    // headless.
    let scale = host.bounds.width > 0 ? Double(rep.pixelsWide) / Double(host.bounds.width) : 1
    let perPixelArea = scale > 0 ? 1 / (scale * scale) : 1
    areas.scale = scale

    accumulate(rep, perPixelArea: perPixelArea, into: &areas)
    return areas
  }

  /// Walks the bitmap once, reading `bitmapData` directly.
  ///
  /// Not a micro-optimisation. The previous version called
  /// `NSBitmapImageRep.colorAt(x:y:)` per pixel and then `usingColorSpace` on
  /// the result — two Objective-C message sends and an `NSColor` allocation for
  /// every pixel, which for the eight 460×520 renders in the accessibility
  /// matrix is about 7.7 million of each. That single test took 8.6s of a 21.4s
  /// suite, which is slow enough that people stop running it.
  ///
  /// Falls back to `colorAt` for any format this does not understand, rather
  /// than silently measuring garbage.
  private func accumulate(
    _ rep: NSBitmapImageRep, perPixelArea: Double, into areas: inout Areas
  ) {
    guard let base = rep.bitmapData,
      rep.bitsPerSample == 8,
      rep.samplesPerPixel == 4,
      !rep.isPlanar
    else {
      for x in 0..<rep.pixelsWide {
        for y in 0..<rep.pixelsHigh {
          guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
          accumulate(
            red: Double(colour.redComponent), green: Double(colour.greenComponent),
            blue: Double(colour.blueComponent), alpha: Double(colour.alphaComponent),
            perPixelArea: perPixelArea, into: &areas)
        }
      }
      return
    }

    let format = rep.bitmapFormat
    let alphaFirst = format.contains(.alphaFirst)
    // Absence of the flag means the samples *are* premultiplied. `colorAt`
    // undoes that for you; reading raw bytes does not, and skipping the
    // division would make every translucent pixel read as darker than it is —
    // which is precisely the distinction `darkHalo` and `solidLight` turn on.
    let premultiplied = !format.contains(.alphaNonpremultiplied)
    let bytesPerRow = rep.bytesPerRow
    let bytesPerPixel = rep.bitsPerPixel / 8

    for y in 0..<rep.pixelsHigh {
      let row = base + y * bytesPerRow
      for x in 0..<rep.pixelsWide {
        let pixel = row + x * bytesPerPixel
        let a: Double
        let r: Double
        let g: Double
        let b: Double
        if alphaFirst {
          a = Double(pixel[0]) / 255
          r = Double(pixel[1]) / 255
          g = Double(pixel[2]) / 255
          b = Double(pixel[3]) / 255
        } else {
          r = Double(pixel[0]) / 255
          g = Double(pixel[1]) / 255
          b = Double(pixel[2]) / 255
          a = Double(pixel[3]) / 255
        }
        let divisor = (premultiplied && a > 0) ? a : 1
        accumulate(
          red: r / divisor, green: g / divisor, blue: b / divisor, alpha: a,
          perPixelArea: perPixelArea, into: &areas)
      }
    }
  }

  private func accumulate(
    red: Double, green: Double, blue: Double, alpha: Double,
    perPixelArea: Double, into areas: inout Areas
  ) {
    let l = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    areas.total += perPixelArea
    areas.alphaSum += alpha * perPixelArea
    if alpha > 0.5 { areas.opaque += perPixelArea }
    if alpha > 0.3 { areas.ink += perPixelArea }
    if alpha > 0.3 && l > 0.85 { areas.light += perPixelArea }
    if alpha > 0.9 && l > 0.85 { areas.solidLight += perPixelArea }
    if alpha > 0.02 && alpha < 0.5 && l < 0.3 { areas.darkHalo += perPixelArea }
  }

  private func clock(_ countdown: Countdown) -> NotificationClock? {
    NotificationClock(id: UUID(), countdown: countdown)
  }

  /// A clock advanced `elapsed` seconds into its first phase, via the injected
  /// date seam rather than by sleeping.
  private func clock(_ countdown: Countdown, elapsed: TimeInterval) -> NotificationClock? {
    let start = Date()
    var now = start
    let clock = NotificationClock(id: UUID(), countdown: countdown, currentDate: { now })
    now = start.addingTimeInterval(elapsed)
    clock?.tick()
    return clock
  }

  private func timer(_ duration: TimeInterval = 20) -> TaskTimer {
    TaskTimer(duration: duration, unitLabel: "seconds", completionLabel: "Break complete")
  }

  // MARK: - Text colour actually reaches the screen

  /// Title, message and footnote all render **light**, with the appearance
  /// forced to light mode.
  ///
  /// `.interrupt` is used because it draws no local scrim, so every opaque
  /// pixel in the frame is text — there is nothing else it could be. Under
  /// `.foregroundColor(.primary)` this is black text under `.aqua` and `white`
  /// collapses to zero.
  @Test func everyTextSlotRendersLight() {
    for notification in [
      RichNotification(title: "Look away now", mode: .interrupt),
      RichNotification(message: "Focus on something twenty feet away", mode: .interrupt),
      RichNotification(footnote: "Press ESC or click anywhere to skip", mode: .interrupt),
    ] {
      let areas = render(notification)
      #expect(areas.ink > 50, "expected visible text, got \(areas.ink)pt² of ink")
      #expect(
        areas.lightFraction > 0.5,
        "text must render light against an unknown desktop; light fraction was \(areas.lightFraction)"
      )
    }
  }

  /// Every text slot casts a **dark** shadow.
  ///
  /// **This metric has a precondition, and the test enforces it rather than
  /// assuming it.** `darkHalo` counts dark semi-transparent pixels, which is a
  /// proxy for "there is a drop shadow" only *given that the text itself is
  /// light*. Black glyphs satisfy the metric all by themselves through their
  /// own antialiased edges — which is not hypothetical: applying the
  /// `.foregroundColor(.primary)` and `color: .clear` mutations together left
  /// this test green, because the black text the first mutation produced
  /// supplied the dark pixels the second one removed. The two masked each
  /// other.
  ///
  /// So the light-text precondition is asserted here, in the test that depends
  /// on it, rather than being borrowed from `everyTextSlotRendersLight`. With
  /// both assertions in one test neither mutation can hide behind the other.
  @Test func everyTextSlotCastsADarkShadow() {
    for notification in [
      RichNotification(title: "Look away now", mode: .interrupt),
      RichNotification(message: "Focus on something twenty feet away", mode: .interrupt),
      RichNotification(footnote: "Press ESC or click anywhere to skip", mode: .interrupt),
    ] {
      let areas = render(notification)

      // The precondition. Without it, `darkHalo` below means nothing.
      #expect(
        areas.lightFraction > 0.5,
        "darkHalo only measures a shadow when the text is light; light fraction was \(areas.lightFraction)"
      )
      #expect(
        areas.darkHalo > 125,
        "a .clear shadow is not a shadow and a light glow is not one either; dark halo was \(areas.darkHalo)pt²"
      )
    }
  }

  // MARK: - The scrim actually reaches the screen

  /// The same content in the two modes must differ by a *lot* of ink, because
  /// `.ambient` draws a feathered scrim and `.interrupt` deliberately draws
  /// none. Deleting `.scrimmed(...)` collapses the two to the same number.
  @Test func ambientDrawsAScrimAndInterruptDoesNot() {
    let content = RichNotification(title: "Look away now", message: "Twenty feet, twenty seconds")
    let ambient = render(
      RichNotification(
        title: content.title, message: content.message, mode: .ambient))
    let interrupt = render(
      RichNotification(
        title: content.title, message: content.message, mode: .interrupt))

    #expect(
      ambient.alphaSum > interrupt.alphaSum * 2,
      """
      .ambient must lay down a feathered scrim under its text and .interrupt must not; \
      ambient=\(Int(ambient.alphaSum)) interrupt=\(Int(interrupt.alphaSum))
      """)
    // And the scrim is a *gradient*, not a block: most of its pixels are
    // partially transparent.
    #expect(ambient.darkHalo > interrupt.darkHalo * 2)
  }

  /// Reduce Transparency replaces the gradient with a genuinely opaque field.
  /// `.solid` that is not solid would be the worst of both.
  @Test func reduceTransparencyRendersASolidAmbientBackdrop() {
    let solid = render(
      RichNotification(title: "Saved", mode: .ambient), reduceTransparency: true)
    let feathered = render(RichNotification(title: "Saved", mode: .ambient))

    #expect(
      solid.opaqueFraction > 0.25,
      "the Reduce Transparency backdrop must be opaque, not a denser gradient")
    #expect(
      solid.opaque > feathered.opaque * 2,
      "solid=\(solid.opaque) feathered=\(feathered.opaque)")
  }

  /// `.interrupt` under Reduce Transparency paints opaque black across the
  /// whole surface — the content window's half of "no blur, radius 0".
  @Test func reduceTransparencyRendersAnOpaqueInterruptBackdrop() {
    let opaqueBackdrop = render(
      RichNotification(title: "Time for a break", mode: .interrupt), reduceTransparency: true)
    #expect(
      opaqueBackdrop.opaqueFraction > 0.9,
      "expected a full-bleed opaque backdrop, got \(opaqueBackdrop.opaqueFraction)")
  }

  // MARK: - Buttons

  /// The forbidden reuse, caught by what it looks like rather than by what it
  /// is called. `RichButtonStyle.primary` is an opaque white capsule, so nearly
  /// every opaque pixel of a buttons-only surface is white.
  /// `PrimaryButtonStyle` fills with `Color.accentColor` and puts a white label
  /// on it, which inverts that ratio.
  @Test func buttonsUseTheChromeLessStyleNotTheCardChrome() {
    let areas = render(
      RichNotification(
        buttons: [.init(title: "Done", style: .primary, action: {})], mode: .interrupt),
      size: CGSize(width: 300, height: 120))

    #expect(areas.opaque > 125, "expected a visible button")
    #expect(
      areas.lightFraction > 0.5,
      """
      the primary button must be an opaque light fill that survives a blurred light desktop, \
      not a flat accent fill; light fraction was \(areas.lightFraction)
      """)
  }

  // MARK: - The countdown children

  /// The regression that a green test used to hide: with a task timer **and**
  /// an auto-dismiss, both children must exist. Choosing between them with an
  /// `if/else` made the dismiss indicator unreachable for exactly the flagship
  /// configuration, while `dismissIndicator(in: .dismissing)` stayed green
  /// against a renderer that could never call it.
  @Test func aTaskTimerAndAnAutoDismissBothDrawTheirOwnChild() {
    let view = RichNotificationView(
      notification: RichNotification(
        taskTimer: timer(),
        autoDismiss: .init(delay: 5, indicator: .bar),
        mode: .interrupt),
      onDismiss: {})

    #expect(view.resolvedTaskTimer != nil, "the ring must be drawn")
    #expect(view.drawsDismissIndicator, "the dismiss indicator must be reachable after handover")
  }

  /// `.ambient` gets the dismiss indicator only. A labelled ring reads as a
  /// task, and in ambient mode there is no task.
  @Test func ambientDrawsNoRingEvenWhenATaskTimerIsSupplied() {
    let view = RichNotificationView(
      notification: RichNotification(
        taskTimer: timer(), autoDismiss: .init(delay: 5, indicator: .bar), mode: .ambient),
      onDismiss: {})

    #expect(view.resolvedTaskTimer == nil)
    #expect(view.drawsDismissIndicator)
  }

  // MARK: - The web layout still draws an alert

  /// The rail survives having a web panel next to it.
  ///
  /// This exists because the exact failure it checks for has already shipped
  /// once, in the other direction: an oversized illustration evicted every
  /// other element past the clip and the surface rendered with *zero* inked
  /// pixels — not a truncated alert, an empty one. The web layout takes a
  /// column away from the same stack, so it can fail the same way, and a
  /// `WKWebView` that draws nothing headless would hide it: the panel's own
  /// backing is dark, so "something rendered" is not evidence the text did.
  ///
  /// Measured against the same content in the stack layout rather than a
  /// pinned number, so a restyle that keeps the property does not break it.
  @Test func theWebRailStillRendersItsTextAndItsButtons() {
    let content = (title: "Rest your eyes", message: "Look twenty feet away.")
    let size = CGSize(width: 1200, height: 760)

    let stacked = render(
      RichNotification(
        title: content.title, message: content.message,
        buttons: [.init(title: "Done", style: .primary, action: {})],
        mode: .interrupt),
      size: size)
    let withPanel = render(
      RichNotification(
        webPanel: WebPanel(url: URL(string: "https://example.com")!),
        title: content.title, message: content.message,
        buttons: [.init(title: "Done", style: .primary, action: {})],
        mode: .interrupt),
      size: size)

    // Light ink is text and button labels. The rail is narrower than the
    // full-width stack, so its text wraps to more lines and lays down *more*
    // of it, never less — but the floor being checked is that it is there at
    // all.
    #expect(
      withPanel.light > stacked.light * 0.5,
      """
      the rail lost its text beside the panel; \
      stacked=\(Int(stacked.light))pt² withPanel=\(Int(withPanel.light))pt²
      """)
    #expect(withPanel.light > 0, "the web layout rendered no light content at all")
  }

  /// Every YouTube shape an author might paste becomes a framed `/embed/`
  /// URL. Handed over unaltered, all three fail differently: a watch URL loads
  /// a page *about* a video, and an embed URL navigated to at top level
  /// refuses to play at all ("Error 153"), because a top-level navigation
  /// carries no referrer for the player to check.
  @Test func youTubeLinksBecomeFramedEmbeds() {
    for raw in [
      "https://www.youtube.com/watch?v=inpok4MKVLM",
      "https://youtu.be/inpok4MKVLM",
      "https://www.youtube.com/embed/inpok4MKVLM",
      "https://www.youtube.com/shorts/inpok4MKVLM",
      "https://www.youtube.com/live/inpok4MKVLM",
    ] {
      let panel = WebPanel(url: URL(string: raw)!)
      #expect(
        panel.url.absoluteString == "https://www.youtube.com/embed/inpok4MKVLM",
        "\(raw) resolved to \(panel.url.absoluteString)")
      #expect(panel.presentation == .player, "\(raw) must be framed or the player refuses")
    }
  }

  /// Autoplay and looping are player parameters on `loadURL`, and `url` stays
  /// the plain identity of the video.
  ///
  /// The `autoplay=1` half is the fix for "Allow media autoplay does nothing":
  /// relaxing the host's media policy is necessary but not sufficient, because
  /// the player will not start on its own unless the URL says to.
  ///
  /// The `playlist=` half is the one that reads like a bug. On a single video
  /// YouTube ignores `loop=1` unless `playlist` names that same video — the
  /// parameter was designed for playlists, and the single-video spelling is a
  /// documented workaround, not something to tidy away.
  @Test func playbackOptionsRideOnLoadURLAndLoopingNamesItsOwnVideo() {
    let link = URL(string: "https://youtu.be/-FlxM_0S2lA?t=2126")!

    let plain = WebPanel(url: link)
    #expect(plain.url.absoluteString == "https://www.youtube.com/embed/-FlxM_0S2lA?start=2126")
    func options(_ panel: WebPanel) -> [String: String] {
      let query = URLComponents(url: panel.loadURL, resolvingAgainstBaseURL: false)!.queryItems ?? []
      return Dictionary(query.compactMap { item in item.value.map { (item.name, $0) } }) { a, _ in a }
    }

    // Muted is the default, so even an untouched panel carries it.
    #expect(options(plain)["mute"] == "1")
    #expect(options(plain)["autoplay"] == nil, "muted is not a request to start playing")

    // The two are independent: muting can be lifted without touching autoplay.
    let loud = WebPanel(url: link, startsMuted: false)
    #expect(options(loud)["mute"] == nil)
    #expect(options(loud)["autoplay"] == nil)

    let playing = WebPanel(url: link, allowsAutoplay: true, loops: true)
    let values = options(playing)

    #expect(values["start"] == "2126", "the offset must survive the options")
    #expect(values["autoplay"] == "1")
    #expect(
      values["mute"] == "1",
      """
      the default must keep autoplay muted. Browsers grant muted autoplay and refuse unmuted \
      autoplay without a user gesture, and the refusal is silent — a blocked autoplay looks \
      exactly like a video waiting to be clicked, which is how this shipped once already
      """)
    #expect(values["loop"] == "1")
    #expect(
      values["playlist"] == "-FlxM_0S2lA",
      "loop=1 on a single video does nothing unless playlist names it")

    // Identity is unchanged by how it is played.
    #expect(playing.url == plain.url)

    // A leading-hyphen id is a real YouTube id and must not be eaten.
    #expect(playing.loadURL.absoluteString.contains("/embed/-FlxM_0S2lA"))
  }

  /// A page that is not an embedded video has nothing to loop, and gains no
  /// player parameters it would not understand.
  @Test func aPlainPageGainsNoPlayerParameters() {
    let panel = WebPanel(
      url: URL(string: "http://127.0.0.1:8080/p/blink-jump/?vc=abc")!,
      allowsAutoplay: true, loops: true)
    #expect(panel.loadURL == panel.url)
    #expect(!panel.loadURL.absoluteString.contains("autoplay"))
  }

  /// The player document's origin must be an unresolvable https origin —
  /// never a real domain, and never the host it embeds.
  ///
  /// The same-origin half is the assertion for a bug that took three wrong
  /// diagnoses to find: giving the document YouTube's own origin looks
  /// considerate and is precisely what the player refuses with Error 152,
  /// because an embed is meant to be cross-origin.
  ///
  /// The unresolvable half is a separate claim. An origin is a statement about
  /// who is embedding, and naming a domain somebody owns would assert their
  /// endorsement of whatever a caller puts in the panel. `.invalid` (RFC 2606)
  /// can never resolve, so it claims nothing about anyone and cannot collide
  /// with a real origin's cookies in the shared data store.
  ///
  /// Asserting the properties rather than the literal, so the origin can be
  /// renamed but not quietly turned into a real domain or the target's own.
  @Test func thePlayerDocumentOriginNamesNoRealDomain() {
    let origin = try! #require(WebPanelView.embedderOrigin)
    let host = try! #require(origin.host())

    #expect(origin.scheme == "https", "the player rejects a non-https embedder")
    #expect(
      host.hasSuffix(".invalid"),
      "the embedder origin must be unresolvable so it claims nothing about a real site; got \(host)"
    )
    for embedded in ["www.youtube.com", "youtube.com", "www.youtube-nocookie.com", "youtu.be"] {
      #expect(host != embedded, "the document must not claim the origin it embeds")
    }
  }

  /// A start offset survives the rewrite, in either spelling.
  ///
  /// It is part of what the author chose, not decoration: `youtu.be/ID?t=68`
  /// points at the exercise, and dropping the offset opens on a minute of
  /// introduction a 20-second break has no room for.
  @Test func aStartOffsetSurvivesTheRewrite() {
    let cases: [(String, String?)] = [
      ("https://youtu.be/IlCyVaoLR4Y?t=68", "start=68"),
      ("https://www.youtube.com/watch?v=IlCyVaoLR4Y&t=90s", "start=90"),
      ("https://www.youtube.com/watch?v=IlCyVaoLR4Y&t=1m30s", "start=90"),
      ("https://www.youtube.com/watch?v=IlCyVaoLR4Y&t=1h2m3s", "start=3723"),
      // No offset, and a tracking parameter that must not become one.
      ("https://www.youtube.com/watch?v=IlCyVaoLR4Y&pp=ygUkYmVzdA", nil),
      ("https://youtu.be/IlCyVaoLR4Y?t=0", nil),
    ]
    for (raw, expected) in cases {
      let resolved = WebPanel(url: URL(string: raw)!).url.absoluteString
      #expect(resolved.hasPrefix("https://www.youtube.com/embed/IlCyVaoLR4Y"), "\(raw) → \(resolved)")
      if let expected {
        #expect(resolved.hasSuffix("?" + expected), "\(raw) → \(resolved), wanted \(expected)")
      } else {
        #expect(!resolved.contains("start="), "\(raw) → \(resolved), wanted no start")
      }
    }
  }

  /// Everything else is left exactly as typed and loaded directly. Framing a
  /// page that sends `X-Frame-Options: DENY` — which is most things worth
  /// logging into — produces a blank frame rather than a refusal you can read.
  @Test func nonYouTubeURLsAreUntouchedAndDirect() {
    for raw in [
      "https://example.com/article",
      "http://127.0.0.1:8080/p/blink-jump/?vc=abc",
      "https://youtube.com.evil.test/watch?v=x",
      "https://evilyoutube.com/watch?v=x",
    ] {
      let panel = WebPanel(url: URL(string: raw)!)
      #expect(panel.url.absoluteString == raw)
      #expect(panel.presentation == .direct)
    }
  }

  /// An explicit presentation beats the URL sniffing, in both directions.
  @Test func anExplicitPresentationWins() {
    let youTube = URL(string: "https://youtu.be/inpok4MKVLM")!
    #expect(WebPanel(url: youTube, presentation: .direct).presentation == .direct)
    #expect(
      WebPanel(url: URL(string: "https://example.com")!, presentation: .player).presentation
        == .player)
  }

  /// `.ambient` refuses the panel outright, so a caller who set one on a
  /// 380×210 toast gets the toast rather than two unusable columns.
  @Test func ambientRefusesAWebPanel() {
    let panel = WebPanel(url: URL(string: "https://example.com")!)
    #expect(RichNotification(webPanel: panel, mode: .ambient).effectiveWebPanel == nil)
    #expect(RichNotification(webPanel: panel, mode: .interrupt).effectiveWebPanel != nil)
  }

  /// The panel replaces the illustration rather than stacking above it — the
  /// surface gets one centre of gravity, not two.
  @Test func aWebPanelSuppressesTheIllustration() {
    let notification = RichNotification(
      illustration: .symbol("eye", pointSize: 56, color: nil),
      webPanel: WebPanel(url: URL(string: "https://example.com")!),
      mode: .interrupt)

    #expect(notification.illustration != nil, "the caller's value is reinterpreted, not rewritten")
    #expect(notification.effectiveIllustration == nil)
  }

  /// The scrim strategy the renderer actually resolves, per mode × Reduce
  /// Transparency. `Legibility` being correct is worth nothing if the view
  /// computes its own answer.
  @Test func theRendererResolvesTheScrimStrategyFromLegibility() {
    func strategy(_ mode: AlertMode, reduceTransparency: Bool) -> ScrimStrategy {
      RichNotificationView(
        notification: RichNotification(title: "x", mode: mode),
        reduceTransparency: reduceTransparency,
        onDismiss: {}
      ).scrimStrategy
    }

    #expect(strategy(.interrupt, reduceTransparency: false) == .none)
    #expect(strategy(.interrupt, reduceTransparency: true) == .none)
    #expect(strategy(.ambient, reduceTransparency: false) == .feathered)
    #expect(strategy(.ambient, reduceTransparency: true) == .solid)
  }

  /// And the palette, likewise resolved rather than reinvented.
  @Test func theRendererResolvesItsTextStylesFromLegibility() {
    let view = RichNotificationView(
      notification: RichNotification(title: "x", mode: .interrupt), onDismiss: {})
    let expected = Legibility.textStyles(colorScheme: .dark)

    #expect(view.styles.title == expected.title)
    #expect(view.styles.message == expected.message)
    #expect(view.styles.footnote == expected.footnote)
  }

  // MARK: - Layout, with the countdown children actually mounted

  /// A clock is injected here specifically so `CountdownRing`, `TickMarks` and
  /// `DismissIndicatorView` bodies are evaluated by the suite at all. Without
  /// one, `RichNotificationView.countdown` renders nothing and three of the six
  /// new views never run outside a human's screen.
  ///
  /// The ring's clock is driven to the **half-way point** through the injected
  /// date seam. At t=0 `steppedArc(.task, 20, 20)` is 0, so the arc draws
  /// nothing and the measured delta would be almost entirely the 46pt numeral —
  /// which is not what a test called "the ring draws" should be measuring. At
  /// t=10 the arc is half-drawn and genuinely participates.
  @Test func theRingAndTheDismissBarBothDraw() throws {
    let halfDrained = try #require(
      clock(Countdown(task: timer(), autoDismiss: nil), elapsed: 10))
    let barred = try #require(
      clock(Countdown(task: nil, autoDismiss: .init(delay: 5, indicator: .bar))))
    let size = CGSize(width: 400, height: 400)

    let withRing = render(
      RichNotification(title: "Break", taskTimer: timer(), mode: .interrupt),
      size: size, clock: halfDrained)
    let withBar = render(
      RichNotification(
        title: "Break", autoDismiss: .init(delay: 5, indicator: .bar), mode: .interrupt),
      size: size, clock: barred)
    let withNeither = render(
      RichNotification(title: "Break", mode: .interrupt), size: size)

    // Sanity: the clock really is mid-drain, so the arc is actually on screen.
    #expect(halfDrained.phase == .task)
    #expect(
      CountdownRing.steppedArc(
        phase: halfDrained.phase, secondsRemaining: 10, duration: 20) == 0.5)

    #expect(
      withRing.opaque > withNeither.opaque + 500,
      "the ring, its ticks, its arc and its numeral must all draw: \(withRing.opaque) vs \(withNeither.opaque)"
    )
    #expect(
      withBar.opaque > withNeither.opaque,
      "the dismiss bar must draw: \(withBar.opaque) vs \(withNeither.opaque)")
  }

  // MARK: - The ambient countdown

  /// The gap that let the entire ambient-contrast fix be reverted with all 80
  /// tests green: **no test rendered an ambient alert with a live clock.**
  /// `theRingAndTheDismissBarBothDraw` above uses `.interrupt`, where
  /// `scrimStrategy` is `.none` and the countdown scrim is therefore a no-op.
  ///
  /// The alert here has no title, message or footnote, so the only thing on the
  /// surface is the countdown — which means every measurement below is
  /// unambiguously about the countdown rather than about the text block's own
  /// scrim.
  @Test func theAmbientDismissBarIsLegibleAndScrimmed() throws {
    let ambientClock = try #require(
      clock(Countdown(task: nil, autoDismiss: .init(delay: 20, indicator: .bar))))
    let interruptClock = try #require(
      clock(Countdown(task: nil, autoDismiss: .init(delay: 20, indicator: .bar))))
    let size = CGSize(width: 400, height: 220)

    let ambient = render(
      RichNotification(autoDismiss: .init(delay: 20, indicator: .bar), mode: .ambient),
      size: size, clock: ambientClock)
    let interrupt = render(
      RichNotification(autoDismiss: .init(delay: 20, indicator: .bar), mode: .interrupt),
      size: size, clock: interruptClock)

    // 1. The bar is an *opaque* light fill. `white.opacity(0.55)` scores as
    //    `light` but never as `solidLight`, which is what makes this catch a
    //    revert to the translucent original.
    #expect(
      ambient.solidLight > 20,
      "the ambient dismiss bar must be an opaque light fill, got \(ambient.solidLight)pt²")

    // 2. The countdown region is scrimmed in `.ambient` and deliberately not in
    //    `.interrupt`, where a global scrim already covers everything.
    #expect(
      ambient.alphaSum > interrupt.alphaSum * 2,
      """
      the ambient countdown must sit on its own scrim; \
      ambient=\(Int(ambient.alphaSum)) interrupt=\(Int(interrupt.alphaSum))
      """)

    // 3. The bar casts an opposing shadow. Measured on `.interrupt`, where
    //    there is no scrim to contribute dark translucent pixels of its own —
    //    on the ambient render the scrim would mask a missing shadow entirely.
    #expect(
      interrupt.darkHalo > 5,
      "the dismiss bar must carry a dark shadow, got \(interrupt.darkHalo)pt²")
  }

  /// A true 2×2×2 over mode, Reduce Motion and Reduce Transparency.
  ///
  /// The original version tied the mode to the flag, so it covered two of four
  /// combinations and missed exactly the two with dedicated code paths:
  /// `.interrupt` + Reduce Transparency (the opaque black layer) and `.ambient`
  /// without it (`FeatheredScrim`, therefore never evaluated by the suite at
  /// all).
  ///
  /// **What a headless snapshot can and cannot see, stated exactly**, because
  /// two earlier versions of this test each claimed more than they proved. With
  /// Reduce Motion *off*, `enter()` sets the final opacity inside
  /// `withAnimation`, and SwiftUI's animations never advance in a test process:
  /// there is no display link and no `NSApp` run loop to drive them. Measured —
  /// the drawn area is still exactly zero four seconds and eight hundred
  /// run-loop turns later. So those four combinations are permanently
  /// transparent here, and no amount of pumping fixes it.
  ///
  /// What still happens for all eight is the part worth testing: the body is
  /// evaluated and the whole tree lays out and draws during `cacheDisplay`. A
  /// crash, a broken layout or an unsatisfiable constraint in the
  /// Reduce-Motion-off branch surfaces regardless of the final composite being
  /// transparent. So all eight assert that the render completed at full size,
  /// and the four that are actually visible additionally assert that content
  /// arrived. Claiming more than that would be the third wrong version.
  @Test func everyModeAndAccessibilityCombinationDraws() throws {
    let ticking = try #require(
      clock(Countdown(task: timer(), autoDismiss: .init(delay: 5, indicator: .bar))))
    let size = CGSize(width: 460, height: 520)

    for mode in [AlertMode.interrupt, .ambient] {
      for reduceMotion in [true, false] {
        for reduceTransparency in [true, false] {
          let label =
            "mode=\(mode) reduceMotion=\(reduceMotion) reduceTransparency=\(reduceTransparency)"
          let areas = render(
            RichNotification(
              illustration: .symbol("eye", pointSize: 48, color: nil),
              title: "Break",
              message: "Look 20 feet away",
              footnote: "ESC to skip",
              buttons: [.init(title: "Done", style: .primary, action: {})],
              taskTimer: timer(),
              autoDismiss: .init(delay: 5, indicator: .bar),
              mode: mode),
            size: size,
            reduceTransparency: reduceTransparency,
            reduceMotion: reduceMotion,
            clock: ticking)

          #expect(
            abs(areas.total - size.width * size.height) < 1,
            "\(label) did not render at full size (\(areas.total)pt², scale \(areas.scale))")

          if reduceMotion {
            #expect(areas.ink > 100, "\(label) drew \(areas.ink)pt² of ink")
          }
        }
      }
    }
  }

  /// The illustration is arbitrary, which is the claim the third renderer
  /// exists to make: `StandardNotificationView` pins bitmaps to a hardcoded
  /// 48×48.
  ///
  /// Measured as drawn area rather than `fittingSize`, because
  /// `sizeDecoupledFromHost` deliberately gives this view no intrinsic size —
  /// that is the whole point of it, and a test reading `fittingSize` through it
  /// now reads a constant 10×10 for every input.
  @Test func theIllustrationSizeReachesTheLayout() {
    let size = CGSize(width: 500, height: 480)
    let small = render(
      RichNotification(
        illustration: .symbol("square.fill", pointSize: 40, color: .white), mode: .interrupt),
      size: size)
    let large = render(
      RichNotification(
        illustration: .symbol("square.fill", pointSize: 200, color: .white), mode: .interrupt),
      size: size)

    #expect(small.opaque > 100, "the small illustration must draw at all")
    #expect(
      large.opaque > small.opaque * 4,
      "a 200pt illustration must cover far more than a 40pt one: \(large.opaque) vs \(small.opaque)")
  }

  /// Illustration, buttons and a footnote coexisting is the combination
  /// `SVGNotification` cannot express at all — it has no `buttons` property.
  @Test func illustrationButtonsAndFootnoteCoexist() {
    let bare = render(
      RichNotification(title: "Break", message: "Look away", mode: .interrupt),
      size: CGSize(width: 460, height: 400))
    let full = render(
      RichNotification(
        title: "Break",
        message: "Look away",
        footnote: "Press ESC or click anywhere to skip",
        buttons: [
          .init(title: "Done", style: .primary, action: {}),
          .init(title: "Skip", style: .secondary, action: {}),
        ],
        mode: .interrupt),
      size: CGSize(width: 460, height: 400))

    #expect(full.opaque > bare.opaque + 250, "buttons and a footnote must add visible content")
  }
}

// MARK: - Window geometry

/// The gap the whole suite had: **every other test measures a hosting view
/// directly and never puts one inside a real `NSWindow`.**
///
/// That is precisely why `RichNotificationView` could resize its own window by
/// a factor of twenty-five with 80 tests green. A demo harness found it by
/// looking at the screen. These tests go through the public
/// `OverlayWindowManager.show` and assert on `NSWindow.frame`.
///
/// The run-loop pump is not incidental. AppKit resolves the offending
/// constraint one pass *after* `show()` returns, so a test that measures
/// synchronously — as the first reproduction attempt did — sees the correct
/// frame and reports success.
@MainActor
struct OverlayGeometryTests {

  /// Long enough that a wrapped layout wants far more height than the window.
  static let longMessage =
    "Your changes were saved just now. This pass also folded in two duplicate "
    + "entries that were created earlier today while this Mac was offline."

  private func pump(rounds: Int = 40) {
    for _ in 0..<rounds {
      RunLoop.main.run(until: Date().addingTimeInterval(0.005))
    }
  }

  /// Shows `notification` through the real manager and returns the frame the
  /// window actually settles at.
  private func settledFrame(
    _ notification: RichNotification,
    configuration: OverlayWindowManager.Configuration
  ) throws -> CGRect {
    let manager = OverlayWindowManager.shared
    let id = UUID()
    _ = manager.show(id: id, configuration: configuration, countdown: notification.countdown) {
      RichNotificationView(
        notification: notification, reduceMotion: true, reduceTransparency: false, onDismiss: {})
    }
    // `defer`, because `#require` throws: without it a failed expectation
    // leaks a window into a process-wide singleton that every later test in
    // this suite then shows into.
    defer { manager.dismiss(id: id, animated: false) }
    let window = try #require(manager.activeWindows[id])
    pump()
    return window.frame
  }

  /// An `.ambient` window keeps the size its caller asked for.
  ///
  /// Before `sizeDecoupledFromHost`, this exact case settled at
  /// `(1328, -2059, 380, 2289)` — eleven times the requested height, with the
  /// window hanging off the bottom of the display.
  @Test func anAmbientWindowKeepsTheSizeItWasGiven() throws {
    let frame = try settledFrame(
      RichNotification(
        title: "Synced to iCloud",
        message: Self.longMessage,
        autoDismiss: .init(delay: 20, indicator: .bar),
        mode: .ambient),
      configuration: .ambient(
        position: .bottomRight, width: 380, height: 210, animatePresentation: false))

    #expect(abs(frame.width - 380) <= 1, "width drifted to \(frame.width)")
    #expect(abs(frame.height - 210) <= 1, "height drifted to \(frame.height)")
  }

  /// …and stays on the screen it was positioned on. Height and origin fail
  /// together, but asserting the origin separately is what makes the failure
  /// message say "off-screen" rather than just "too tall".
  @Test func anAmbientWindowStaysWhereItWasPut() throws {
    let screen = try #require(NSScreen.main ?? NSScreen.screens.first)
    let frame = try settledFrame(
      RichNotification(
        title: "Synced to iCloud", message: Self.longMessage, mode: .ambient),
      configuration: .ambient(
        position: .bottomRight, width: 380, height: 210, animatePresentation: false,
        screen: screen))

    #expect(
      screen.frame.contains(frame),
      "the window left its screen: \(frame) is not inside \(screen.frame)")
  }

  /// Content that cannot possibly fit does not enlarge the window — **and the
  /// alert is still legible afterwards**, which is the half this test was
  /// missing.
  ///
  /// The frame assertions alone passed against a window that was correctly
  /// sized and *completely empty*: a 600×500 image in a 380×210 window pushed
  /// the title and message outside the clip, and the render measured zero inked
  /// pixels. That is the same shape of gap twice fixed elsewhere in this suite —
  /// an assertion aimed at the thing that used to be broken rather than at the
  /// thing that matters.
  @Test func oversizedContentIsScaledDownRatherThanEvictingTheAlert() throws {
    let notification = RichNotification(
      illustration: .image(
        NSImage(size: CGSize(width: 600, height: 500)), size: CGSize(width: 600, height: 500)),
      title: "Synced",
      message: Self.longMessage,
      mode: .ambient)

    let frame = try settledFrame(
      notification,
      configuration: .ambient(
        position: .bottomRight, width: 380, height: 210, animatePresentation: false))

    #expect(abs(frame.width - 380) <= 1, "width drifted to \(frame.width)")
    #expect(abs(frame.height - 210) <= 1, "height drifted to \(frame.height)")

    // …and the window is not blank.
    let drawn = RichRendererPixelTests().render(
      notification, size: CGSize(width: 380, height: 210))
    #expect(
      drawn.ink > 500,
      "an oversized illustration must scale down, not evict the alert; drew \(drawn.ink)pt²")
  }

  /// **`.interrupt` was affected too**, and this is the assertion that says so.
  ///
  /// The first diagnosis assumed only fixed-size windows could be distorted,
  /// since interrupt asks for the whole screen anyway. Measured, an interrupt
  /// with a long message settled at `(0, -27049, 1728, 28166)` against a
  /// 1728×1117 screen — twenty-five times too tall, invisible because the
  /// window is transparent, and quietly centring the content thousands of
  /// points below the display. A fix scoped to `.ambient` would have shipped
  /// this.
  @Test func anInterruptWindowCoversExactlyItsScreen() throws {
    let screen = try #require(NSScreen.main ?? NSScreen.screens.first)
    let frame = try settledFrame(
      RichNotification(
        title: "Time for a break",
        message: Self.longMessage,
        taskTimer: TaskTimer(
          duration: 20, unitLabel: "seconds", completionLabel: "Break complete"),
        mode: .interrupt),
      configuration: .interrupt(animatePresentation: false, screen: screen))

    #expect(
      abs(frame.height - screen.frame.height) <= 1,
      "interrupt height \(frame.height) against a \(screen.frame.height)pt screen")
    #expect(abs(frame.width - screen.frame.width) <= 1)
    #expect(abs(frame.origin.y - screen.frame.origin.y) <= 1)
  }

  /// The control. `StandardNotificationView` under an identical configuration
  /// was never affected, which is what established that the defect belonged to
  /// the new renderer rather than to `OverlayWindowManager`.
  @Test func theExistingRendererIsUnaffectedUnderTheSameConfiguration() throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()
    _ = manager.show(
      id: id,
      configuration: .ambient(
        position: .bottomRight, width: 380, height: 210, animatePresentation: false)
    ) {
      StandardNotificationView(
        notification: StandardNotification(title: "Synced", message: Self.longMessage),
        onDismiss: {})
    }
    defer { manager.dismiss(id: id, animated: false) }
    let window = try #require(manager.activeWindows[id])
    pump()
    #expect(abs(window.frame.height - 210) <= 1)
  }
}
