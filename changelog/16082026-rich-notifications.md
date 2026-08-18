# Rich Notifications, Countdowns and Legibility

**Date:** August 16, 2026
**Type:** Feature Release
**Breaking Changes:** None — strictly additive

## Summary

A third content model and renderer, `RichNotification` / `RichNotificationView`,
added beside `StandardNotification` and `SVGNotification`. Neither existing
model changes and neither existing renderer changes. With it: a countdown engine
the library owns, an `AlertMode` axis above the raw window geometry, and a set
of legibility rules that are functions returning values rather than decisions
buried in view bodies.

The one bug this release fixes outright: **`.svg(…).button(…)` used to compile
and silently discard every button.** `NotificationBuilder.show()` forked on
`useSVG` before buttons entered the picture, and `SVGNotification` has no
`buttons` property that could have accepted one. That combination now routes to
the rich renderer and draws the buttons.

## Additive

### `RichNotification`

An illustration, a title, a message, a footnote, a row of buttons, a task timer
and an auto-dismiss on one surface — the combination neither older model can
express. No card, no panel, no border: content sits directly on the scrim.

- `Illustration` — `.svg(SVGSource, size:)`, `.image(NSImage, size:)`,
  `.symbol(String, pointSize:, color:)`. Size lives *inside* each case: an SF
  Symbol is sized by a point size and a bitmap by a `CGSize`, and one shared
  `CGSize` would force a caller to encode a font size as a square rectangle.
- `fitted(in:)` scales an oversized illustration **down** rather than letting it
  evict the rest of the alert. Clipping alone was not enough: a 600×500 image in
  a 380×210 window pushed everything else outside the clip and the measured
  result was zero inked pixels — an empty alert, not a truncated one. It never
  scales *up*; a 40pt symbol stays 40pt on a 5K display.
- `artworkTone` defaults to `.automatic`, which rasterises the artwork once and
  measures the alpha-weighted mean luminance of its inked pixels. Dark artwork
  gets a light halo, light artwork a dark shadow. The renderer previously gave
  *every* illustration a dark drop shadow, which is correct for white line art
  and exactly wrong for a black-filled silhouette on a dimmed desktop.
- `completionState(phase:didCompleteTask:completedEarly:)` — ran to zero says
  "Break complete", Done pressed early says "Got it", and Skip/ESC/click-away/a
  deadline slept through say nothing at all. A surface claiming a completed
  break when seventeen of twenty seconds were skipped is telling the user
  something false about their own health.

### `VibeNotify.showRich(_:configuration:reduceMotion:reduceTransparency:onEnd:)`

The entry point that was missing: every call site wanting the rich renderer —
including this library's own demo harness and tests — had to reach past
`VibeNotify` and call `OverlayWindowManager.show(…)` directly.

`onEnd` fires exactly once however the overlay closes, including the case that
previously had no signal at all: a clock reaching its own deadline tears the
window down through `clockDidEnd`, which never runs the `onDismiss` closure
baked into the hosted view.

### `AlertMode` and the configuration factories

`AlertMode` is presentation *intent* above `PresentationMode`'s geometry, and it
bundles the ~20 `Configuration` knobs that are only ever correct together:

- `Configuration.interrupt(dismissOnScreenTap:animatePresentation:screen:backdropStyle:)`
- `Configuration.ambient(position:width:height:dismissOnScreenTap:animatePresentation:screen:)`

`.ambient` requires `width`/`height` rather than defaulting them: leaving both
nil produces a transparent window the size of the screen, swallowing every click
on the display. `.interrupt` takes key focus so ESC works without a prior click;
`.ambient` deliberately does not, because a toast that steals focus mid-keystroke
is the failure that mode exists to avoid.

**Known gap:** neither factory reaches `isMoveable`, and `interrupt(…)`
hardcodes `screenBlurIntensity` to `.heavy`, silently overriding a caller's
choice. Tracked as [#3](https://github.com/vibecare-io/vibe-notify-macos/issues/3).

### `NotificationClock`

One cancellable clock per overlay, owned by `OverlayWindowManager` and keyed by
the same id as its window. Replaces a bare `DispatchQueue.main.asyncAfter` living
inside each renderer's view body, which had three defects at once: no
cancellation handle, duplicated byte-identically in two renderers, and no timer
at all for caller-supplied SwiftUI content.

- Phases `.task` → `.dismissing` → `.finished` / `.cancelled`.
- `deadline` is a wall-clock `Date`, not a duration. `asyncAfter` across a system
  sleep is not a contract worth relying on. A wake with the deadline already
  behind us voids a task outright — the conservative side wins on purpose.
- Injected into the SwiftUI environment as `\.notificationClock`, so
  caller-supplied content inherits a countdown without asking for one. Reading it
  gets the *reference*, not the redraws — anything drawing the countdown must
  hand it to a child holding it as `@ObservedObject`.

### The countdown split

`TaskTimer` is the large labelled ring counting an exercise the user is meant to
read; `DismissIndicator` (`.none` / `.bar` / `.hairlineRing`) is the quiet "this
closes in N". Set both and they run as **sequential phases**, total
`duration + delay` — never a race. Earliest-deadline-wins was considered and
rejected: it lets a habitual 5-second auto-dismiss silently kill a 20-second eye
break at second five.

A task timer suppresses the dismiss indicator while it runs. There is exactly one
number on screen at a time, and it is the one the user is meant to obey.

`.ambient` never draws a task ring — a labelled ring reads as a task, and ambient
alerts have none. Enforced in `RichNotification.effectiveTaskTimer` rather than
in the renderer, so the clock cannot run a phase nothing explains.

### `Legibility`

Every "will this be readable?" decision, as pure functions of their inputs. The
bug that started this work was a rendering decision buried in a view body —
`SVGNotificationView` defines `useLightText` as `colorScheme == .dark`, which is
unassertable without a screen and therefore survived five releases.

The invariant: *text is never rendered over a backdrop whose luminance we do not
control.* `Legibility.safeDim` (0.55) is derived once and used in three places;
`scrimStrategy(effectiveDim:reduceTransparency:)` decides whether the renderer
draws its own local scrim, keyed on the dim rather than on a blur flag.

Reduce Motion and Reduce Transparency are both honoured. The countdown keeps
animating under Reduce Motion — it is information the user is reading, not
decoration — and only its cadence changes, to discrete one-second steps.

### `BackdropStyle` and `screenDim`

A break alert can now replace the desktop rather than only dim it: seven fixed
options — the blurred desktop (the default and unchanged behaviour), three
solids, three gradients. Staring at your own blurred work for twenty seconds is
not restful.

Every `BackdropFill.Stop` is luminance-capped in its initializer, so a pale
solid or a light gradient is not "a bad idea we chose not to offer" — it is
unconstructible. Not a colour picker: a free colour well is the API that would
need a runtime "your choice is illegible" error.

`Configuration.screenDim` makes the backdrop opacity a parameter, clamped to
`0.1...0.95`, independent of blur radius. Radius controls how much of the
desktop's *detail* survives; dim controls how much of its *light* does.

## Deprecated

Marked, not removed. All still compile and behave exactly as before.

| Deprecated | Replacement |
|---|---|
| `SVGNotification` | `RichNotification` with an `.svg` illustration |
| `VibeNotify.showSVG(svgPath:…)` / `showSVG(svgURL:…)` | `VibeNotify.showRich(_:configuration:)` |
| `AutoDismiss.init(delay:showProgress:)` | `AutoDismiss.init(delay:indicator:)` — `true` → `.bar`, `false` → `.none` |
| `NotificationBuilder.autoDismiss(after:showProgress:)` | none yet; see below |

`SVGNotification` is deprecated rather than made to assert: an
`assertionFailure` compiles away in release builds, which would silently resume
swallowing a caller's `buttons:` in exactly the configuration where it matters.

The builder's `autoDismiss(after:showProgress:)` is deprecated but **not
replaced** — a second defaulted-second-parameter overload of the same base name
would make every existing call site that omits both trailing arguments
ambiguous. It remains the builder's only auto-dismiss entry point. A
non-ambiguous `indicator:` entry point is follow-up work.

`AutoDismiss.showProgress` survives as a read-only shim, `true` only for `.bar`,
so both older renderers stay byte-identical while the storage underneath is now
`indicator`.

## Compatibility

Strictly additive, verified by compiling an unmodified consumer against it: a
package whose only source is the 0.0.5 call sites copied out of the previous
README and DOCS — the builder, `showSVG` both ways, `showCustom`, a hand-written
memberwise `Configuration`, and both `AutoDismiss` call shapes — builds clean
against HEAD. The only diagnostics are deprecation warnings on `showSVG(…)` and
`AutoDismiss(delay:showProgress:)`. No errors, no ambiguity.

The only public declarations that changed at all, rather than being added:
`AutoDismiss.showProgress` became a computed shim over `indicator`,
`AutoDismiss` gained `Sendable`, and `init(delay:showProgress:)` lost its
`= false` default — which is source-compatible because `init(delay:indicator:)`
now owns the single-argument `AutoDismiss(delay:)` shape with an identical
result. Defaulting it on both would have made that call ambiguous.

Every existing call site keeps its behaviour:

- `.svg(path).show()` renders exactly as it did in 0.0.5. Opting into the new
  renderer for an SVG-only alert takes one explicit `.mode(…)` call — which is
  why "any explicitly set mode routes rich" is a rule, rather than routing on
  the presence of an illustration alone.
- `Configuration`'s new fields (`screenDim`, `takesKeyFocus`, `backdropStyle`)
  are all defaulted to the pre-existing behaviour, so every `Configuration`
  written before they existed produces the same window.
- `OverlayWindowManager.show`'s new `countdown:` and `onEnd:` parameters default
  to `nil`.
- `backdropStyle` defaults to `.blurredDesktop`, byte for byte what every alert
  drew before the type existed.

## Files Added

- `Sources/VibeNotify/Models/RichNotification.swift`
- `Sources/VibeNotify/Models/AlertMode.swift`
- `Sources/VibeNotify/Models/BackdropStyle.swift`
- `Sources/VibeNotify/Models/Legibility.swift`
- `Sources/VibeNotify/Models/RichMetrics.swift`
- `Sources/VibeNotify/Core/NotificationClock.swift`
- `Sources/VibeNotify/Views/RichNotificationView.swift`
- `Sources/VibeNotify/Views/CountdownRing.swift`
- `Sources/VibeNotify/Views/IllustrationHalo.swift`
- `Sources/VibeNotify/Views/RichButtonStyle.swift`
- `Sources/VibeNotify/Views/Scrim.swift`
- `Tests/VibeNotifyTests/` — routing, legibility, clock, configuration and
  overlay lifetime
- `VibeNotifyDemo/` — a visual harness for the rich renderer

## Files Modified

- `Sources/VibeNotify/API/VibeNotify.swift` — `showRich`, the rich builder
  methods, the routing rule in `show()`
- `Sources/VibeNotify/Core/OverlayWindowManager.swift` — clock ownership, end
  handlers, `screenDim` / `takesKeyFocus` / `backdropStyle`
- `Sources/VibeNotify/Models/NotificationContent.swift` — `TaskTimer`,
  `DismissIndicator`, `Countdown`, `AutoDismiss.indicator`, deprecations
