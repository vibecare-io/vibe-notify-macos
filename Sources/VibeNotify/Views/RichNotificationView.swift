import AppKit
import SVGView
import SwiftUI

/// The third renderer, added beside `StandardNotificationView` and
/// `SVGNotificationView`. Neither of those changes, and neither existing model
/// changes.
///
/// It draws, top to bottom: illustration, title, message, the task ring (or the
/// quiet dismiss indicator), the button row, the footnote. No card, no panel,
/// no border, no container shadow — there is no container. Content sits
/// directly on the scrim.
///
/// **The legibility invariant it serves:** text is never rendered over a
/// backdrop whose luminance this view does not control. `.interrupt` inherits a
/// global scrim from its blur window's 0.55 dim; `.ambient` draws a local
/// feathered scrim under its own text. Text colour then follows the scrim *we
/// drew*, never `@Environment(\.colorScheme)` — `useLightText = (colorScheme ==
/// .dark)` in `SVGNotificationView` is precisely the defect being fixed, and
/// nothing in this file reads the colour scheme.
public struct RichNotificationView: View {

  private let notification: RichNotification
  private let onDismiss: () -> Void
  private let effectiveDimOverride: Double?
  private let reduceMotionOverride: Bool?
  private let reduceTransparencyOverride: Bool?
  private let backdropStyle: BackdropStyle

  /// The reference only — **not** a subscription. `NotificationClock` is a
  /// Combine `ObservableObject`, so this hands back the same object for the
  /// life of the overlay and never invalidates this body. That is exactly what
  /// is wanted here: a per-tick invalidation of *this* view would re-parse
  /// `SVGView` ten times a second. Anything that draws the countdown is handed
  /// the reference and observes it itself (`CountdownRing`,
  /// `DismissIndicatorView`).
  @Environment(\.notificationClock) private var clock

  /// Entrance state. Skipped entirely under Reduce Motion, where content is
  /// placed at final scale rather than animated to it.
  @State private var entranceScale: CGFloat = 0.92
  @State private var entranceOpacity: Double = 0.0

  /// Set when Done is pressed while the task is still counting. The clock
  /// records *that* the task ended on its own terms (`didCompleteTask`) but not
  /// *how*, and the difference is the whole honesty rule — so the view, which
  /// is where the press happens, carries it.
  @State private var completedEarly: Bool = false

  /// Alpha-weighted mean luminance of the illustration's inked pixels, once
  /// `ArtworkLuminance` has had a chance to rasterise it. `nil` means "not yet,
  /// or nothing to measure", and resolves to the safe fallback treatment.
  ///
  /// Measured rather than declared, for the reason set out on
  /// `ArtworkLuminance`: the caller handing this view an illustration is
  /// routinely not the party that knows what is inside it.
  @State private var artworkLuminance: Double?

  /// - Parameters:
  ///   - effectiveDim: the dim of whatever backdrop is already in place, which
  ///     is what selects between the scrim strategies. Not a `Bool` over
  ///     "is blur on": a `.light` blur at the pinned 0.1 is blur-on and is not
  ///     a safe backdrop. Defaults to what the mode implies.
  ///   - reduceMotion/reduceTransparency: overrides for the live system
  ///     settings, so the demo harness and tests can drive both branches.
  ///   - backdropStyle: what the *backdrop window* is painting, so this view
  ///     does not draw over it. Must match the `Configuration` the same alert
  ///     was shown with; `VibeNotify.showRich` reads it off that configuration
  ///     precisely so the two cannot disagree.
  public init(
    notification: RichNotification,
    effectiveDim: Double? = nil,
    reduceMotion: Bool? = nil,
    reduceTransparency: Bool? = nil,
    backdropStyle: BackdropStyle = .blurredDesktop,
    onDismiss: @escaping () -> Void
  ) {
    self.notification = notification
    self.effectiveDimOverride = effectiveDim
    self.reduceMotionOverride = reduceMotion
    self.reduceTransparencyOverride = reduceTransparency
    self.backdropStyle = backdropStyle
    self.onDismiss = onDismiss
  }

  // MARK: - Resolved inputs

  private var reducesMotion: Bool {
    reduceMotionOverride ?? Legibility.Accessibility.reduceMotion
  }

  private var reducesTransparency: Bool {
    reduceTransparencyOverride ?? Legibility.Accessibility.reduceTransparency
  }

  private var effectiveDim: Double {
    if let effectiveDimOverride { return effectiveDimOverride }
    return Legibility.backdrop(
      for: notification.mode, reduceTransparency: reducesTransparency, style: backdropStyle)?
      .effectiveDim ?? 0
  }

  /// Internal, not private, and read by `LegibilityTests` — a wiring assertion
  /// in the same spirit as `NotificationClock.isRunning`. `Legibility` can be
  /// perfectly correct while this view ignores it, and a suite that only tests
  /// the pure functions cannot tell the difference.
  var scrimStrategy: ScrimStrategy {
    Legibility.scrimStrategy(
      effectiveDim: effectiveDim, reduceTransparency: reducesTransparency)
  }

  /// The colour scheme is passed to make the call site honest and is discarded
  /// inside: both scrims are dark, so both modes render light text in both
  /// system themes.
  var styles:
    (title: Legibility.TextStyle, message: Legibility.TextStyle, footnote: Legibility.TextStyle)
  {
    Legibility.textStyles(colorScheme: .dark)
  }

  /// The task ring's timer, or `nil` if no ring is drawn. Internal and read by
  /// the body, so it cannot drift from what is on screen.
  var resolvedTaskTimer: TaskTimer? { notification.effectiveTaskTimer }

  /// Whether the dismiss indicator child is drawn at all. **Independent of
  /// `resolvedTaskTimer`** — the two are sequential phases, not alternatives.
  /// Whether it draws anything *right now* is the pure function's call, not
  /// this one's.
  var drawsDismissIndicator: Bool { notification.autoDismiss != nil }

  /// Which treatment the illustration gets, resolved the same way the scrim
  /// strategy is: a pure function in `Legibility`, consumed here, never a
  /// second opinion computed in a view body.
  ///
  /// Internal so a test can read the resolved value without a screen — the same
  /// wiring assertion `scrimStrategy` exists for.
  var illustrationTreatment: IllustrationTreatment {
    switch notification.artworkTone {
    case .dark: return .halo
    case .light: return .shadow
    case .automatic: return Legibility.illustrationTreatment(artworkLuminance: artworkLuminance)
    }
  }

  /// The type and spacing scale for this alert.
  ///
  /// Mode-dependent, and that is not the `colorScheme` mistake wearing a new
  /// hat: `mode` describes the *surface this library is drawing* — a full
  /// screen it owns versus a 380-point toast in a corner — not the OS's opinion
  /// about anything. A 26-point title and a 148-point ring are right on the
  /// first and absurd on the second, and one scale for both is why the
  /// interrupt read as under-set and the toast as shouted.
  private var metrics: RichMetrics { RichMetrics.forMode(notification.mode) }

  // MARK: - Body

  public var body: some View {
    // The `GeometryReader` is doing two jobs, both load-bearing.
    //
    // **One: it stops this view resizing the window it is hosted in.**
    // `OverlayWindowManager.createWindow` builds a borderless `NSWindow` at a
    // caller-chosen frame and installs an `NSHostingView` as its `contentView`.
    // That hosting view publishes an `intrinsicContentSize` derived from the
    // SwiftUI content, and AppKit resolves the resulting constraint by resizing
    // *the window* — one run-loop pass after `show()` returns, which is why the
    // frame is still correct when `show()` hands back. Measured through the
    // public API before this existed:
    //
    //   .ambient, long message       (1328, 20, 380, 210) -> (1328, -2059, 380, 2289)
    //   .ambient, 600x500 image      (1328, 20, 380, 210) -> (1328,  -358, 656,  588)
    //   .interrupt, long message     the screen, 1728x1117 -> (0, -27049, 1728, 28166)
    //
    // Note the third row: the intuitive reading — "only fixed-size ambient
    // windows are affected, interrupt asks for the whole screen anyway" — is
    // wrong. Interrupt blew up by a factor of twenty-five, invisibly, because
    // the window is transparent; it just centred the content thousands of
    // points off-screen. Any fix scoped to `.ambient` would have left that in.
    //
    // A `GeometryReader` is the lever because it is greedy and incurious: it
    // accepts whatever size it is proposed and never reports its children's
    // requirements upward, so the hosting view stops having an opinion about
    // how big the window should be.
    //
    // **Two: it hands the content the size it must fit into**, which is what
    // lets an oversized illustration scale down instead of evicting everything
    // else. See `Illustration.fitted(in:)`.
    GeometryReader { proxy in
      body(in: proxy.size)
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
    // Content that still does not fit is cut off rather than granted a bigger
    // window. With the illustration bounded above, what gets cut is the tail of
    // a long message — not, as it once was, the entire alert.
    .clipped()
    .onAppear(perform: enter)
  }

  private func body(in available: CGSize) -> some View {
    ZStack {
      // `.interrupt` under Reduce Transparency: the backdrop window's blur is
      // dropped, and this is the opaque black that replaces it. Drawn in the
      // content window because `Configuration.screenDim` clamps at 0.95 —
      // "solid" has to be genuinely solid, and here it is.
      if drawsOpaqueFallback {
        Color.black.bleedingToScreenEdges(bleeds)
      }

      // The full-bleed dismissal target, *below* the content so the buttons
      // take their taps first. `.interrupt` needs its own because
      // `dismissOnScreenTap` installs its handler on the blur window, which is
      // levelled below the content window — with a full-screen content window
      // the blur window is completely occluded and receives nothing, so
      // click-anywhere silently does not work. That is a defect to fix, not
      // inherit. In `.ambient` the window is sized to its content, so the same
      // target is simply "a click on the alert itself".
      // Suppressed outright when a web panel is on screen. Everywhere else
      // "click anywhere to skip" is a courtesy, because everywhere else there
      // is nothing on the surface to click *at*. With a game or a video in the
      // panel the user is aiming at things for a living, and one shot landing
      // in the margin would cancel the break mid-way — losing whatever they
      // were doing and reporting nothing about why. The buttons and ESC remain,
      // and both say what they do.
      if notification.effectiveWebPanel == nil {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { dismissByCancelling() }
          .bleedingToScreenEdges(bleeds)
      }

      content(in: available)
        .scaleEffect(entranceScale)
        .opacity(entranceOpacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Whether this view draws its own full-bleed opaque black.
  ///
  /// The third clause is the one that is easy to leave out and expensive to
  /// leave out. Reduce Transparency's black exists because the *desktop*
  /// backdrop reaches a safe luminance through a translucent dim and a blur,
  /// neither of which that setting tolerates. A painted backdrop reaches it
  /// through neither: the backdrop window is genuinely opaque and every colour
  /// in it is capped at `Legibility.maxSafeLuminance`. Drawing black over that
  /// would not make anything more legible — the surface was already compliant —
  /// it would just silently discard the backdrop the user chose, on the one
  /// configuration where nobody testing the default would ever see it happen.
  ///
  /// Internal rather than private so a test can read the decision without a
  /// screen, the same wiring assertion `scrimStrategy` exists for.
  var drawsOpaqueFallback: Bool {
    notification.mode == .interrupt && reducesTransparency && backdropStyle.fill == nil
  }

  /// Whether this alert's window *is* the screen.
  ///
  /// `.interrupt` is presented full-screen with `width`/`height` left `nil`, so
  /// bleeding past the safe area is exactly right — the scrim must reach the
  /// menu bar and the notch, not stop short of them. `.ambient` is a fixed-size
  /// window the caller sized, where there is no screen edge to reach and
  /// nothing to gain.
  private var bleeds: Bool { notification.mode == .interrupt }

  /// The stack, with **grouped** rather than uniform vertical rhythm.
  ///
  /// `VStack(spacing: 0)` plus an explicit gap *above* each element, rather
  /// than one shared spacing, because the gaps are not all the same
  /// relationship — see `RichMetrics`. Each gap is applied only when something
  /// actually precedes the element, so an alert with no illustration does not
  /// carry an illustration-sized hole where one would have been; that is what
  /// keeps a 380×210 `.ambient` toast from spending a fifth of its height on
  /// padding for content it does not have.
  @ViewBuilder
  private func content(in available: CGSize) -> some View {
    if let panel = notification.effectiveWebPanel {
      webContent(panel, in: available)
    } else {
      stackContent(in: available)
    }
  }

  private func stackContent(in available: CGSize) -> some View {
    let hasIllustration = notification.effectiveIllustration != nil
    let hasText = notification.title != nil || notification.message != nil
    // `clock == nil` means no countdown is drawn at all, so its gap must not be
    // reserved either. A `.padding` on an absent child is still a real gap.
    let hasCountdown = clock != nil
    let aboveCountdown = hasIllustration || hasText
    let aboveButtons = aboveCountdown || hasCountdown
    let aboveFootnote = aboveButtons || !notification.buttons.isEmpty

    return VStack(spacing: 0) {
      illustration(in: available)

      // Title and message share one scrim: they are one text block, and two
      // adjacent gradients would meet in a seam that reads as an edge.
      if hasText {
        VStack(spacing: metrics.titleToMessage) {
          if let title = notification.title {
            styled(
              Text(title).font(.system(size: metrics.titleSize, weight: .semibold)),
              as: styles.title)
          }
          if let message = notification.message {
            // Refuses vertical truncation, so a long message wraps in full
            // instead of being clipped to one line by a tight parent.
            //
            // Safe *because* of the `GeometryReader` in `body`, and not before
            // it: this modifier makes height a required function of width, and
            // that requirement used to propagate out and resize the window.
            styled(Text(message).font(.system(size: metrics.messageSize)), as: styles.message)
              .fixedSize(horizontal: false, vertical: true)
              // Long-form text set solid reads as a wall. One extra half-line of
              // leading is the cheapest thing that stops it, and it only touches
              // the slot that ever wraps.
              .lineSpacing(3)
          }
        }
        .frame(maxWidth: metrics.textWidth)
        .scrimmed(scrimStrategy)
        .padding(.top, hasIllustration ? metrics.illustrationToText : 0)
      }

      countdown
        .padding(.top, (hasCountdown && aboveCountdown) ? metrics.textToCountdown : 0)

      if !notification.buttons.isEmpty {
        HStack(spacing: 14) {
          ForEach(notification.buttons) { button in
            SwiftUI.Button(action: { press(button) }) {
              Text(button.title)
            }
            .buttonStyle(RichButtonStyle(role: button.style))
          }
        }
        .padding(.top, aboveButtons ? metrics.countdownToButtons : 0)
      }

      if let footnote = notification.footnote {
        styled(Text(footnote).font(.system(size: metrics.footnoteSize)), as: styles.footnote)
          // Its own scrim rather than a share of the block's: the footnote sits
          // below the buttons, and one rect spanning both would put a gradient
          // behind buttons that already carry their own contrast.
          .scrimmed(scrimStrategy, feather: 28)
          .padding(.top, aboveFootnote ? metrics.buttonsToFootnote : 0)
      }
    }
    .padding(metrics.contentPadding)
    // Optical centring — see `RichMetrics.opticalRise`. An `.offset` rather
    // than asymmetric padding on purpose: it moves what is drawn without
    // changing what is measured, so nothing here can propagate a new size
    // requirement back out through the `GeometryReader`.
    .offset(y: -available.height * metrics.opticalRise)
  }

  // MARK: - Web layout

  /// The two-column surface: a live page in one column, this renderer's usual
  /// chrome in the other.
  ///
  /// Sized off `available` and inset from it, rather than bleeding like the
  /// stack layout does. The stack bleeds because it is text floating on a
  /// scrim and the scrim must reach the notch; this has a hard-edged, opaque
  /// panel in it, and a hard edge that meets the screen edge stops reading as
  /// an overlay at all.
  private func webContent(_ panel: WebPanel, in available: CGSize) -> some View {
    let surface = CGSize(
      width: available.width * RichMetrics.webSurfaceWidthFraction,
      height: available.height * RichMetrics.webSurfaceHeightFraction)

    // The rail's floor wins over the panel's requested fraction. `WebPanel`
    // clamps `widthFraction` against constants, but the constants cannot know
    // the screen: 0.85 of a 5K display leaves a generous rail, and 0.85 of a
    // 1280-point laptop leaves 158 points — not enough for the ring and the
    // button row the user needs in order to end the break.
    let railWidth = max(
      RichMetrics.webRailMinimumWidth,
      surface.width * (1 - panel.widthFraction) - RichMetrics.webColumnGap)
    let webWidth = max(0, surface.width - railWidth - RichMetrics.webColumnGap)

    return HStack(spacing: RichMetrics.webColumnGap) {
      if panel.placement == .trailing {
        webRail(width: railWidth)
      }
      WebPanelView(panel: panel)
        .frame(width: webWidth, height: surface.height)
        // Behind the page, not over it: a page that has not painted yet would
        // otherwise show system white through the rounded corners.
        .background(Color.black.opacity(0.94))
        .clipShape(
          RoundedRectangle(cornerRadius: RichMetrics.webPanelCornerRadius, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: RichMetrics.webPanelCornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
      if panel.placement == .leading {
        webRail(width: railWidth)
      }
    }
    .frame(width: surface.width, height: surface.height)
  }

  /// The text column beside the panel.
  ///
  /// **The countdown leads here**, where in the stack layout it follows the
  /// text. The rail is read top-down against a panel that has already taken
  /// the eye, so its order has to be *how long is left → what to do → how to
  /// leave*; a ring discovered below the message is a ring discovered after
  /// the user has decided whether to bother.
  ///
  /// Everything in it — `styled`, `scrimStrategy`, `press`, the button style —
  /// is the same machinery the stack layout uses. That is the point of this
  /// being a second layout rather than a second renderer.
  private func webRail(width: CGFloat) -> some View {
    let hasText = notification.title != nil || notification.message != nil

    return VStack(alignment: .leading, spacing: 0) {
      if clock != nil {
        countdown
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.top, RichMetrics.webRingTopInset)
      }

      // Paired with the `Spacer` at the foot: the ring stays pinned to the top
      // corner, and everything below it centres in what is left rather than
      // hanging from it.
      Spacer(minLength: clock != nil ? metrics.textToCountdown : 0)

      if hasText {
        VStack(alignment: .leading, spacing: metrics.titleToMessage) {
          if let title = notification.title {
            styled(
              Text(title).font(.system(size: metrics.titleSize, weight: .semibold)),
              as: styles.title)
          }
          if let message = notification.message {
            styled(Text(message).font(.system(size: metrics.messageSize)), as: styles.message)
              .fixedSize(horizontal: false, vertical: true)
              .lineSpacing(3)
          }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrimmed(scrimStrategy)
      }

      if !notification.buttons.isEmpty {
        HStack(spacing: 14) {
          ForEach(notification.buttons) { button in
            SwiftUI.Button(action: { press(button) }) {
              Text(button.title)
            }
            .buttonStyle(RichButtonStyle(role: button.style))
          }
        }
        .padding(.top, hasText ? metrics.countdownToButtons : 0)
      }

      if let footnote = notification.footnote {
        styled(Text(footnote).font(.system(size: metrics.footnoteSize)), as: styles.footnote)
          .multilineTextAlignment(.leading)
          .scrimmed(scrimStrategy, feather: 28)
          .padding(.top, notification.buttons.isEmpty ? 0 : metrics.buttonsToFootnote)
      }

      // Balances the `Spacer` under the ring, centring text-through-footnote
      // in whatever the ring left behind.
      //
      // The first version pinned the buttons to the *foot* of the rail
      // instead, reasoning that the way out of a break belongs somewhere
      // predictable. On screen that put a title and two lines of message up at
      // the top, the buttons a full screen-height below them, and six hundred
      // points of nothing in between — three fragments on a column rather than
      // one thing to read. Proximity is what groups them, and there is no
      // grouping left at that distance.
      Spacer(minLength: 0)
    }
    .frame(width: width, alignment: .leading)
  }

  /// The **only** place this renderer sets a text colour or a text shadow.
  ///
  /// Funnelling all of it through one function is not tidiness. Colour and
  /// shadow chosen per call site is exactly the shape the original bug had —
  /// four independent `.foregroundColor`/`.shadow` pairs, one of which was
  /// `.clear` and another a white glow under white text — and it is
  /// unassertable when it is spread out. With one funnel, `LegibilityTests`
  /// can render this view and check the pixels that come out, and any attempt
  /// to reintroduce a per-site colour has to visibly route around this.
  private func styled(_ text: Text, as style: Legibility.TextStyle) -> some View {
    text
      .foregroundColor(style.color)
      .shadow(color: style.shadowColor, radius: style.shadowRadius, y: style.shadowOffsetY)
      .multilineTextAlignment(.center)
  }

  // MARK: - Illustration

  @ViewBuilder
  private func illustration(in available: CGSize) -> some View {
    if let illustration = notification.effectiveIllustration {
      // Bounded against the space actually available. Unbounded, a large
      // caller-supplied image pushed every other element outside the clip and
      // the alert rendered completely blank.
      let fitted = illustration.fitted(in: available)
      treated(illustrationBody(fitted))
        // Measured off the *unfitted* illustration: how light or dark the ink
        // is does not change with the frame it is drawn into, and measuring the
        // fitted one would re-measure on every window resize.
        .onAppear { measureArtwork(illustration) }
    }
  }

  /// Applies the treatment that **opposes the artwork**, which is the rule the
  /// text styles have always followed and the illustration never did.
  ///
  /// The old code gave every illustration `black.opacity(0.5)` and justified it
  /// in a comment as "a dark drop shadow, never a glow" — correct reasoning
  /// about the *old* SVG renderer's bug (a coloured glow keyed off dark mode,
  /// which erased light artwork against light backdrops) applied to the wrong
  /// variable. The thing a glow must not be keyed off is the **colour scheme**.
  /// Keying it off the artwork's own luminance is the opposite of that mistake:
  /// it is the same rule as "light text takes a dark shadow", run in the
  /// direction the input demands.
  ///
  /// Both halves of `.halo` are needed and they do different jobs. The bloom is
  /// centred on the *frame*, so it puts light behind the mass of the artwork
  /// but has already fallen away at the extremities of anything wide. The glow
  /// follows the *drawn geometry*, so it puts light exactly along the ink. With
  /// only the bloom the outer corners of the eye still merged into a black
  /// desktop; with only the glow the illustration read as a sticker with a rim.
  @ViewBuilder
  private func treated(_ body: some View) -> some View {
    switch illustrationTreatment {
    case .halo:
      body
        .shadow(color: IllustrationHalo.glowColor, radius: IllustrationHalo.glowRadius)
        .background {
          IllustrationHalo().padding(-IllustrationHalo.feather)
        }
    case .shadow:
      body
        .shadow(color: .black.opacity(0.5), radius: 15, y: 2)
    }
  }

  /// Rasterises the illustration once and records its ink luminance.
  ///
  /// Deferred to the next run-loop turn rather than run inline in `onAppear`:
  /// `ImageRenderer` starts a render pass of its own, and starting one from
  /// inside the pass that is currently drawing this view is asking for trouble
  /// in a way that is very hard to see when it goes wrong. One turn later the
  /// entrance animation has not finished, so nothing is ever seen with the
  /// fallback treatment.
  ///
  /// Skipped entirely when the caller declared the tone, which is the whole
  /// point of letting them: an `.svg` measurement costs a second parse of the
  /// file, and `eye.svg` is 98 KB.
  private func measureArtwork(_ illustration: RichNotification.Illustration) {
    guard notification.artworkTone == .automatic, artworkLuminance == nil else { return }
    DispatchQueue.main.async {
      artworkLuminance = ArtworkLuminance.measure(
        illustrationBody(illustration), naturalSize: illustration.pixelSize)
    }
  }

  @ViewBuilder
  private func illustrationBody(_ illustration: RichNotification.Illustration) -> some View {
    switch illustration {
    case .svg(let source, let size):
      SVGView(contentsOf: source.url)
        .frame(width: size.width, height: size.height)
    case .image(let image, let size):
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size.width, height: size.height)
    case .symbol(let name, let pointSize, let color):
      Image(systemName: name)
        .font(.system(size: pointSize))
        // Defaults to the title colour, not `.primary`: this is the fallback an
        // unconfigured schedule alert gets, and it must be legible over the
        // scrim like everything else.
        .foregroundColor(color ?? styles.title.color)
    }
  }

  // MARK: - Countdown

  /// Both branches hand the clock *reference* to a child that holds it as
  /// `@ObservedObject`. That indirection is the documented pattern and the
  /// reason this view can read `@Environment(\.notificationClock)` without
  /// being invalidated on every tick.
  @ViewBuilder
  private var countdown: some View {
    if let clock {
      VStack(spacing: 14) {
        // `resolvedTaskTimer` reads `effectiveTaskTimer`, not `taskTimer`:
        // `.ambient` gets the dismiss indicator only, and that rule is enforced
        // on the model so the clock and the renderer cannot disagree about
        // whether a task is running.
        if let timer = resolvedTaskTimer {
          CountdownRing(
            clock: clock,
            notification: notification,
            timer: timer,
            completedEarly: completedEarly,
            reduceMotion: reducesMotion)
        }

        // Deliberately *not* an `else`. A task timer and an auto-dismiss are
        // sequential phases, not alternatives: the task runs first and alone,
        // and the dismiss indicator has to be reachable once it hands over —
        // "then the dismiss phase runs, its indicator visible if one was
        // configured". Choosing the child structurally made that unreachable
        // for the flagship 20s-task-plus-5s-dismiss case, and turned
        // `dismissIndicator(in:)`'s `.dismissing` branch into dead code that a
        // green test still claimed to cover. Suppression during `.task` is the
        // pure function's job; this view draws `EmptyView` for `.none`.
        if drawsDismissIndicator {
          DismissIndicatorView(
            clock: clock, notification: notification, reduceMotion: reducesMotion)
        }
      }
      // Without this the countdown is light-on-nothing in `.ambient`. The
      // ring's numerals carry opposing shadows, but a shadow is a second-order
      // safety net and was never the contrast mechanism — and the dismiss bar
      // had neither. Scrimmed like the text block, which is what the invariant
      // requires of anything this library draws light.
      .scrimmed(scrimStrategy, feather: 32)
    }
  }

  // MARK: - Entrance

  private func enter() {
    guard !reducesMotion else {
      // Content at final scale, no spring. The countdown is the deliberate
      // exception to Reduce Motion and keeps running — it is information being
      // read, not decoration — which is why this only governs the entrance.
      entranceScale = 1.0
      entranceOpacity = 1.0
      return
    }
    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
      entranceScale = 1.0
      entranceOpacity = 1.0
    }
  }

  // MARK: - Dismissal

  /// ESC is wired by the window; this is the click-away half. Cancellation
  /// produces no completion state and no acknowledgement.
  private func dismissByCancelling() {
    clock?.cancel()
    onDismiss()
  }

  /// The caller's closure supplies the *meaning*; the library guarantees what
  /// happens to the clock and the window around it. Every route ends with the
  /// window down — one of them via the clock, which is the only way an
  /// acknowledgement can be on screen long enough to read. See
  /// `RichNotification.outcome(for:taskPhaseActive:hasClock:)`.
  private func press(_ button: StandardNotification.Button) {
    let outcome = RichNotification.outcome(
      for: button.style,
      taskPhaseActive: clock?.phase == .task,
      hasClock: clock != nil)

    switch outcome {
    case .completeTaskThenHold:
      completedEarly = true
      clock?.completeTask()
      button.action()
    case .cancelAndDismiss:
      clock?.cancel()
      button.action()
      onDismiss()
    case .dismiss:
      button.action()
      onDismiss()
    }
  }
}

// MARK: - Window geometry

extension View {
  /// `ignoresSafeArea()`, but only where a safe area is something this alert has
  /// any business crossing.
  ///
  /// `.interrupt` owns the whole screen and its backdrop must reach the menu bar
  /// and the notch rather than stopping short of them. `.ambient` is a
  /// fixed-size window the caller positioned, where there is no screen edge to
  /// reach.
  ///
  /// Recorded because the first diagnosis of the window-resizing defect blamed
  /// this modifier: it is **not** the cause, and removing it outright changed
  /// nothing (verified — the ambient window still settled at
  /// `(1328, -2059, 380, 2289)` with both calls deleted). The `GeometryReader`
  /// in `body` is the actual fix. This stays conditional on its own smaller
  /// merits: unconditionally it was stating an intent true for only one mode.
  @ViewBuilder
  func bleedingToScreenEdges(_ bleeds: Bool) -> some View {
    if bleeds {
      ignoresSafeArea()
    } else {
      self
    }
  }
}
