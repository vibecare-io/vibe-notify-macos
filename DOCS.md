# VibeNotify Documentation

A comprehensive guide to using VibeNotify - a lightweight, customizable notification overlay library for macOS built with SwiftUI.

## Table of Contents

- [Getting Started](#getting-started)
- [Builder API](#builder-api)
- [Rich Notifications](#rich-notifications)
  - [Web panel](#web-panel)
- [Alert Modes and Window Configuration](#alert-modes-and-window-configuration)
- [Countdowns](#countdowns)
- [NotificationClock](#notificationclock)
- [Legibility and Backdrops](#legibility-and-backdrops)
- [Which Renderer Runs](#which-renderer-runs)
- [Customization Options](#customization-options)
- [SVG Support](#svg-support)
- [Advanced Features](#advanced-features)
- [API Reference](#api-reference)
- [Deprecations](#deprecations)
- [Examples](#examples)

---

## Getting Started

### Installation

Add VibeNotify to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/vibecare-io/vibe-notify-macos.git", branch: "main")
]
```

### Quick Start

```swift
import VibeNotify

// Simple success notification
VibeNotify.shared.success(message: "Task completed!")

// Simple error notification
VibeNotify.shared.error(message: "Something went wrong")
```

---

## Builder API

The Builder API provides a declarative, chainable interface for creating notifications. This is the **recommended approach** for most use cases.

### Basic Builder Pattern

```swift
VibeNotify.builder()
    .title("Notification Title")
    .message("Your notification message")
    .icon(.success)
    .show()
```

### Builder with Buttons

```swift
VibeNotify.builder()
    .title("Confirm Action")
    .message("Do you want to proceed?")
    .icon(.warning)
    .button(
        StandardNotification.Button(
            title: "Confirm",
            style: .primary
        ) {
            print("Confirmed!")
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            print("Cancelled")
        }
    )
    .show()
```

### Builder with Auto-Dismiss

```swift
VibeNotify.builder()
    .title("Success")
    .message("Operation completed")
    .icon(.success)
    .autoDismiss(
        after: 3.0,
        showProgress: true
    )
    .show()
```

> `showProgress` is a deprecated spelling of `DismissIndicator` — `true` means
> `.bar`, `false` means `.none`. It remains the builder's only auto-dismiss
> entry point, so the examples throughout this document still use it. See
> [Deprecations](#deprecations).

### Builder with Positioning

```swift
VibeNotify.builder()
    .title("Positioned Notification")
    .message("Located in the top-right corner")
    .icon(.info)
    .position(.topRight)
    .width(400)
    .height(200)
    .show()
```

### Builder with Transparency

```swift
VibeNotify.builder()
    .title("Transparent Effect")
    .message("Beautiful blur effect")
    .icon(.success)
    .transparent(
        true,
        material: .hudWindow
    )
    .position(.center)
    .width(450)
    .height(200)
    .show()
```

### Builder with Screen Blur

```swift
// Using intensity-based blur (recommended)
VibeNotify.builder()
    .title("Focus Mode")
    .message("Screen is blurred for focus")
    .icon(.info)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(true, intensity: .medium)
    .dismissOnScreenTap(true)
    .show()

// Using custom blur radius
VibeNotify.builder()
    .title("Custom Blur")
    .message("Fine-tuned blur intensity")
    .screenBlur(true, intensity: .custom(radius: 15))
    .show()

// Legacy material-based blur (still supported)
VibeNotify.builder()
    .title("Legacy Blur")
    .message("Using NSVisualEffectView materials")
    .screenBlur(true, material: .underWindowBackground)
    .show()
```

### Builder with Moveable Window

```swift
VibeNotify.builder()
    .title("Drag Me!")
    .message("Click and drag to reposition")
    .icon(.info)
    .position(.center)
    .width(400)
    .height(200)
    .moveable(true)
    .show()
```

### Builder with SVG

```swift
VibeNotify.builder()
    .svg(
        "/path/to/icon.svg",
        size: CGSize(width: 200, height: 200),
        interactive: true
    )
    .title("SVG Notification")
    .message("Rendered with SVGView")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 350, height: 400)))
    .show()
```

### Complete Builder Example

```swift
VibeNotify.builder()
    .title("Fully Customized")
    .message("All options enabled!")
    .icon(.warning)
    .position(.topRight)
    .width(500)
    .height(250)
    .moveable(true)
    .alwaysOnTop(true)
    .transparent(
        true,
        material: .hudWindow
    )
    .windowOpacity(0.95)
    .autoDismiss(
        after: 8.0,
        showProgress: true
    )
    .button(
        StandardNotification.Button(
            title: "OK",
            style: .primary
        ) {
            print("OK pressed")
        }
    )
    .show()
```

---

## Rich Notifications

`RichNotification` is a third content model, added beside `StandardNotification`
and `SVGNotification`. Neither of those changed, and neither is going away.

It exists because an illustration and buttons cannot coexist in either older
model: `SVGNotification` has no `buttons` property at all, and
`StandardNotificationView` maps `.svg` and `.url` icons to `EmptyView()` and
pins bitmaps to a hardcoded 48×48. Retrofitting either one means keeping the old
behaviour behind a flag, and a renderer with a "behave like 0.0.5" flag is two
renderers wearing one name.

### The model

```swift
public init(
    illustration: Illustration? = nil,
    artworkTone: ArtworkTone = .automatic,
    webPanel: WebPanel? = nil,          // see § Web panel; replaces the illustration
    title: String? = nil,
    message: String? = nil,
    footnote: String? = nil,
    buttons: [StandardNotification.Button] = [],
    taskTimer: TaskTimer? = nil,
    autoDismiss: StandardNotification.AutoDismiss? = nil,
    mode: AlertMode = .ambient,
    acknowledgementLabel: String = "Got it"
)
```

The renderer draws, top to bottom: illustration, title, message, the task ring
(or the quiet dismiss indicator), the button row, the footnote. There is no
card, no panel, no border and no container shadow — content sits directly on the
scrim.

- **`footnote`** is a fifth text slot below the buttons ("Press ESC or click
  anywhere to skip"). Separate from `message` because it styles differently and
  because in `.ambient` it is usually absent.
- **`buttons`** reuses `StandardNotification.Button` verbatim rather than
  forking a parallel type.
- **`acknowledgementLabel`** is what the ring's centre says when Done is pressed
  *early*. Deliberately not the timer's `completionLabel` — see
  [Completion honesty](#completion-honesty).

### Showing one

```swift
@discardableResult
public func showRich(
    _ notification: RichNotification,
    configuration: OverlayWindowManager.Configuration,
    reduceMotion: Bool? = nil,
    reduceTransparency: Bool? = nil,
    onEnd: ((NotificationClock.Phase?) -> Void)? = nil
) -> UUID
```

`configuration` should come from `Configuration.interrupt(…)` or
`.ambient(…)`, matching `notification.mode`. Passing a configuration for one
mode with a notification set to the other produces a backdrop that disagrees
with what the renderer assumes is behind it.

`reduceMotion` / `reduceTransparency` override the live `NSWorkspace`
accessibility settings; `nil` reads the system value.

`onEnd` fires exactly once, however the overlay closes — a button, ESC, a click
away, `dismiss(id:)`, or the countdown reaching its own end. That last case has
no other signal: a clock that reaches its deadline tears the window down through
`OverlayWindowManager.clockDidEnd`, which never runs the `onDismiss` closure
baked into the hosted view. The `NotificationClock.Phase` handed back is the
phase at the moment of closing (`.finished` for a countdown that ran out,
`.cancelled` for everything that ended it early), and `nil` when there was no
clock at all.

### Illustration

```swift
public enum Illustration {
    case svg(SVGSource, size: CGSize)
    case image(NSImage, size: CGSize)
    case symbol(String, pointSize: CGFloat, color: Color?)
}
```

**Size lives inside each case, not as a sibling property.** An SF Symbol is
sized by a point size and a bitmap or SVG by a `CGSize`; one shared `CGSize`
would force a caller to encode a font size as a square rectangle. `pixelSize`
reads a symbol's point size back as a square, for layout and for asserting sizes
without a screen.

Each case has a named consumer. `.image` is for an already-fetched `NSImage` —
a host that fetches through an authenticated proxy cannot hand this library a
URL, because the re-fetch would go out unauthenticated and fail. `.symbol` is
the no-artwork fallback. `.svg` is everything else.

#### `fitted(in:)`

```swift
public func fitted(in available: CGSize) -> Illustration
```

Returns this illustration scaled down, aspect ratio preserved, so it cannot
evict the rest of the alert from a window it does not fit in. The limits are
half the available height and the available width less 56 points of content
padding (both internal constants, not API).

**This exists because clipping alone produced a blank alert.** A 600×500
`NSImage` in a 380×210 `.ambient` window pushed the title, the message and
everything below them outside the clip entirely — the measured result was *zero*
inked pixels, not a truncated alert but an empty one.

It only ever scales **down**. A small illustration in a large window is exactly
what the caller asked for; growing it would silently override a deliberate
choice, and a 40pt symbol stays 40pt on a 5K display.

#### `artworkTone`

`.automatic` (the default) means *measure it*: the renderer rasterises the
illustration once and takes the alpha-weighted mean luminance of its inked
pixels. Dark artwork gets a light halo, light artwork gets a dark drop shadow —
the same opposition rule the text styles follow. `.dark` and `.light` skip the
raster for a caller who genuinely already knows.

The enum is named for the *artwork*, not for the treatment, on purpose: a caller
can answer "my icon is white line art", but asking them to answer "my icon wants
a dark drop shadow rather than a light bloom" is asking them to make this
library's rendering decision for it.

### Web panel

A live page in one column and the usual chrome — title, message, ring, buttons,
footnote — in the other. A property of `RichNotification`, not a fourth
renderer, so every legibility rule and button outcome above applies unchanged.

```swift
public struct WebPanel: Sendable, Equatable {
    public enum Placement: Sendable { case leading, trailing }
    public enum Presentation: Sendable { case direct, player }

    public let url: URL               // rewritten for YouTube — see below
    public let placement: Placement   // which side the page takes; default .leading
    public let widthFraction: CGFloat // clamped 0.3...0.85, default 0.64
    public let allowsAutoplay: Bool   // default false
    public let startsMuted: Bool      // default true
    public let loops: Bool            // default false
    public var loadURL: URL           // url + the playback options
}
```

```swift
RichNotification(
    webPanel: WebPanel(url: shortURL, widthFraction: 0.36, allowsAutoplay: true, loops: true),
    title: "Rest your eyes",
    taskTimer: TaskTimer(duration: 60, unitLabel: "seconds", completionLabel: "Eyes rested"),
    mode: .interrupt)
```

**Ignored in `.ambient`** (`effectiveWebPanel`), for the reason a task timer is:
a 380×210 toast split into two columns is two columns too narrow to be either,
and a `WKWebView` is expensive to instantiate for something nobody can read. The
builder therefore upgrades to `.interrupt` on a web panel exactly as it does on
a task timer.

**It replaces the illustration** (`effectiveIllustration` returns nil). The
panel *is* the picture; two focal points is the composition problem
`RichMetrics` exists to avoid. The caller's stored `illustration` is left
untouched — this reinterprets, it does not rewrite.

#### Two interaction changes, both deliberate

| Behaviour | Why |
|---|---|
| Click-anywhere-to-dismiss is **suppressed** | Everywhere else it is a courtesy; with a game in the panel, one shot landing in the margin would cancel the break and explain nothing. ESC and the buttons remain. |
| The countdown **leads** the rail rather than following the text | The rail is read against a panel that has already taken the eye, so it must go *how long is left → what to do → how to leave*. |

#### YouTube links are rewritten

`watch?v=`, `youtu.be`, `/shorts/` and `/live/` all become an `/embed/` URL
presented `.player`, preserving any start offset in either spelling (`t=68`,
`t=1m30s`). Everything else is left untouched and loaded `.direct`.

Shorts especially need it: followed directly, a Short plays and then scrolls on
to the next one — an infinite feed at the exact moment the break was meant to
stop the user looking at one.

#### The three things that break an embed

Each was diagnosed the hard way and each has a test holding it.

| Symptom | Cause | What the library does |
|---|---|---|
| `Error 153 — player configuration error` | No `Referer`/origin. A top-level navigation to `/embed/` carries none. | Loads the player in an `<iframe>` inside a document that has a real origin. |
| `Error 152 — video unavailable` | The wrapper document claimed **the target's own** origin. An embed is meant to be cross-origin. | Uses a reserved `.invalid` host: third-party, unresolvable, so it cannot be mistaken for a real site or collide with one's cookies in the shared data store. |
| Autoplay silently never starts | Unmuted autoplay is refused without a user gesture, and the refusal looks exactly like a video waiting to be clicked. | `startsMuted` defaults to `true`, and `loadURL` emits `mute=1` alongside `autoplay=1`. |

**`loop=1` is emitted with `playlist=<the same video id>`.** On a single video
YouTube ignores `loop` without it — the parameter was designed for playlists,
and the single-video spelling is a documented workaround, not an oversight to be
tidied away.

#### Low Power Mode defeats autoplay entirely

Measured. With macOS Low Power Mode on, WebKit's
`RequireUserGestureForVideoDueToLowPowerMode` refuses to start **any** video
without a real click — muted or not, `autoplay=1` or not, and whatever the host
sets `WKWebViewConfiguration.mediaTypesRequiringUserActionForPlayback` to. It
has no muted exemption, no platform guard, and no API or SPI that lifts it.

Deliberately not detected or worked around: the only thing that satisfies the
gate is the user pressing play, which is the fallback anyway. The symptom, so
nobody spends a day on it again — **the video loads and displays correctly,
shows its play button, and simply never starts.**

#### Authentication

`WebPanelView` uses the default (persistent, process-wide)
`WKWebsiteDataStore`, not an ephemeral one. The library is linked into its host,
so that is the same cookie jar the host's own web views write to: a host that
has already exchanged a token for a session cookie has already authenticated
this panel, and a signed-in webmail stays signed in between alerts. An ephemeral
store is the more cautious default in a browser; here it would mean every break
surface opening on a login page.

### Completion honesty

```swift
public func completionState(
    phase: NotificationClock.Phase,
    didCompleteTask: Bool,
    completedEarly: Bool
) -> CompletionState   // .none | .completed(label:) | .acknowledged(label:)
```

The user asked for confirmation that a break *completed*. A surface saying so
when seventeen of twenty seconds were skipped is telling them something false
about their own health. So:

| What happened | What the ring's centre says |
|---|---|
| Ran to zero | the timer's `completionLabel` ("Break complete"), stroke shifts to the success colour |
| Done pressed early | `acknowledgementLabel` ("Got it"), arc **snaps** to full rather than animating there |
| Skip, Snooze, ESC, click-away, or a deadline that elapsed while the machine slept | nothing at all |

Only a genuine completion earns the success colour (`CompletionState.isCompletion`).

### Button outcomes

```swift
public static func outcome(
    for style: StandardNotification.Button.ButtonStyle,
    taskPhaseActive: Bool,
    hasClock: Bool
) -> ButtonOutcome   // .completeTaskThenHold | .cancelAndDismiss | .dismiss
```

The caller's closure supplies the *meaning*; the library supplies the
*dismissal*, and it always ends in the window coming down — a Snooze that leaves
the interrupt on screen is not a snooze.

`.primary` during an active task phase routes through the clock
(`completeTask()`) rather than dismissing inline. Dismissing in the same turn
would make the acknowledgement state exist for exactly zero frames, and the
acknowledgement is the whole point of pressing Done rather than Skip.

---

## Alert Modes and Window Configuration

```swift
public enum AlertMode: Sendable {
    case interrupt   // the whole screen becomes the scrim
    case ambient     // a positioned window; the desktop stays untouched
}
```

`AlertMode` is one named axis of presentation *intent*, above
`OverlayWindowManager.PresentationMode`'s pure geometry. `PresentationMode` says
only where a rectangle lands; `AlertMode` says what the alert *is*, and bundles
the ~20 `Configuration` knobs that are only ever correct together.

### `Configuration.interrupt(…)`

```swift
public static func interrupt(
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil,
    backdropStyle: BackdropStyle = .blurredDesktop
) -> OverlayWindowManager.Configuration
```

Full-screen geometry on the target screen, a heavy blur backdrop dimmed to
`Legibility.safeDim`, always on top, and it **takes key focus** — ESC must work
without a prior click, and stray keystrokes must not land in whatever the user
was typing behind the dim.

A painted `backdropStyle` replaces that surface entirely and makes `screenDim`
inert: the dim exists to bound an *unknown* desktop, and a painted field is not
unknown.

### `Configuration.ambient(…)`

```swift
public static func ambient(
    position: OverlayWindowManager.WindowPosition,
    width: CGFloat,
    height: CGFloat,
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil
) -> OverlayWindowManager.Configuration
```

No blur window at all, so `screenDim` is inert here — every other window stays
clickable and the desktop keeps its light.

`width`/`height` are **required, not optional**, deliberately. `Configuration`
defaults `presentationMode` to `.fullScreen` and `createWindow` only shrinks
that starting rect when both are non-nil; leaving them nil (as an earlier
version of this factory did) silently produces a transparent window the size of
the screen, swallowing every click on the display.

It does **not** take key focus. `.ambient` is confirmations, warnings, plugin
notices and toasts, and a toast that steals focus mid-keystroke is exactly the
failure this mode exists to avoid. The window stays key-*capable*, so clicking
it can still make it key and ESC still dismisses it.

### What the factories do not reach

Two `Configuration` fields cannot be set through either factory
([#3](https://github.com/vibecare-io/vibe-notify-macos/issues/3)):

- **`isMoveable`** is never set by either, so it falls back to `false`. It only
  *means* anything for `.ambient` — a full-screen window has nowhere to move to
  — so the gap is that `.ambient` has no way to accept it.
- **`screenBlurIntensity`** is hardcoded to `.heavy` in `interrupt(…)`. This is
  worse than merely unwired: a caller's choice is silently overridden, so every
  full-screen alert is Heavy no matter what was picked. `.ambient` builds no
  blur window, so intensity has nowhere to apply there either.

A consumer that exposes either as a user-facing control today gets a control
that does nothing. Until #3 lands, the only way to reach them is to build a
`Configuration` with its memberwise initializer instead of the factory — every
field is `public let`, so a factory result can also be read back and used as a
template.

---

## Countdowns

Two different countdowns, deliberately not one type with a flag.

### `TaskTimer` — the big ring

```swift
public struct TaskTimer: Sendable {
    public let duration: TimeInterval
    public let unitLabel: String        // "seconds"
    public let completionLabel: String  // "Break complete"
}
```

The large, legible countdown for an exercise the user is meant to read — "look
20 feet away for 20 seconds". `unitLabel` and `completionLabel` are the caller's
words, never inferred by the library.

**`.ambient` never draws one.** `RichNotification.effectiveTaskTimer` returns
`nil` in `.ambient`, and it is enforced there rather than in the renderer so
that `countdown` agrees with what is drawn — if the renderer alone ignored the
timer, the clock would still run a task phase and the toast would sit on screen
for `duration + delay` with nothing to explain why. A large labelled ring reads
as a task, and in ambient mode there is no task. The caller's stored `taskTimer`
is left untouched; this reinterprets it, it does not rewrite what was passed.

### `DismissIndicator` — the quiet one

```swift
public enum DismissIndicator: Sendable, Equatable {
    case none
    case bar
    case hairlineRing
}
```

The generic "this closes in N" signal: no number, no label, just an indication
that dismissal is coming. It is a property of `AutoDismiss`:

```swift
public init(delay: TimeInterval, indicator: DismissIndicator = .none)
```

`.hairlineRing` is drawn only by the rich renderer.
`StandardNotificationView` and `SVGNotificationView` read the compatibility
shim `AutoDismiss.showProgress`, which is `true` only for `.bar` — so
`.hairlineRing` draws nothing in either older renderer, which is correct: it has
no old-renderer picture.

### Both together: sequential phases

```swift
public struct Countdown: Sendable {
    public let task: TaskTimer?
    public let autoDismiss: StandardNotification.AutoDismiss?
}
```

Either half may be `nil` independently; both `nil` means no clock at all, not an
inert object carried around.

When both are set they run as **sequential phases, never a race**. The task runs
first and alone, and the auto-dismiss clock arms the instant the task hits zero,
its delay measured from that moment. Total time on screen is
**`duration + delay`**.

Earliest-deadline-wins was considered and rejected: it lets a caller's habitual
5-second auto-dismiss ceiling silently kill a 20-second eye break at second
five.

A task timer also suppresses the dismiss indicator outright while it runs, even
when one is configured. There is exactly one number on screen at a time, and it
is the one the user is meant to obey.

`RichNotification.countdown` derives the pair from the model, so the renderer
and the clock cannot disagree about what is being timed.

---

## NotificationClock

One cancellable clock per notification, owned by `OverlayWindowManager` and
keyed by the same id as its window.

It exists because the dismiss timer used to be a bare
`DispatchQueue.main.asyncAfter` living *inside* each renderer's view body, which
produced three defects at once: no cancellation handle (a button tap or ESC
could not stop it), the same code written twice byte-identically in two
renderers, and caller-supplied SwiftUI content getting no timer at all.

### Phases

```swift
public enum Phase: Sendable, Equatable {
    case task        // counting down the user-facing exercise
    case dismissing  // counting down to automatic dismissal
    case finished    // ran to completion; the window should close
    case cancelled   // stopped early — never a completion
}
```

`.dismissing` is entered directly when there is no task timer, or from `.task`
the moment the task reaches zero. `.cancelled` covers Skip, Snooze, ESC,
click-away, teardown, **and a task whose deadline elapsed while the machine was
asleep** — `didCompleteTask` stays `false` for every one of them.

### Controls

| Member | What it does |
|---|---|
| `completeTask()` | "Done" — ends the task phase *now*. The dismiss delay is then measured from this moment, not from the deadline the task would have had. No-op outside `.task`. |
| `cancel()` | User-driven stop. No completion state, reports the end so the window comes down. A no-op on an already-terminal clock, which is what makes the `cancel()` → dismiss → `invalidate()` round trip re-entrancy safe. |
| `remaining` | Seconds left in the current phase, derived from the wall-clock deadline. Never negative. |
| `progress` | Fraction of the current phase elapsed, `0...1`. |
| `indicator` | What the *dismiss* indicator should draw right now — `.none` during `.task`. |
| `completionHold` | `public static let`, 1.5s. How long a completed task holds its completion state when the caller configured no `AutoDismiss` of their own. |

**`deadline` is a wall-clock `Date`, not a duration.** `asyncAfter` across a
system sleep is not a contract worth relying on; comparing `Date()` against a
stored deadline is. A wake with the deadline already behind us voids a task
outright — a short nap straddling the deadline surfaces as an overshoot of one
second, which no tolerance can distinguish from an ordinary late tick, and on
tolerance alone that break would be reported *complete* to a user who slept
through the whole thing.

### Reading it from SwiftUI

`OverlayWindowManager.show(id:configuration:countdown:content:)` injects the
clock into the environment around the hosted view, which is how caller-supplied
content inherits a countdown without asking for one:

```swift
@Environment(\.notificationClock) private var clock
```

It is optional rather than an `@EnvironmentObject` on purpose: a missing
environment object is a crash, and "this overlay has no countdown" is an
ordinary, expected state.

**Reading it gets you the reference, not the redraws.** `NotificationClock` is a
Combine `ObservableObject`, and SwiftUI invalidates an environment reader only
when the stored *value's* identity changes — it does not subscribe to
`objectWillChange` on your behalf. The reference is the same object for the
whole life of the overlay, so a view that reads the clock straight out of the
environment and prints `clock.remaining` renders the initial number once and
then sits frozen. Anything that *draws* the countdown must hand the reference to
a child that observes it:

```swift
struct MyAlert: View {
  @Environment(\.notificationClock) private var clock
  var body: some View {
    if let clock {
      CountdownView(clock: clock)   // observes, so it redraws each tick
    }
  }
}

struct CountdownView: View {
  @ObservedObject var clock: NotificationClock
  var body: some View {
    Text("\(Int(clock.remaining.rounded(.up)))")   // repaints per tick
  }
}
```

The one-level indirection is the whole trick: `@ObservedObject` is what
subscribes to `objectWillChange`. Nothing about ownership, cancellation or
dismissal depends on this — those are the manager's, and they work regardless.

---

## Legibility and Backdrops

The invariant every rendering decision serves:

> Text is never rendered over a backdrop whose luminance we do not control.

`.interrupt` satisfies it by dimming the whole screen; `.ambient` by drawing a
local feathered scrim under its text block. Text colour then follows the scrim
*the library drew* — never `@Environment(\.colorScheme)`, which answers a
question about the OS rather than about the pixels behind the alert. That
rendering-decision-in-a-view-body is the bug this whole area exists to fix:
`SVGNotificationView` defines `useLightText` as `colorScheme == .dark` and
branches every colour on it, which is unassertable without a screen and
therefore survived five releases.

### `screenDim` and `Legibility.safeDim`

`Configuration.screenDim` is the opacity of the black backdrop behind the blur,
independent of blur radius. It is clamped to `0.1...0.95`: the floor is the
minimum background alpha the private CGS blur call needs to composite at all,
and the ceiling stops short of a fully opaque backdrop, which would no longer
read as a blur. It defaults to `0.1`, and `Configuration.interrupt(…)` sets it
to `Legibility.safeDim`.

```swift
public static let safeDim: Double = 0.55
```

**The derivation**, worst case a pure white desktop: compositing black at alpha
`a` over white leaves sRGB `1 − a`. For white text to clear WCAG AA at 4.5:1 the
backdrop's relative luminance must be at most `1.05/4.5 − 0.05 = 0.1833`, which
is sRGB ≈ 0.465, i.e. `a` ≈ 0.535. Rounded up: 0.55.

One number, three uses, derived once — the `.interrupt` dim, the feathered
scrim's peak opacity, and the threshold above which a local scrim is redundant.
Re-deriving it anywhere is how two of the three end up stale.

`Legibility.maxSafeLuminance` (`1.05/4.5 − 0.05`) is not a second constant. It
is the middle step of the same derivation, promoted to a name, and it is the
bound that applies to a surface the library *painted* rather than one it dimmed.

### `scrimStrategy`

```swift
public static func scrimStrategy(effectiveDim: Double, reduceTransparency: Bool) -> ScrimStrategy
// .none | .feathered | .solid
```

The selector is the effective dim, **not a boolean over `screenBlur`**: a
`.light` blur at the pinned 0.1 is blur-on and is not a safe backdrop. A blur
preserves local mean luminance — blurring a white browser half yields a white
half — so radius destroys detail, not light.

- `effectiveDim >= safeDim`: draw nothing. A local scrim over a uniform field is
  a visible rectangle, i.e. a card arrived at by accident.
- `effectiveDim < safeDim`, **including 0**: the renderer owns the backdrop
  under its own text and must draw it.

Reduce Transparency only changes *which* local backdrop (`.solid` instead of
`.feathered`), never whether one is needed.

### `BackdropStyle`

What an `.interrupt` alert puts behind itself. The feature is a product one —
staring at your own blurred work for twenty seconds is not restful, and the
point of a 20-20-20 break is to look *away*.

| Case | Family | What it is |
|---|---|---|
| `.blurredDesktop` | desktop | Your desktop, blurred and dimmed. **The default**, and byte for byte the behaviour every alert had before this type existed. |
| `.charcoal` | solid | Near-black neutral |
| `.midnight` | solid | Deep blue-violet |
| `.moss` | solid | Deep desaturated green |
| `.dusk` | gradient | Indigo into plum |
| `.deepSea` | gradient | Navy into deep teal |
| `.ember` | gradient | Near-black into a deep warm maroon |

`BackdropStyle` is `String`-backed, `CaseIterable` and `Identifiable`, and
carries `displayName`, `summary` and `family` for a settings picker. `fill`
returns `nil` for `.blurredDesktop` and a `BackdropFill` for everything else —
that `nil` is the discriminator every consumer branches on, rather than a
separate `isPainted` flag that could disagree with it.

**Legibility here is enforced by construction, not by convention.** Every
`BackdropFill.Stop` passes through `Legibility.luminanceCapped(…)` in its
initializer, so `red`/`green`/`blue` are always the *constrained* values and
`relativeLuminance` is always `<= maxSafeLuminance`. There is no memberwise
initializer that skips the cap. A pale solid or a light gradient is therefore
not "a bad idea we chose not to offer"; it is unconstructible — including by
someone adding a preset later who never read this page.

The capping scales in *linear* light rather than on the sRGB values, so an
over-bright teal comes back a darker teal rather than a grey: relative luminance
is a linear combination of the linearised channels, so scaling all three by the
same factor lands exactly on the cap and leaves their ratios intact.

**Not a colour picker.** A free colour well is precisely the API that would need
a runtime "your choice is illegible" error, and an error nobody can act on is
worse than a smaller menu.

### Reduce Transparency

A painted backdrop does not fight Reduce Transparency, it removes its cause. The
two things Reduce Transparency objects to — a translucent dim and a private-API
blur — are exactly how the *desktop* backdrop reaches a safe luminance. A
painted backdrop has neither: it is opaque already, no blur is involved, and it
is luminance-capped. So the user's chosen backdrop survives the setting instead
of being silently replaced with black.

`.interrupt` over `.blurredDesktop` *does* drop to opaque black under Reduce
Transparency. That costs nothing — the desktop was already unreadable behind a
0.55 dim and a 50-point blur — and it takes the private CGS blur call off the
legibility path entirely, so if it ever degrades to nothing the alert is still
legible, just flatter.

---

## Which Renderer Runs

`NotificationBuilder.show()` picks a renderer from what you set. The rules, in
order:

**Rule 1 — any field the older renderers cannot express at all routes rich,
regardless of buttons:** `.mode(…)` called explicitly, `.taskTimer(…)`,
`.footnote(…)`, or an `.illustration(…)` of the `.image`/`.symbol` kind.

**Rule 2 — an illustration of *any* kind (including a plain `.svg(…)`) plus at
least one button routes rich.** This is the fix for the silent button drop:

```swift
// Before: compiled, rendered the SVG, and silently discarded the button —
// `show()` forked on `useSVG` before buttons ever entered the picture, and
// `SVGNotification` has no `buttons` property to have accepted one.
// Now: routes to the rich renderer and draws the button.
VibeNotify.builder()
    .svg("/path/to/icon.svg")
    .button(StandardNotification.Button(title: "OK", style: .primary) {})
    .show()
```

**Short of both**, `.svg(path).show()` renders exactly as it did in 0.0.5. Rule 1
existing is what makes that safe: a caller who wants the new renderer for an
SVG-only alert opts in with one `.mode(…)` call rather than having it silently
forced on them. Calling `.mode(.ambient)` — the value `mode` already defaults to
— is itself the opt-in signal.

### Mode upgrade

`.taskTimer(…)` without any `.mode(…)` call upgrades the alert to `.interrupt`.

At the model layer `.ambient` is always what the caller actually asked for, so
`effectiveTaskTimer` correctly drops the ring. Through the builder it is not:
`mode` defaults to `.ambient` whether or not the caller ever thought about it,
so `.taskTimer(TaskTimer(duration: 20, …))` alone — the shape a caller reaches
for when they want a ring — would otherwise produce neither a ring nor a clock,
with no error and no visible alert to explain why.

Upgrading was chosen over refusing loudly because a `fatalError` or
`assertionFailure` compiles away in release builds, resuming the silent failure
exactly where checking is cheapest to skip. A caller who really does want
`.ambient` with a task timer keeps the escape hatch: `.mode(.ambient)`
explicitly is honoured.

### Window sizing through the builder

`.interrupt` takes no size. `.ambient` falls back to `.topRight` at 300×400 —
the same corner and footprint `showSVG`'s own default `presentationMode` already
used — unless you supply `.position(…)` / `.width(…)` / `.height(…)`.

Note that the legacy builder knobs (`transparent`, `screenBlur`, `windowLevel`,
`windowOpacity`, `moveable`) are **not** carried into a rich presentation: the
configuration comes from the `AlertMode` factories, which bundle the knobs that
are only ever correct together. Mixing them by hand is what produced the bug the
rich renderer exists to fix.

---

## Customization Options

### Window Positioning

Use 9 predefined positions to place notifications anywhere on screen:

```swift
VibeNotify.builder()
    .title("Positioned")
    .message("Try different positions")
    .icon(.info)
    .position(.center)        // or .topLeft, .top, .topRight
    .width(400)               // .left, .center, .right
    .height(200)              // .bottomLeft, .bottom, .bottomRight
    .show()
```

**Available Positions:**
- `.topLeft`, `.top`, `.topRight`
- `.left`, `.center` (also `.centre`), `.right`
- `.bottomLeft`, `.bottom`, `.bottomRight`

### Custom Sizing

Override default dimensions with custom width and height:

```swift
VibeNotify.builder()
    .title("Custom Size")
    .message("This notification is 600x400")
    .icon(.success)
    .position(.center)
    .width(600)
    .height(400)
    .show()
```

**Size Guidelines:**
- **Small**: 300x150 - Toast notifications
- **Medium**: 400x200 - Standard notifications
- **Large**: 600x400 - Rich content

### Moveable Windows

Allow users to drag notifications to reposition them:

```swift
VibeNotify.builder()
    .title("Drag Me!")
    .message("Click and drag anywhere")
    .icon(.info)
    .position(.topLeft)
    .width(350)
    .height(180)
    .moveable(true)
    .show()
```

### Transparent Backgrounds

Add macOS-native blur materials for beautiful transparent effects:

```swift
VibeNotify.builder()
    .title("Transparent")
    .message("Beautiful blur effect")
    .icon(.success)
    .transparent(
        true,
        material: .hudWindow
    )
    .show()
```

**Available Materials:**
- `.hudWindow` - Heads-up display style (default)
- `.popover` - Popover menu style
- `.sidebar` - Sidebar style
- `.menu` - Menu style
- `.selection` - Selection style
- `.titlebar` - Titlebar style
- `.underWindowBackground` - Under window style

### Window Opacity

Control overall window transparency (0.0 = invisible, 1.0 = opaque):

```swift
VibeNotify.builder()
    .title("Semi-Transparent")
    .message("70% opacity")
    .icon(.info)
    .windowOpacity(0.7)
    .show()
```

### Screen Blur

Blur the **entire screen** behind the notification for maximum focus:

```swift
// Recommended: Use intensity presets
VibeNotify.builder()
    .title("Focus Mode")
    .message("Everything else is blurred")
    .icon(.success)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(true, intensity: .medium)
    .dismissOnScreenTap(true)
    .show()
```

**Blur Intensity Levels:**

| Preset | Radius | Use Case |
|--------|--------|----------|
| `.light` | 10 | Subtle blur, content still partially visible |
| `.medium` | 25 | Balanced blur, good for most notifications |
| `.heavy` | 50 | Strong blur, draws full attention |
| `.custom(radius:)` | 0-100 | Fine-grained control |

```swift
// Light blur - subtle background effect
.screenBlur(true, intensity: .light)

// Heavy blur - maximum focus
.screenBlur(true, intensity: .heavy)

// Custom radius for precise control
.screenBlur(true, intensity: .custom(radius: 35))
```

**Difference:**
- **`transparent`** - Blurs notification background
- **`screenBlur`** - Blurs entire screen behind notification
- **Can use both together** for layered effects!

### Presentation Modes

Alternative to positioning - use predefined layouts:

```swift
// Full screen overlay
VibeNotify.builder()
    .title("Full Screen")
    .message("Covers entire screen")
    .presentationMode(.fullScreen)
    .show()

// Banner at top
VibeNotify.builder()
    .title("Banner")
    .message("Slides from top")
    .presentationMode(.banner(edge: .top, height: 120))
    .show()

// Toast in corner
VibeNotify.builder()
    .title("Toast")
    .message("Corner notification")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))
    .show()
```

---

## SVG Support

VibeNotify includes built-in SVG rendering using SVGView, supporting both local files and remote URLs.

> **`SVGNotification` and `showSVG(…)` are deprecated** in favour of
> `RichNotification` with an `.svg` illustration and
> `VibeNotify.showRich(_:configuration:)`. They still work and still render
> exactly as they did in 0.0.5 — removal is a 1.0 concern — but they cannot
> express buttons or a footnote. That gap is what made
> `.svg(…).button(…)` compile while silently discarding every button:
> `SVGNotification` has no `buttons` property that could have accepted one.
> The builder now routes that combination to the rich renderer instead; see
> [Which Renderer Runs](#which-renderer-runs).

### SVG as Icon — does not work

```swift
// ⚠️ Draws NOTHING. Documented here because it was documented as working.
.icon(.svg("/path/to/icon.svg"))
.icon(.url(someURL))
```

`StandardNotificationView.iconView(for:)` maps both `.svg` and `.url` to
`EmptyView()`, and `.image` is pinned to a hardcoded 48×48. `IconType` is an
icon slot, not an illustration slot. For an SVG at a size you choose, use a
`RichNotification` illustration:

```swift
VibeNotify.builder()
    .illustration(.svg(.filePath("/path/to/icon.svg"), size: CGSize(width: 200, height: 200)))
    .title("Custom Icon")
    .message("Drawn at the size you asked for")
    .mode(.ambient)
    .show()
```

### SVG Full Notification (Local File)

Display an SVG as the main notification content:

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animation.svg",
        size: CGSize(width: 200, height: 200),
        interactive: true
    )
    .title("Vector Graphics")
    .message("Full SVG notification")
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 350, height: 400)))
    .moveable(true)
    .transparent(true)
    .show()
```

### SVG from URL (New!)

Load SVG from remote URLs:

```swift
// Using builder API
VibeNotify.builder()
    .svgURL(
        URL(string: "https://example.com/icon.svg")!,
        size: CGSize(width: 200, height: 200),
        interactive: false
    )
    .title("Remote SVG")
    .message("Loaded from URL")
    .show()

// Using direct API
VibeNotify.shared.showSVG(
    svgURL: URL(string: "https://example.com/icon.svg")!,
    title: "Remote Icon",
    message: "From CDN"
)
```

### SVG with Customization

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animated.svg",
        size: CGSize(width: 300, height: 300),
        interactive: true
    )
    .title("Animated SVG")
    .message("Interactive animation")
    .position(.center)
    .width(600)
    .height(500)
    .moveable(true)
    .transparent(true, material: .hudWindow)
    .screenBlur(true)
    .dismissOnScreenTap(true)
    .show()
```

### SVG with Auto-Dismiss

```swift
VibeNotify.builder()
    .svg(
        "/path/to/loading.svg",
        size: CGSize(width: 200, height: 200)
    )
    .title("Loading...")
    .message("Please wait")
    .position(.center)
    .width(400)
    .height(300)
    .autoDismiss(after: 3.0, showProgress: true)
    .show()
```

---

## Advanced Features

### Auto-Dismiss with Progress

Show a progress bar while counting down to auto-dismiss:

```swift
VibeNotify.builder()
    .title("Auto Dismiss")
    .message("Closes in 5 seconds")
    .icon(.info)
    .autoDismiss(
        after: 5.0,
        showProgress: true
    )
    .show()
```

### Multiple Buttons

Add multiple action buttons with different styles:

```swift
VibeNotify.builder()
    .title("Delete File?")
    .message("This action cannot be undone")
    .icon(.warning)
    .button(
        StandardNotification.Button(
            title: "Delete",
            style: .destructive
        ) {
            // Perform deletion
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            // Cancel action
        }
    )
    .position(.center)
    .width(450)
    .height(200)
    .show()
```

**Button Styles:**
- `.primary` - Blue, primary action
- `.secondary` - Gray, secondary action
- `.destructive` - Red, destructive action

### Keyboard Shortcuts

Notifications support ESC key to dismiss:

```swift
// Press ESC to dismiss
VibeNotify.builder()
    .title("Press ESC")
    .message("Hit ESC key to close")
    .icon(.info)
    .show()
```

### Programmatic Dismissal

```swift
// Dismiss specific notification
let id = VibeNotify.builder()
    .title("Temporary")
    .message("Will be dismissed programmatically")
    .show()

// Later...
VibeNotify.shared.dismiss(id: id)

// Dismiss all notifications
VibeNotify.shared.dismissAll()
```

### Custom SwiftUI Views

Display any custom SwiftUI view as a notification:

```swift
VibeNotify.shared.showCustom(
    presentationMode: .fullScreen,
    windowLevel: .floating
) {
    ZStack {
        Color.black.opacity(0.5)

        VStack(spacing: 20) {
            Text("Custom View")
                .font(.largeTitle)
                .foregroundColor(.white)

            Button("Dismiss") {
                VibeNotify.shared.dismissAll()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

---

## API Reference

### Builder Methods

All builder methods return `self` for chaining:

```swift
// Content
.title(_ title: String) -> Self
.message(_ message: String) -> Self
.icon(_ icon: StandardNotification.IconType) -> Self

// Buttons
.button(_ button: StandardNotification.Button) -> Self

// Positioning
.position(_ position: WindowPosition) -> Self
.presentationMode(_ mode: PresentationMode) -> Self

// Sizing
.width(_ width: CGFloat) -> Self
.height(_ height: CGFloat) -> Self

// Behavior
.moveable(_ moveable: Bool = true) -> Self
.alwaysOnTop(_ alwaysOnTop: Bool = true) -> Self
.windowLevel(_ level: WindowLevel) -> Self

// Visual Effects
.transparent(
    _ enabled: Bool = true,
    material: NSVisualEffectView.Material = .hudWindow
) -> Self

.windowOpacity(_ opacity: CGFloat) -> Self

// Intensity-based blur (recommended)
.screenBlur(
    _ enabled: Bool = true,
    intensity: ScreenBlurIntensity
) -> Self

// Legacy material-based blur
.screenBlur(
    _ enabled: Bool = true,
    material: NSVisualEffectView.Material = .underWindowBackground
) -> Self

.dismissOnScreenTap(_ enabled: Bool = true) -> Self

// Auto-Dismiss (deprecated spelling — see Deprecations)
.autoDismiss(
    after delay: TimeInterval,
    showProgress: Bool = false
) -> Self

// SVG (deprecated content model — see Deprecations)
.svg(
    _ path: String,
    size: CGSize = CGSize(width: 200, height: 200),
    interactive: Bool = false
) -> Self

.svgURL(
    _ url: URL,
    size: CGSize = CGSize(width: 200, height: 200),
    interactive: Bool = false
) -> Self

// Rich — any of these routes show() to the rich renderer
.illustration(_ illustration: RichNotification.Illustration) -> Self
.footnote(_ footnote: String) -> Self
.taskTimer(_ timer: TaskTimer) -> Self
.mode(_ mode: AlertMode) -> Self

// Display
.show() -> UUID
```

### Rich API

```swift
VibeNotify.shared.showRich(
    _ notification: RichNotification,
    configuration: OverlayWindowManager.Configuration,
    reduceMotion: Bool? = nil,
    reduceTransparency: Bool? = nil,
    onEnd: ((NotificationClock.Phase?) -> Void)? = nil
) -> UUID

OverlayWindowManager.Configuration.interrupt(
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil,
    backdropStyle: BackdropStyle = .blurredDesktop
) -> OverlayWindowManager.Configuration

OverlayWindowManager.Configuration.ambient(
    position: OverlayWindowManager.WindowPosition,
    width: CGFloat,
    height: CGFloat,
    dismissOnScreenTap: Bool = false,
    animatePresentation: Bool = true,
    screen: NSScreen? = nil
) -> OverlayWindowManager.Configuration

// Register an end handler on an overlay that is already showing. Chains rather
// than replaces, and fires immediately with `nil` if `id` is not showing — so a
// caller is never left waiting on an overlay that has already gone.
OverlayWindowManager.shared.addEndHandler(
    id: UUID,
    _ handler: @escaping (NotificationClock.Phase?) -> Void
)
```

### Convenience Methods

```swift
// Quick notifications
VibeNotify.shared.success(
    title: String = "Success",
    message: String,
    autoDismiss: TimeInterval? = 3.0
) -> UUID

VibeNotify.shared.error(
    title: String = "Error",
    message: String,
    buttons: [StandardNotification.Button] = []
) -> UUID

VibeNotify.shared.warning(
    title: String = "Warning",
    message: String,
    autoDismiss: TimeInterval? = 5.0
) -> UUID

VibeNotify.shared.info(
    title: String = "Info",
    message: String,
    autoDismiss: TimeInterval? = 4.0
) -> UUID
```

### Icon Types

```swift
.icon(.success)                              // Green checkmark
.icon(.error)                                // Red X
.icon(.warning)                              // Orange triangle
.icon(.info)                                 // Blue info icon
.icon(.system("star.fill"))                  // Any SF Symbol
.icon(.image(NSImage(named: "icon")!))       // Custom NSImage, pinned to 48×48
.icon(.svg("/path/to/icon.svg"))             // ⚠️ draws nothing — see SVG as Icon
.icon(.url(someURL))                         // ⚠️ draws nothing — see SVG as Icon
```

### Screen Blur Intensity

```swift
.light                    // radius: 10 - subtle blur
.medium                   // radius: 25 - balanced
.heavy                    // radius: 50 - strong blur
.custom(radius: Int)      // radius: 0-100 - clamped
```

There is **no default intensity**. `Configuration.screenBlurIntensity` is
`ScreenBlurIntensity?` and defaults to `nil`, which selects the legacy
`NSVisualEffectView` material path rather than any preset.
`Configuration.interrupt(…)` hardcodes `.heavy` — see
[What the factories do not reach](#what-the-factories-do-not-reach).

### Window Positions

```swift
.topLeft, .top, .topRight
.left, .center, .right
.bottomLeft, .bottom, .bottomRight
```

### Presentation Modes

```swift
.fullScreen
.banner(edge: .top, height: 120)
.toast(corner: .topRight, size: CGSize(width: 300, height: 150))
.custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300))
```

---

## Deprecations

Nothing here has been removed. Every deprecated symbol still compiles and still
behaves exactly as it did — these are marked, not broken.

### `AutoDismiss.init(delay:showProgress:)` → `init(delay:indicator:)`

```swift
// Deprecated
StandardNotification.AutoDismiss(delay: 5.0, showProgress: true)
// Replacement
StandardNotification.AutoDismiss(delay: 5.0, indicator: .bar)
```

`showProgress: true` maps to `.bar`, `false` maps to `.none`. The property
`AutoDismiss.showProgress` survives as a read-only shim — both older renderers
read it, and this keeps them byte-identical while the storage underneath is now
`indicator`. It reports `true` only for `.bar`.

Note the deprecated initializer has **no default** for `showProgress`, unlike
the old declaration: only `init(delay:indicator:)` owns the single-argument
`AutoDismiss(delay:)` call shape, and defaulting it on both would make that call
ambiguous.

### `NotificationBuilder.autoDismiss(after:showProgress:)`

Deprecated alongside the initializer above, and **still the only auto-dismiss
the builder offers**. It was not replaced with an `indicator:`-taking overload
because a second defaulted-second-parameter overload of the same base name would
make every existing call site that omits both trailing arguments ambiguous. To
reach `.hairlineRing`, build the `AutoDismiss` yourself and pass it through
`RichNotification`.

### `SVGNotification` and `showSVG(…)` → `RichNotification` + `showRich(…)`

```swift
// Deprecated
VibeNotify.shared.showSVG(svgPath: "/path/to/icon.svg", title: "Hi")

// Replacement
VibeNotify.shared.showRich(
    RichNotification(
        illustration: .svg(.filePath("/path/to/icon.svg"), size: CGSize(width: 200, height: 200)),
        title: "Hi",
        mode: .ambient
    ),
    configuration: .ambient(position: .topRight, width: 300, height: 400)
)
```

`SVGNotification` cannot express buttons or a footnote — it has no properties
for them. **This is the API that silently discarded buttons.**

Deprecated rather than made to assert: an `assertionFailure` compiles away in
release builds, which would silently resume swallowing a caller's `buttons:` in
exactly the configuration where it matters. Removal is a 1.0 concern.

---

## Examples

### Example 1: Simple Success Toast

```swift
VibeNotify.builder()
    .title("Success")
    .message("File saved successfully")
    .icon(.success)
    .presentationMode(.toast(corner: .topRight, size: CGSize(width: 300, height: 150)))
    .autoDismiss(after: 3.0, showProgress: true)
    .show()
```

### Example 2: Centered Modal Dialog

```swift
VibeNotify.builder()
    .title("Confirm Delete")
    .message("Are you sure you want to delete this item?")
    .icon(.warning)
    .position(.center)
    .width(450)
    .height(200)
    .screenBlur(true)
    .dismissOnScreenTap(false)
    .button(
        StandardNotification.Button(
            title: "Delete",
            style: .destructive
        ) {
            // Delete action
        }
    )
    .button(
        StandardNotification.Button(
            title: "Cancel",
            style: .secondary
        ) {
            // Cancel
        }
    )
    .show()
```

### Example 3: Transparent Floating HUD

```swift
VibeNotify.builder()
    .title("System Status")
    .message("All services running normally")
    .icon(.success)
    .position(.bottomRight)
    .width(350)
    .height(180)
    .moveable(true)
    .transparent(true, material: .hudWindow)
    .windowOpacity(0.9)
    .autoDismiss(after: 5.0)
    .show()
```

### Example 4: SVG Animation with Blur

```swift
VibeNotify.builder()
    .svg(
        "/path/to/animation.svg",
        size: CGSize(width: 250, height: 250),
        interactive: true
    )
    .title("Loading...")
    .message("Please wait while we process")
    .position(.center)
    .width(500)
    .height(400)
    .transparent(true, material: .hudWindow)
    .screenBlur(true, intensity: .medium)
    .show()
```

### Example 5: Remote SVG from CDN

```swift
VibeNotify.builder()
    .svgURL(
        URL(string: "https://cdn.example.com/icon.svg")!,
        size: CGSize(width: 200, height: 200)
    )
    .title("Remote Resource")
    .message("SVG loaded from CDN")
    .position(.topRight)
    .width(400)
    .height(350)
    .transparent(true)
    .autoDismiss(after: 4.0, showProgress: true)
    .show()
```

### Example 6: 20-20-20 Break

The countdown here is a `TaskTimer`, not an auto-dismiss: the user is meant to
read the number and obey it, and only a break that runs to zero gets told it
completed.

```swift
VibeNotify.builder()
    .illustration(.symbol("eye", pointSize: 96, color: nil))
    .title("20-20-20 Rule")
    .message("Look at something 20 feet away")
    .footnote("Press ESC or click anywhere to skip")
    .taskTimer(TaskTimer(
        duration: 20,
        unitLabel: "seconds",
        completionLabel: "Break complete"))
    .button(StandardNotification.Button(title: "Done", style: .primary) {})
    .button(StandardNotification.Button(title: "Skip", style: .secondary) {})
    .show()
```

No `.mode(.interrupt)` is needed — the task timer implies it. Pressing Done
early shows "Got it" rather than "Break complete"; pressing Skip shows neither.

### Example 7: Focus Mode Alert

```swift
VibeNotify.builder()
    .title("Focus Mode Active")
    .message("Notifications are paused. Click anywhere to dismiss.")
    .icon(.success)
    .position(.center)
    .width(500)
    .height(250)
    .screenBlur(true, intensity: .heavy)
    .dismissOnScreenTap(true)
    .transparent(true, material: .hudWindow)
    .windowOpacity(0.95)
    .show()
```

### Example 8: Light Blur Overlay

```swift
VibeNotify.builder()
    .title("Quick Tip")
    .message("Background is subtly blurred")
    .icon(.info)
    .position(.center)
    .width(400)
    .height(200)
    .screenBlur(true, intensity: .light)
    .autoDismiss(after: 4.0, showProgress: true)
    .show()
```

---

## Best Practices

### 1. Choose the Right Approach

**Use Builder API for:**
- Complex configurations
- Multiple options
- Readable, maintainable code
- Most production use cases

**Use Convenience Methods for:**
- Quick alerts
- Simple notifications
- Prototyping

### 2. Positioning Strategy

- **`.center`** - Critical alerts, confirmations
- **`.top` / `.bottom`** - Status messages, banners
- **`.topRight` / `.bottomRight`** - Non-intrusive notifications
- **`.topLeft` / `.bottomLeft`** - Persistent indicators

### 3. Transparency & Blur

- Use `.transparent(true)` for elegant, modern look
- Combine with `.screenBlur(true)` for modal dialogs
- Adjust `.windowOpacity()` for subtle effects
- Match material to your app's design language

### 4. Moveable Windows

- Enable for non-critical, informational notifications
- Provide sufficient size (min 300x150) for dragging
- Consider starting position carefully
- **Not reachable on a rich alert.** Neither `AlertMode` factory sets
  `isMoveable`, so `.moveable(true)` on a builder that routes rich is ignored
  ([#3](https://github.com/vibecare-io/vibe-notify-macos/issues/3))

### 5. Auto-Dismiss

- **Success**: 3-5 seconds
- **Info**: 4-6 seconds
- **Warning**: 5-8 seconds
- **Error**: Manual dismiss (buttons)
- Enable an indicator (`showProgress: true`, i.e. `DismissIndicator.bar`) for clarity
- **A break countdown is not an auto-dismiss.** Use `TaskTimer` — it is the
  number the user is meant to read, and setting both makes them sequential
  phases totalling `duration + delay`, not a race. See [Countdowns](#countdowns).

---

## Troubleshooting

### Keyboard Input Not Working

If keyboard input goes to terminal instead of the app when using `swift run`:

```swift
// Already fixed in demo app with AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
```

### Notification Not Appearing

- Check window level: try `.windowLevel(.screenSaver)`
- Verify presentation mode or position is correct
- Ensure main thread: all APIs are `@MainActor`

### SVG Not Rendering

- Use absolute file paths
- Verify file exists at the specified path
- Check SVG is valid and not corrupted

### Transparent Background Not Showing

- Confirm `transparent: true` is set
- Try different materials (`.hudWindow`, `.popover`, etc.)
- Ensure background isn't being overridden

---

## Demo Application

The included demo app showcases all features:

```bash
cd VibeNotifyDemo
swift run
```

**Features:**
- 📚 Topic-based exploration
- ⚡️ Quick Start presets
- 🎨 Live customization
- 💻 Generated code examples
- ⌨️ Keyboard shortcuts (⌘P to preview, ⌘D to dismiss all)

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details.

## Credits

Inspired by:
- [swiftDialog](https://github.com/swiftDialog/swiftDialog)
- [SVGView](https://github.com/exyte/SVGView)

Built with ❤️ for the macOS developer community
