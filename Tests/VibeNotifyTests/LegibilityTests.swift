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
  @Test func textIsLightInBothModesAndBothColorSchemes() {
    for mode in [AlertMode.interrupt, .ambient] {
      for scheme in [ColorScheme.light, .dark] {
        let styles = Legibility.textStyles(mode: mode, colorScheme: scheme)
        #expect(luminance(styles.title.color) > 0.9, "title must be light for \(mode)/\(scheme)")
        #expect(luminance(styles.message.color) > 0.9)
        #expect(luminance(styles.footnote.color) > 0.9)
      }
    }
  }

  /// The colour scheme must not reach the palette at all — asserted as
  /// equality of the whole style triple, so adding a scheme-dependent branch
  /// anywhere in it fails here.
  @Test func theColorSchemeDoesNotReachThePalette() {
    for mode in [AlertMode.interrupt, .ambient] {
      let light = Legibility.textStyles(mode: mode, colorScheme: .light)
      let dark = Legibility.textStyles(mode: mode, colorScheme: .dark)
      #expect(light.title == dark.title)
      #expect(light.message == dark.message)
      #expect(light.footnote == dark.footnote)
    }
  }

  /// Kills both halves of the old bug at once: the `.clear` shadow under dark
  /// text in light mode (`SVGNotificationView.swift:47`) and the *white* glow
  /// under white text in dark mode (`:47`, `:56`). A shadow opposes its text
  /// or it is not doing anything.
  @Test func everyShadowOpposesItsTextAndIsNeverClear() {
    for mode in [AlertMode.interrupt, .ambient] {
      let styles = Legibility.textStyles(mode: mode, colorScheme: .dark)
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

/// The one place a view is actually mounted.
///
/// Not a "construct it and assert non-nil" test — that asserts nothing. This
/// hosts the renderer, forces layout, and reads back the measured size, which
/// is the claim the third renderer exists to make: the illustration is
/// arbitrary, not the hardcoded 48×48 `StandardNotificationView` pins bitmaps
/// to. It also means every `body` in this file — scrim, ring, buttons — is
/// evaluated at least once by the suite rather than only by a human looking at
/// a screen.
@MainActor
struct RichRendererLayoutTests {

  private func measure(_ notification: RichNotification) -> CGSize {
    let host = NSHostingView(
      rootView: RichNotificationView(
        notification: notification,
        reduceMotion: false,
        reduceTransparency: false,
        onDismiss: {}))
    host.layoutSubtreeIfNeeded()
    return host.fittingSize
  }

  /// A 220×150 illustration must produce a surface at least that wide. The
  /// fixed 48×48 frame is the defect being escaped.
  @Test func theIllustrationSizeReachesTheLayout() {
    let small = measure(
      RichNotification(
        illustration: .symbol("eye", pointSize: 40, color: nil), title: "Break", mode: .interrupt))
    let large = measure(
      RichNotification(
        illustration: .image(
          NSImage(size: CGSize(width: 220, height: 150)), size: CGSize(width: 220, height: 150)),
        title: "Break", mode: .interrupt))

    #expect(small.width > 0 && small.height > 0)
    #expect(large.width >= 220)
    #expect(
      large.height > small.height,
      "a 150pt illustration must make the surface taller than a 40pt one")
  }

  /// Buttons and a footnote both render — the combination `SVGNotification`
  /// cannot express at all, since it has no `buttons` property.
  @Test func illustrationButtonsAndFootnoteCoexist() {
    let withoutButtons = measure(
      RichNotification(title: "Break", message: "Look away", mode: .interrupt))
    let withButtons = measure(
      RichNotification(
        title: "Break",
        message: "Look away",
        footnote: "Press ESC or click anywhere to skip",
        buttons: [
          .init(title: "Done", style: .primary, action: {}),
          .init(title: "Skip", style: .secondary, action: {}),
        ],
        mode: .interrupt))

    #expect(withButtons.height > withoutButtons.height)
    #expect(withButtons.width >= withoutButtons.width)
  }

  /// Both accessibility branches must lay out, including the solid backdrop
  /// that replaces the feathered scrim — the branch no one will look at.
  @Test func bothAccessibilityBranchesLayOut() {
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
              mode: reduceTransparency ? .ambient : .interrupt),
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            onDismiss: {}))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 0)
      }
    }
  }
}
