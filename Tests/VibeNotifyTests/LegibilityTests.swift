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

  /// What a rendered surface is made of. All counts are pixels.
  struct Pixels {
    var total = 0
    /// Alpha > 0.5 — a genuinely solid pixel.
    var opaque = 0
    /// Alpha > 0.3 — anything drawn firmly enough to read as content rather
    /// than as the tail of a gradient or a shadow.
    var ink = 0
    /// `ink` that is also light (luminance > 0.85).
    ///
    /// The alpha floor is 0.3 rather than 0.9 deliberately: the palette's
    /// message is `white.opacity(0.9)` and its footnote `white.opacity(0.6)`,
    /// so a stricter floor would score correct light text as absent. What is
    /// being distinguished here is *light versus dark*, not opaque versus
    /// translucent.
    var light = 0
    /// Dark *and* partially transparent: with light content on nothing, the
    /// only thing that produces these is a drop shadow. Antialiased edges of
    /// white glyphs are light, not dark.
    var darkHalo = 0
    /// Total ink laid down, however faint. A scrim moves this a lot.
    var alphaSum = 0.0

    var lightFraction: Double { ink == 0 ? 0 : Double(light) / Double(ink) }
    var opaqueFraction: Double { total == 0 ? 0 : Double(opaque) / Double(total) }
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
  ) -> Pixels {
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

    var pixels = Pixels()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
      Issue.record("the host view produced no bitmap representation")
      return pixels
    }
    host.cacheDisplay(in: host.bounds, to: rep)

    for x in 0..<rep.pixelsWide {
      for y in 0..<rep.pixelsHigh {
        guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        let a = Double(colour.alphaComponent)
        let l =
          0.2126 * Double(colour.redComponent) + 0.7152 * Double(colour.greenComponent)
          + 0.0722 * Double(colour.blueComponent)
        pixels.total += 1
        pixels.alphaSum += a
        if a > 0.5 { pixels.opaque += 1 }
        if a > 0.3 { pixels.ink += 1 }
        if a > 0.3 && l > 0.85 { pixels.light += 1 }
        if a > 0.02 && a < 0.5 && l < 0.3 { pixels.darkHalo += 1 }
      }
    }
    return pixels
  }

  private func clock(_ countdown: Countdown) -> NotificationClock? {
    NotificationClock(id: UUID(), countdown: countdown)
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
      let pixels = render(notification)
      #expect(pixels.ink > 200, "expected visible text, got \(pixels.ink) inked pixels")
      #expect(
        pixels.lightFraction > 0.5,
        "text must render light against an unknown desktop; light fraction was \(pixels.lightFraction)"
      )
    }
  }

  /// Every text slot casts a **dark** shadow.
  ///
  /// With light content over nothing, dark semi-transparent pixels can only be
  /// a drop shadow — a white glyph's antialiased edge is light. `color: .clear`
  /// (the shipped bug at `SVGNotificationView.swift:47`) drives this to zero;
  /// so does a white glow, which is the *other* half of that bug, because the
  /// halo it produces is light rather than dark.
  @Test func everyTextSlotCastsADarkShadow() {
    for notification in [
      RichNotification(title: "Look away now", mode: .interrupt),
      RichNotification(message: "Focus on something twenty feet away", mode: .interrupt),
      RichNotification(footnote: "Press ESC or click anywhere to skip", mode: .interrupt),
    ] {
      let pixels = render(notification)
      #expect(
        pixels.darkHalo > 500,
        "a .clear shadow is not a shadow and a light glow is not one either; dark halo was \(pixels.darkHalo)"
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
    let pixels = render(
      RichNotification(
        buttons: [.init(title: "Done", style: .primary, action: {})], mode: .interrupt),
      size: CGSize(width: 300, height: 120))

    #expect(pixels.opaque > 500, "expected a visible button")
    #expect(
      pixels.lightFraction > 0.5,
      """
      the primary button must be an opaque light fill that survives a blurred light desktop, \
      not a flat accent fill; light fraction was \(pixels.lightFraction)
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
  @Test func theCountdownChildrenMountAndOccupySpace() throws {
    let ringed = try #require(clock(Countdown(task: timer(), autoDismiss: nil)))
    let barred = try #require(
      clock(Countdown(task: nil, autoDismiss: .init(delay: 5, indicator: .bar))))

    let withRing = render(
      RichNotification(title: "Break", taskTimer: timer(), mode: .interrupt),
      size: CGSize(width: 400, height: 400), clock: ringed)
    let withBar = render(
      RichNotification(
        title: "Break", autoDismiss: .init(delay: 5, indicator: .bar), mode: .interrupt),
      size: CGSize(width: 400, height: 400), clock: barred)
    let withNeither = render(
      RichNotification(title: "Break", mode: .interrupt),
      size: CGSize(width: 400, height: 400))

    #expect(
      withRing.opaque > withNeither.opaque + 2000,
      "the ring, its ticks and its numeral must all draw: \(withRing.opaque) vs \(withNeither.opaque)"
    )
    #expect(
      withBar.opaque > withNeither.opaque,
      "the dismiss bar must draw: \(withBar.opaque) vs \(withNeither.opaque)")
  }

  /// A true 2×2×2 over mode, Reduce Motion and Reduce Transparency.
  ///
  /// The previous version tied the mode to the flag, so it covered two of four
  /// combinations and missed exactly the two with dedicated code paths:
  /// `.interrupt` + Reduce Transparency (the opaque black layer) and `.ambient`
  /// without it (`FeatheredScrim`, therefore never evaluated by the suite at
  /// all).
  ///
  /// Asserted on **layout**, not pixels, and the reason is worth recording. With
  /// Reduce Motion *off*, the entrance spring starts at
  /// `entranceOpacity = 0` and has not run by the time `cacheDisplay` snapshots,
  /// so the frame is legitimately empty — which is an artifact of snapshotting
  /// an animation on frame zero, and incidentally a confirmation that the
  /// Reduce Motion branch really does skip the entrance. `fittingSize` forces
  /// full body evaluation regardless of opacity, which is what this test is
  /// for; the colour and scrim claims are asserted by the dedicated pixel tests
  /// above, where Reduce Motion is on.
  @Test func everyModeAndAccessibilityCombinationEvaluates() throws {
    let ticking = try #require(
      clock(Countdown(task: timer(), autoDismiss: .init(delay: 5, indicator: .bar))))

    for mode in [AlertMode.interrupt, .ambient] {
      for reduceMotion in [true, false] {
        for reduceTransparency in [true, false] {
          let host = NSHostingView(
            rootView: RichNotificationView(
              notification: RichNotification(
                illustration: .symbol("eye", pointSize: 48, color: nil),
                title: "Break",
                message: "Look 20 feet away",
                footnote: "ESC to skip",
                buttons: [.init(title: "Done", style: .primary, action: {})],
                taskTimer: timer(),
                autoDismiss: .init(delay: 5, indicator: .bar),
                mode: mode),
              reduceMotion: reduceMotion,
              reduceTransparency: reduceTransparency,
              onDismiss: {}
            ).environment(\.notificationClock, ticking))
          host.layoutSubtreeIfNeeded()

          #expect(
            host.fittingSize.height > 0,
            "mode=\(mode) reduceMotion=\(reduceMotion) reduceTransparency=\(reduceTransparency) did not lay out"
          )
        }
      }
    }
  }

  /// The illustration is arbitrary, which is the claim the third renderer
  /// exists to make: `StandardNotificationView` pins bitmaps to a hardcoded
  /// 48×48.
  @Test func theIllustrationSizeReachesTheLayout() {
    func height(_ illustration: RichNotification.Illustration) -> CGFloat {
      let host = NSHostingView(
        rootView: RichNotificationView(
          notification: RichNotification(illustration: illustration, title: "Break", mode: .interrupt),
          reduceMotion: true, reduceTransparency: false, onDismiss: {}))
      host.layoutSubtreeIfNeeded()
      return host.fittingSize.height
    }

    let small = height(.symbol("eye", pointSize: 40, color: nil))
    let large = height(
      .image(NSImage(size: CGSize(width: 220, height: 150)), size: CGSize(width: 220, height: 150)))

    #expect(small > 0)
    #expect(large > small, "a 150pt illustration must make the surface taller than a 40pt one")
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

    #expect(full.opaque > bare.opaque + 1000, "buttons and a footnote must add visible content")
  }
}
