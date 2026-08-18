import AppKit
import SwiftUI
import VibeNotify

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.setActivationPolicy(.regular)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let window = NSApp.windows.first {
        // One step above `BackdropWindowController.level`, itself one step
        // above every ordinary window: without this the control panel sits
        // at the plain `.normal` every other app window uses, and the
        // backdrop — which has to render above *those* to stand in for a
        // real desktop — would cover the panel too. See the level comment on
        // `BackdropWindowController` for the full stacking order.
        window.level = NSWindow.Level(rawValue: BackdropWindowController.level.rawValue + 1)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        NSApp.activate(ignoringOtherApps: true)
      }
    }
  }
}

@main
struct VibeNotifyRichDemoApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      DemoContentView()
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
    .windowResizability(.contentSize)
  }
}

// MARK: - Appearance override

/// Drives `NSApp.appearance`. `.system` passes `nil`, which is the documented
/// way to hand control back to the OS default; the whole point of this picker
/// is letting a reviewer flip between light and dark *without* having to leave
/// the app and touch System Settings, since the one claim under test — that
/// `RichNotificationView` ignores `colorScheme` entirely and renders the same
/// light-on-dark-scrim text either way — is exactly the thing that has to be
/// checked in both.
enum AppearanceOverride: String, CaseIterable, Identifiable {
  case system = "System"
  case light = "Light"
  case dark = "Dark"

  var id: String { rawValue }

  @MainActor
  func apply() {
    switch self {
    case .system: NSApp.appearance = nil
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }
}

/// Three-state override for the two accessibility settings `RichNotificationView`
/// reads. `.useSystem` passes `nil` through to the view, which then falls back
/// to the live `NSWorkspace` value; `.forceOn`/`.forceOff` let a reviewer
/// exercise both specified branches (feathered vs. solid scrim, spring vs.
/// static entrance) without changing an actual System Settings toggle.
enum OverrideState: String, CaseIterable, Identifiable {
  case useSystem = "System"
  case forceOn = "Force On"
  case forceOff = "Force Off"

  var id: String { rawValue }

  var resolved: Bool? {
    switch self {
    case .useSystem: return nil
    case .forceOn: return true
    case .forceOff: return false
    }
  }
}

// MARK: - Backdrop controller

@MainActor
final class BackdropController: ObservableObject {
  @Published var pattern: BackdropPattern = .splitBlackWhite {
    didSet { apply() }
  }

  private let windowController = BackdropWindowController()

  init() {
    apply()
  }

  func apply() {
    guard let screen = NSScreen.main else { return }
    windowController.show(pattern, on: screen)
  }
}

// MARK: - Main demo view

struct DemoContentView: View {
  @StateObject private var backdrop = BackdropController()
  @StateObject private var presenter = RichDemoPresenter()

  @State private var appearance: AppearanceOverride = .system

  // Flagship interrupt controls
  @State private var breakBackdrop: BackdropStyle = .blurredDesktop
  @State private var illustration: RichDemoPresenter.IllustrationChoice = .svg
  @State private var flagshipDuration: Double = 15
  @State private var dismissOnScreenTap = true

  // Web panel. The default URL is a YouTube *embed* path rather than a
  // `watch?v=` one: a watch URL loads the whole site chrome, which in a
  // 60%-of-screen column is a page about a video instead of a video.
  @State private var webURL = "https://www.youtube.com/embed/inpok4MKVLM"
  @State private var webPlacement: WebPanel.Placement = .leading
  @State private var webWidthFraction: Double = 0.64
  @State private var webAutoplay = false
  @State private var webDuration: Double = 20

  // Ambient controls
  @State private var ambientPosition: OverlayWindowManager.WindowPosition = .bottomRight
  @State private var ambientIndicator: DismissIndicator = .bar
  @State private var ambientDismissDelay: Double = 8

  // Accessibility overrides
  @State private var reduceMotion: OverrideState = .useSystem
  @State private var reduceTransparency: OverrideState = .useSystem

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header

        Divider()
        backdropSection

        Divider()
        appearanceSection

        Divider()
        breakBackdropSection

        Divider()
        flagshipSection

        Divider()
        webPanelSection

        Divider()
        completionSection

        Divider()
        ambientSection

        Divider()
        accessibilitySection

        Divider()
        activeAlertsSection
      }
      .padding(28)
    }
    .frame(minWidth: 560, idealWidth: 620, minHeight: 700, idealHeight: 900)
  }

  // MARK: - Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("VibeNotify — Rich Renderer Demo")
        .font(.title)
        .fontWeight(.bold)
      Text(
        "Everything here drives RichNotificationView, the new third renderer. Pick a hostile backdrop below, then trigger a scenario — the alert appears above this panel, and the backdrop sits behind both."
      )
      .font(.subheadline)
      .foregroundColor(.secondary)
    }
  }

  private var backdropSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("1. Hostile Backdrop").font(.headline)
      Picker("Backdrop", selection: $backdrop.pattern) {
        ForEach(BackdropPattern.allCases) { pattern in
          Text(pattern.rawValue).tag(pattern)
        }
      }
      .labelsHidden()
      Text(backdrop.pattern.summary)
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var appearanceSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("2. System Appearance").font(.headline)
      Picker("Appearance", selection: $appearance) {
        ForEach(AppearanceOverride.allCases) { option in
          Text(option.rawValue).tag(option)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .onChange(of: appearance) { _, newValue in newValue.apply() }
      Text(
        "RichNotificationView deliberately ignores colorScheme — both modes render light text on a dark scrim in both appearances. Flip this and re-run a scenario to confirm nothing changes."
      )
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }

  /// The user-facing backdrop choice, next to the *hostile* backdrop picker on
  /// purpose: the two answer different questions ("what is behind the alert if
  /// the user picked nothing" vs. "what is on the reviewer's desktop"), and the
  /// only way to see that a painted backdrop hides the desktop outright is to
  /// pick a violent pattern above and watch it vanish.
  ///
  /// The luminance readout is not decoration. It is the legibility rule, read
  /// back out of the shipped value through the same `Legibility` functions that
  /// enforce it, so a preset that drifted over the cap would say so here rather
  /// than needing to be noticed as "hmm, that looks a bit bright".
  private var breakBackdropSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("3. Break backdrop (the user's choice)").font(.headline)
      Picker("Break backdrop", selection: $breakBackdrop) {
        ForEach(BackdropStyle.allCases) { style in
          Text(style.displayName).tag(style)
        }
      }
      .labelsHidden()

      if let fill = breakBackdrop.fill {
        HStack(spacing: 10) {
          RoundedRectangle(cornerRadius: 5)
            .fill(
              LinearGradient(
                colors: fill.stops.map(\.color), startPoint: .topLeading,
                endPoint: .bottomTrailing)
            )
            .frame(width: 64, height: 22)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.secondary.opacity(0.35)))
          Text(
            String(
              format: "peak luminance %.4f / cap %.4f — %@", fill.peakLuminance,
              Legibility.maxSafeLuminance,
              fill.peakLuminance <= Legibility.maxSafeLuminance ? "safe" : "OVER CAP")
          )
          .font(.caption)
          .monospacedDigit()
          .foregroundColor(
            fill.peakLuminance <= Legibility.maxSafeLuminance ? .secondary : .red)
        }
      } else {
        Text(
          String(
            format: "Unknown surface — bounded by dim instead: %.2f (Legibility.safeDim).",
            Legibility.safeDim)
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
    }
  }

  private var flagshipSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("4. Flagship: .interrupt — the 20-20-20 eye break").font(.headline)
      Text(
        "Illustration, title, message, a running task timer with its ring, Done / Snooze / Skip, and a footnote. Judge legibility where the title/message cross the backdrop's black/white seam."
      )
      .font(.caption)
      .foregroundColor(.secondary)

      Picker("Illustration", selection: $illustration) {
        ForEach(RichDemoPresenter.IllustrationChoice.allCases) { choice in
          Text(choice.rawValue).tag(choice)
        }
      }

      HStack {
        Text("Duration: \(Int(flagshipDuration))s")
        Slider(value: $flagshipDuration, in: 4...20, step: 1)
      }

      Toggle("Dismiss on screen tap", isOn: $dismissOnScreenTap)

      Button {
        presenter.showFlagshipInterrupt(
          duration: flagshipDuration,
          illustration: illustration,
          dismissOnScreenTap: dismissOnScreenTap,
          backdropStyle: breakBackdrop,
          reduceMotion: reduceMotion.resolved,
          reduceTransparency: reduceTransparency.resolved,
          screen: .main)
      } label: {
        Label("Show Interrupt", systemImage: "eye.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
  }

  private var webPanelSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("5. Web panel — a break you can play, watch or read").font(.headline)
      Text(
        "A live page in one column, the usual rail in the other. Judge whether the ring and the buttons still read beside a bright, arbitrary rectangle — and note that clicking the panel does not dismiss the alert, which is deliberate."
      )
      .font(.caption)
      .foregroundColor(.secondary)

      TextField("URL", text: $webURL)
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))

      Picker("Web column", selection: $webPlacement) {
        Text("Leading").tag(WebPanel.Placement.leading)
        Text("Trailing").tag(WebPanel.Placement.trailing)
      }
      .pickerStyle(.segmented)

      HStack {
        Text("Width: \(Int(webWidthFraction * 100))%")
        Slider(value: $webWidthFraction, in: 0.3...0.85, step: 0.01)
      }

      HStack {
        Text("Duration: \(Int(webDuration))s")
        Slider(value: $webDuration, in: 5...60, step: 1)
      }

      Toggle("Allow media autoplay", isOn: $webAutoplay)

      Button {
        guard let url = URL(string: webURL) else { return }
        presenter.showWebPanel(
          url: url,
          placement: webPlacement,
          widthFraction: webWidthFraction,
          allowsAutoplay: webAutoplay,
          duration: webDuration,
          backdropStyle: breakBackdrop,
          reduceMotion: reduceMotion.resolved,
          reduceTransparency: reduceTransparency.resolved,
          screen: .main)
      } label: {
        Label("Show Web Panel", systemImage: "play.rectangle.on.rectangle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(URL(string: webURL) == nil)
    }
  }

  private var completionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("6. Completion states, on demand").font(.headline)
      Text(
        "Both use a short 4s timer so you don't have to wait. Let it run to zero for \"Break complete\" with the check glyph and green stroke; press Done immediately for \"Got it\" — acknowledged, not claimed complete."
      )
      .font(.caption)
      .foregroundColor(.secondary)

      HStack(spacing: 12) {
        Button {
          presenter.showFlagshipInterrupt(
            duration: 4,
            illustration: illustration,
            dismissOnScreenTap: false,
            backdropStyle: breakBackdrop,
            reduceMotion: reduceMotion.resolved,
            reduceTransparency: reduceTransparency.resolved,
            screen: .main)
        } label: {
          Label("Let it finish (watch to 0)", systemImage: "checkmark.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button {
          presenter.showFlagshipInterrupt(
            duration: 4,
            illustration: illustration,
            dismissOnScreenTap: false,
            backdropStyle: breakBackdrop,
            reduceMotion: reduceMotion.resolved,
            reduceTransparency: reduceTransparency.resolved,
            screen: .main)
        } label: {
          Label("Press Done yourself", systemImage: "hand.tap")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var ambientSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("7. .ambient — corner toast, feathered scrim").font(.headline)
      Text(
        "Multi-line message of varying width, the hardest case for the scrim: its ellipse must reach zero alpha *inside* its own rect. Judge whether you can see a rectangular edge — you should not."
      )
      .font(.caption)
      .foregroundColor(.secondary)

      Picker("Corner", selection: $ambientPosition) {
        Text("Top Left").tag(OverlayWindowManager.WindowPosition.topLeft)
        Text("Top Right").tag(OverlayWindowManager.WindowPosition.topRight)
        Text("Bottom Left").tag(OverlayWindowManager.WindowPosition.bottomLeft)
        Text("Bottom Right").tag(OverlayWindowManager.WindowPosition.bottomRight)
      }
      .pickerStyle(.segmented)

      Picker("Dismiss indicator", selection: $ambientIndicator) {
        Text("Bar").tag(DismissIndicator.bar)
        Text("Hairline Ring").tag(DismissIndicator.hairlineRing)
        Text("None").tag(DismissIndicator.none)
      }
      .pickerStyle(.segmented)

      HStack {
        Text("Auto-dismiss: \(Int(ambientDismissDelay))s")
        Slider(value: $ambientDismissDelay, in: 3...15, step: 1)
      }

      Button {
        presenter.showAmbient(
          position: ambientPosition,
          indicator: ambientIndicator,
          dismissDelay: ambientDismissDelay,
          reduceMotion: reduceMotion.resolved,
          reduceTransparency: reduceTransparency.resolved,
          screen: .main)
      } label: {
        Label("Show Ambient", systemImage: "bell.badge")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
  }

  private var accessibilitySection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("8. Accessibility overrides").font(.headline)
      Text(
        "Overrides passed straight into RichNotificationView's init — no need to touch System Settings. \"System\" reads the live NSWorkspace value instead."
      )
      .font(.caption)
      .foregroundColor(.secondary)

      HStack {
        Text("Reduce Motion").frame(width: 140, alignment: .leading)
        Picker("Reduce Motion", selection: $reduceMotion) {
          ForEach(OverrideState.allCases) { state in
            Text(state.rawValue).tag(state)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      HStack {
        Text("Reduce Transparency").frame(width: 140, alignment: .leading)
        Picker("Reduce Transparency", selection: $reduceTransparency) {
          ForEach(OverrideState.allCases) { state in
            Text(state.rawValue).tag(state)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
      Text(
        "Force Reduce Transparency on to see the solid-backdrop fallback (.interrupt: opaque black; .ambient: SolidBackdrop) in place of the blur/feathered scrim."
      )
      .font(.caption2)
      .foregroundColor(.secondary)
    }
  }

  private var activeAlertsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Active alerts: \(presenter.activeIDs.count)")
        .font(.headline)
      Button(role: .destructive) {
        presenter.dismissAll()
      } label: {
        Label("Dismiss All", systemImage: "xmark.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
      .keyboardShortcut("d", modifiers: .command)
    }
  }
}

#Preview {
  DemoContentView()
}
