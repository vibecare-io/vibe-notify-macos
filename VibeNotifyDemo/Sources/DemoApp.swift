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
  @State private var illustration: RichDemoPresenter.IllustrationChoice = .svg
  @State private var flagshipDuration: Double = 15
  @State private var dismissOnScreenTap = true

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
        flagshipSection

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

  private var flagshipSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("3. Flagship: .interrupt — the 20-20-20 eye break").font(.headline)
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

  private var completionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("4. Completion states, on demand").font(.headline)
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
      Text("5. .ambient — corner toast, feathered scrim").font(.headline)
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
      Text("6. Accessibility overrides").font(.headline)
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
