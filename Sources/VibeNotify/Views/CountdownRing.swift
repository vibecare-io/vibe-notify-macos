import SwiftUI

/// The large, tick-marked task ring: a numeral, a unit label under it, and a
/// draining arc. After the illustration it is the largest element on the
/// surface, because it is what the user was asked to obey.
///
/// **Why this is a separate view from `RichNotificationView`.**
/// `NotificationClock` is a Combine `ObservableObject`, not `@Observable`. A
/// view that reads `@Environment(\.notificationClock)` receives the *reference*
/// and nothing more — SwiftUI invalidates an environment reader on the stored
/// value's identity, and that identity never changes for the life of the
/// overlay, so an environment read alone renders the initial number once and
/// then sits frozen. The working pattern, documented on
/// `EnvironmentValues.notificationClock`, is this two-view split: the parent
/// reads the environment and hands the reference to a child holding it as
/// `@ObservedObject`, which is what subscribes to `objectWillChange`.
///
/// The split is load-bearing in the other direction too. Converting the clock
/// to `@Observable` would remove the wrapper but make *whatever reads
/// `remaining`* re-evaluate — and in the parent that means `SVGView`, whose
/// re-parse is not free, ten times a second. Confining the subscription to this
/// view is what keeps per-tick invalidation off the illustration.
struct CountdownRing: View {

  @ObservedObject var clock: NotificationClock

  /// The model, not a pre-computed completion state. The completion state is a
  /// function of `clock.phase` and `clock.didCompleteTask`, so computing it in
  /// the parent would freeze it: the parent reads the clock out of the
  /// environment and therefore never re-evaluates when the phase changes.
  /// Anything derived from the clock has to be derived *here*, on the side of
  /// the split that subscribes.
  let notification: RichNotification
  let timer: TaskTimer
  /// Whether Done was pressed while the task was still counting. Parent
  /// `@State`, so it propagates on its own.
  let completedEarly: Bool
  let reduceMotion: Bool

  private var completion: RichNotification.CompletionState {
    notification.completionState(
      phase: clock.phase,
      didCompleteTask: clock.didCompleteTask,
      completedEarly: completedEarly)
  }

  /// Diameter of the ring. Sized to be the second-largest thing on the surface.
  static let diameter: CGFloat = 164
  static let lineWidth: CGFloat = 9

  /// **Twenty-four, down from forty.** At 148 points across, forty 1.5-point
  /// ticks at 22% white sat 11 points apart and antialiased into a grey fringe
  /// — a texture, not a dial. The reported symptom was that they "read as muddy
  /// at this size", and the cause is spatial frequency, not colour: no opacity
  /// makes forty hairlines at that pitch resolve. Twenty-four at 2 points and
  /// 34% do, and a 15° pitch is a dial anyone can read.
  static let tickCount: Int = 24
  static let tickLength: CGFloat = 7
  static let tickWidth: CGFloat = 2
  /// Gap between the outside of the track and the inside of the ticks. Small
  /// enough that the two read as one object rather than as a ring with a
  /// separate sunburst floating around it, which is what a 10-point gap did.
  static let tickGap: CGFloat = 5

  /// The stroke once a task genuinely ran to zero. Not used for an early Done:
  /// the colour is part of the claim, and the claim has to be true.
  static let successStroke = Color(red: 0.35, green: 0.85, blue: 0.55)

  /// Drained fraction of the arc, `0...1`.
  ///
  /// Set **once** per phase and animated by Core Animation, which is the whole
  /// reason the body is not re-evaluated per frame. A `Timer` publisher into
  /// `@State` would invalidate everything above it once a second *and* drift
  /// against the wall clock, so the digit and the deadline would eventually
  /// disagree.
  @State private var arc: CGFloat = 0

  /// The last whole-second count observed while the task was actually running.
  ///
  /// Exists for cancellation. `NotificationClock.remaining` and `progress` are
  /// both pinned (0 and 1) the moment the phase goes terminal, so once Skip or
  /// ESC lands there is no way to ask the clock where the countdown had got to.
  /// Without this the ring would show a "0" the user never reached, and — under
  /// Reduce Motion — an arc that *fills* on the way out, both of which are the
  /// surface claiming something happened that did not.
  @State private var lastSecondsRemaining: Int = 0

  private var stroke: Color {
    completion.isCompletion ? Self.successStroke : Legibility.TextStyle.title.color
  }

  var body: some View {
    ZStack {
      ticks
      track
      arcLayer
      centre
    }
    .frame(width: Self.diameter, height: Self.diameter)
    .onAppear {
      captureSecond()
      armArc()
    }
    // The arc is re-armed on every phase change rather than on a timer: `.task`
    // → `.dismissing` is the only transition that changes what it should be
    // showing, and it is the transition that must *snap* rather than sweep.
    .onChange(of: clock.phase) { _, _ in armArc() }
    // Not a redraw driver — the body already re-evaluates on every tick, since
    // this view observes the clock. This only keeps the freeze value current so
    // that a cancellation has something truthful to freeze *at*.
    .onChange(of: clock.lastTick) { _, _ in captureSecond() }
  }

  /// Records where the countdown is, but only while it is genuinely running.
  /// Terminal phases deliberately leave the value alone: that is the freeze.
  private func captureSecond() {
    guard clock.phase == .task else { return }
    lastSecondsRemaining = max(0, Int(clock.remaining.rounded(.up)))
  }

  // MARK: - Layers

  /// The unfilled part of the dial.
  ///
  /// Two strokes, not one. A single `white.opacity(0.18)` ring was the reported
  /// "faint track" problem, and simply raising the alpha does not fix it: over
  /// the light half of a split desktop a pale ring on a pale field is *still*
  /// invisible, so the fix has to work in both directions like everything else
  /// here. The dark stroke underneath is the same opposition rule the text
  /// shadows follow — it gives the light track something to be light against on
  /// backdrops the library does not own.
  private var track: some View {
    ZStack {
      // Blurred and wider than the track it sits under, so it reads as a soft
      // aura rather than as a second concentric ring. Measured the other way
      // first: a crisp `black.opacity(0.32)` at `lineWidth + 1.5` made the
      // unfilled arc read *darker* than the backdrop on a mid-grey field, which
      // inverts what a track means — the unfilled part of a dial is a dimmer
      // version of the filled part, not its negative.
      Circle()
        .stroke(Color.black.opacity(0.28), lineWidth: Self.lineWidth + 5)
        .blur(radius: 3)
      Circle()
        .stroke(Color.white.opacity(0.28), lineWidth: Self.lineWidth)
    }
  }

  @ViewBuilder
  private var arcLayer: some View {
    if reduceMotion {
      // Reduce Motion does **not** stop the countdown — it is information being
      // read, not decoration. Only the cadence changes, to discrete one-second
      // steps, driven by the same `TimelineView` that drives the numeral so the
      // two can never disagree about which second it is.
      TimelineView(.periodic(from: .now, by: 1)) { _ in
        arcShape(trim: steppedArc)
      }
    } else {
      arcShape(trim: arc)
    }
  }

  private func arcShape(trim: CGFloat) -> some View {
    Circle()
      .trim(from: 0, to: trim)
      .stroke(stroke, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
      // 12 o'clock, clockwise.
      .rotationEffect(.degrees(-90))
      .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
  }

  private var ticks: some View {
    TickMarks(count: Self.tickCount, length: Self.tickLength)
      .stroke(
        Color.white.opacity(0.34),
        style: StrokeStyle(lineWidth: Self.tickWidth, lineCap: .round)
      )
      // Negative padding grows the tick ring outward from the ring's own frame
      // without moving anything below it. Derived rather than eyeballed, so
      // that changing `lineWidth` or `diameter` cannot silently reopen the gap:
      // the stroke straddles the circle, so its outer edge is half a line width
      // beyond the frame, and the ticks start `tickGap` past that.
      .padding(-(Self.lineWidth / 2 + Self.tickGap + Self.tickLength))
      .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
  }

  @ViewBuilder
  private var centre: some View {
    if let label = completion.label {
      VStack(spacing: 8) {
        Image(systemName: "checkmark")
          .font(.system(size: 32, weight: .semibold))
          .foregroundColor(stroke)
        Text(label)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(Legibility.TextStyle.message.color)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: Self.diameter - 32)
      }
      .shadow(
        color: Legibility.TextStyle.message.shadowColor,
        radius: Legibility.TextStyle.message.shadowRadius,
        y: Legibility.TextStyle.message.shadowOffsetY)
    } else {
      // Scoped to the numeral alone, deliberately: this is the only thing on
      // the surface that changes once a second, and `TimelineView` is aligned
      // to the wall clock rather than accumulating from ticks.
      TimelineView(.periodic(from: .now, by: 1)) { _ in
        // Spacing 0, not 2, and a negative top pad on the label: a numeral's
        // ascender box is much taller than its digits, so the *typographic* gap
        // is already several points wider than the number says. The numeral and
        // its unit are one readout and have to sit as one — the reported
        // symptom was that the pairing "could be tighter", and 2 points of
        // stack spacing on top of the digit's own leading is what made them
        // read as two stacked labels.
        VStack(spacing: 0) {
          Text("\(secondsRemaining)")
            // 42, down from 46. The numeral was set larger than the 30-point
            // title, so the two competed for the top of the hierarchy; the
            // title has to win that, and a dial readout at 42 in a 164-point
            // ring is still unmistakably the second-largest thing here.
            .font(.system(size: 42, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(Legibility.TextStyle.title.color)
            .shadow(
              color: Legibility.TextStyle.title.shadowColor,
              radius: Legibility.TextStyle.title.shadowRadius,
              y: Legibility.TextStyle.title.shadowOffsetY)
          Text(timer.unitLabel)
            // Small caps with wide tracking, which is what a unit under a dial
            // readout is. It also stops "seconds" competing with the message
            // line above the ring at the same 11–13 point size: they now differ
            // in *kind*, not just in size.
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundColor(Legibility.TextStyle.footnote.color)
            .shadow(
              color: Legibility.TextStyle.footnote.shadowColor,
              radius: Legibility.TextStyle.footnote.shadowRadius,
              y: Legibility.TextStyle.footnote.shadowOffsetY)
            .padding(.top, -4)
        }
      }
    }
  }

  // MARK: - Values

  /// The number in the middle of the ring.
  ///
  /// Live while the task runs, frozen at its last observed value afterwards.
  /// Returning 0 outside `.task` — as this used to — put a "0" on screen during
  /// the fade of a countdown the user cancelled at fifteen, which is the same
  /// class of lie as an early Done claiming a completed break.
  var secondsRemaining: Int {
    clock.phase == .task
      ? max(0, Int(clock.remaining.rounded(.up)))
      : lastSecondsRemaining
  }

  /// The arc's value under Reduce Motion, as a pure function of the phase and
  /// the whole-second count, so the cancellation case is assertable without a
  /// screen.
  ///
  /// Quantized from the second count — the same value the numeral shows —
  /// rather than from `clock.progress`. That is not belt-and-braces: this view
  /// observes the clock, which republishes every 0.1s, so a body reading
  /// `progress` directly would sweep at 10 Hz and the `TimelineView` around it
  /// would change nothing. Deriving from the second count makes the step a
  /// property of the *value*, not of how often the view happens to be asked to
  /// draw, and guarantees the arc and the digit agree.
  ///
  /// `.cancelled` reads the frozen count and therefore stays where the
  /// countdown stopped — matching the non-Reduce-Motion path, which leaves the
  /// arc alone rather than animating it. An arc that completes on Skip says the
  /// break finished.
  static func steppedArc(
    phase: NotificationClock.Phase, secondsRemaining: Int, duration: TimeInterval
  ) -> CGFloat {
    switch phase {
    case .dismissing, .finished:
      return 1
    case .task, .cancelled:
      guard duration > 0 else { return 0 }
      return CGFloat(min(1, max(0, 1 - Double(secondsRemaining) / duration)))
    }
  }

  private var steppedArc: CGFloat {
    Self.steppedArc(
      phase: clock.phase, secondsRemaining: secondsRemaining, duration: timer.duration)
  }

  // MARK: - Arc animation

  /// One `withAnimation` per phase, never per frame.
  ///
  /// The early-Done snap is the reason this is expressible at all: interrupting
  /// a running animation with a *zero-duration* `withAnimation` sets the trim to
  /// a known value instantly. Animating to full instead would read as "the timer
  /// sped up", which says something false about what just happened.
  private func armArc() {
    guard !reduceMotion else { return }

    switch clock.phase {
    case .task:
      // From wherever the clock already is, not from empty. A view that appears
      // after the clock started — or reappears — would otherwise restart the arc
      // from zero and under-report the elapsed part of the break for the whole
      // remaining duration.
      arc = CGFloat(clock.progress)
      withAnimation(.linear(duration: clock.remaining)) { arc = 1 }
    case .dismissing, .finished:
      withAnimation(.linear(duration: 0)) { arc = 1 }
    case .cancelled:
      // No completion state, so nothing to say — leave the arc where the fade
      // catches it rather than filling it on the way out.
      break
    }
  }
}

/// The ring's tick marks: short radial strokes just outside the track.
struct TickMarks: Shape {
  let count: Int
  /// Radial length of each mark. A parameter rather than the hardcoded 6 it
  /// used to be, because the length has to move with the tick *count* — fewer,
  /// longer marks is what turns a fringe back into a dial.
  var length: CGFloat = 7

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let centre = CGPoint(x: rect.midX, y: rect.midY)
    let outer = min(rect.width, rect.height) / 2
    let inner = outer - length

    for index in 0..<max(1, count) {
      let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
      path.move(to: CGPoint(x: centre.x + cos(angle) * inner, y: centre.y + sin(angle) * inner))
      path.addLine(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
    }
    return path
  }
}

/// The generic "this closes in N" — deliberately quiet: no number, no label.
/// Nobody needs to watch a toast expire; they need to be able to tell that it
/// will.
///
/// Same `@ObservedObject` split as `CountdownRing`, and for the same reason.
struct DismissIndicatorView: View {

  @ObservedObject var clock: NotificationClock

  /// Same reason as `CountdownRing`: which indicator to draw depends on the
  /// phase, and the phase only moves for a view that observes the clock.
  let notification: RichNotification
  let reduceMotion: Bool

  private var indicator: DismissIndicator {
    notification.dismissIndicator(in: clock.phase)
  }

  @State private var drained: CGFloat = 0
  /// The phase's length, captured when the drain is armed. Reduce Motion needs
  /// it to quantize; nothing else reads it.
  @State private var phaseDuration: TimeInterval = 0

  var body: some View {
    Group {
      switch indicator {
      case .none:
        EmptyView()
      case .bar:
        bar
      case .hairlineRing:
        hairlineRing
      }
    }
    .onAppear { armDrain() }
    .onChange(of: clock.phase) { _, _ in armDrain() }
  }

  /// The fill and the shadow under it.
  ///
  /// The bar is the *only* countdown `.ambient` gets, and `.ambient` has no
  /// global scrim — so at `white.opacity(0.55)` with nothing behind it, this
  /// was light-on-nothing over a desktop the library does not own, i.e. exactly
  /// the failure 0.55 was derived to prevent. It is opaque now and carries the
  /// same opposing dark shadow every other light element does; the local scrim
  /// `RichNotificationView` puts behind the countdown block is the other half.
  private var bar: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.black.opacity(0.35))
        Capsule()
          .fill(Legibility.TextStyle.title.color)
          .frame(width: geometry.size.width * max(0, 1 - fraction))
      }
    }
    .frame(width: 180, height: 3)
    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
  }

  private var hairlineRing: some View {
    Circle()
      .trim(from: 0, to: max(0, 1 - fraction))
      .stroke(
        Legibility.TextStyle.title.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
      )
      .rotationEffect(.degrees(-90))
      .frame(width: 16, height: 16)
      .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
  }

  /// Under Reduce Motion the value steps once a second, quantized off whole
  /// seconds remaining for the same reason `CountdownRing.steppedArc` is —
  /// observing the clock redraws this body at 10 Hz whatever the cadence is
  /// meant to be. Otherwise Core Animation interpolates the single
  /// `withAnimation` armed in `armDrain`.
  private var fraction: CGFloat {
    guard reduceMotion else { return drained }
    guard clock.phase == .dismissing, phaseDuration > 0 else { return 0 }
    let secondsLeft = max(0, clock.remaining.rounded(.up))
    return CGFloat(min(1, max(0, 1 - secondsLeft / phaseDuration)))
  }

  private func armDrain() {
    guard clock.phase == .dismissing else { return }
    phaseDuration = clock.remaining.rounded(.up)
    guard !reduceMotion else { return }
    drained = 0
    withAnimation(.linear(duration: clock.remaining)) { drained = 1 }
  }
}
