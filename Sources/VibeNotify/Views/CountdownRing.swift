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
  static let diameter: CGFloat = 148
  static let lineWidth: CGFloat = 8
  static let tickCount: Int = 40

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
    .onAppear { armArc() }
    // The arc is re-armed on every phase change rather than on a timer: `.task`
    // → `.dismissing` is the only transition that changes what it should be
    // showing, and it is the transition that must *snap* rather than sweep.
    .onChange(of: clock.phase) { _, _ in armArc() }
  }

  // MARK: - Layers

  private var track: some View {
    Circle()
      .stroke(Color.white.opacity(0.18), lineWidth: Self.lineWidth)
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
    TickMarks(count: Self.tickCount)
      .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
      .padding(-10)
  }

  @ViewBuilder
  private var centre: some View {
    if let label = completion.label {
      VStack(spacing: 6) {
        Image(systemName: "checkmark")
          .font(.system(size: 34, weight: .semibold))
          .foregroundColor(stroke)
        Text(label)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(Legibility.TextStyle.message.color)
          .multilineTextAlignment(.center)
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
        VStack(spacing: 2) {
          Text("\(secondsRemaining)")
            .font(.system(size: 46, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(Legibility.TextStyle.title.color)
            .shadow(
              color: Legibility.TextStyle.title.shadowColor,
              radius: Legibility.TextStyle.title.shadowRadius,
              y: Legibility.TextStyle.title.shadowOffsetY)
          Text(timer.unitLabel)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Legibility.TextStyle.footnote.color)
            .shadow(
              color: Legibility.TextStyle.footnote.shadowColor,
              radius: Legibility.TextStyle.footnote.shadowRadius,
              y: Legibility.TextStyle.footnote.shadowOffsetY)
        }
      }
    }
  }

  // MARK: - Values

  private var secondsRemaining: Int {
    guard clock.phase == .task else { return 0 }
    return max(0, Int(clock.remaining.rounded(.up)))
  }

  /// The arc's value under Reduce Motion.
  ///
  /// Quantized from `secondsRemaining` — the same whole-second value the
  /// numeral shows — rather than from `clock.progress`. That is not
  /// belt-and-braces: this view observes the clock, which republishes every
  /// 0.1s, so a body reading `progress` directly would sweep at 10 Hz and the
  /// `TimelineView` around it would change nothing. Deriving from the second
  /// count makes the step a property of the *value*, not of how often the view
  /// happens to be asked to draw, and guarantees the arc and the digit agree.
  private var steppedArc: CGFloat {
    guard clock.phase == .task, timer.duration > 0 else { return 1 }
    return CGFloat(min(1, max(0, 1 - Double(secondsRemaining) / timer.duration)))
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
      arc = 0
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

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let centre = CGPoint(x: rect.midX, y: rect.midY)
    let outer = min(rect.width, rect.height) / 2
    let inner = outer - 6

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

  private var bar: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.18))
        Capsule()
          .fill(Color.white.opacity(0.55))
          .frame(width: geometry.size.width * max(0, 1 - fraction))
      }
    }
    .frame(width: 180, height: 3)
  }

  private var hairlineRing: some View {
    Circle()
      .trim(from: 0, to: max(0, 1 - fraction))
      .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      .rotationEffect(.degrees(-90))
      .frame(width: 16, height: 16)
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
