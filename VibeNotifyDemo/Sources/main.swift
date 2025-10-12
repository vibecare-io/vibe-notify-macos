import AppKit
import SwiftUI
import VibeNotify
import UniformTypeIdentifiers

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Activate the app to bring it to the foreground and accept keyboard input
    NSApp.activate(ignoringOtherApps: true)

    // Set activation policy to regular app (shows in Dock and can be focused)
    NSApp.setActivationPolicy(.regular)

    // Make sure the main window is key and front
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let window = NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        NSApp.activate(ignoringOtherApps: true)
      }
    }
  }
}

@main
struct VibeNotifyDemoApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      DemoContentView()
        .onAppear {
          // Additional activation when the view appears
          NSApp.activate(ignoringOtherApps: true)
        }
    }
  }
}

// MARK: - Topic Model
enum DemoTopic: String, CaseIterable, Identifiable {
  case quickStart = "Quick Start"
  case basicTypes = "Basic Types"
  case presentationModes = "Presentation Modes"
  case positioning = "Positioning"
  case transparency = "Transparency"
  case screenBlur = "Screen Blur"
  case customization = "Customization"
  case media = "Media & Images"
  case builderAPI = "Builder API"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .quickStart: return "star.fill"
    case .basicTypes: return "bell.badge"
    case .presentationModes: return "rectangle.3.group"
    case .positioning: return "target"
    case .transparency: return "aqi.medium"
    case .screenBlur: return "circle.hexagongrid.fill"
    case .customization: return "slider.horizontal.3"
    case .media: return "photo.on.rectangle.angled"
    case .builderAPI: return "hammer.fill"
    }
  }

  var description: String {
    switch self {
    case .quickStart:
      return "Common patterns and quick examples"
    case .basicTypes:
      return "Success, Error, Warning, Info notifications"
    case .presentationModes:
      return "Full Screen, Banner, Toast presentations"
    case .positioning:
      return "9 predefined window positions"
    case .transparency:
      return "Transparent backgrounds with materials"
    case .screenBlur:
      return "Full screen blur effects"
    case .customization:
      return "Size, moveable, buttons, opacity"
    case .media:
      return "SVG images and custom icons"
    case .builderAPI:
      return "Declarative builder pattern API"
    }
  }
}

// MARK: - Notification Presets
enum NotificationPreset: String, CaseIterable, Identifiable {
  case successToast = "Success Toast"
  case errorModal = "Error Modal"
  case warningBanner = "Warning Banner"
  case blurredCenter = "Blurred Center"
  case transparentFloat = "Transparent Floating"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .successToast: return "checkmark.circle.fill"
    case .errorModal: return "xmark.circle.fill"
    case .warningBanner: return "exclamationmark.triangle.fill"
    case .blurredCenter: return "circle.hexagongrid.fill"
    case .transparentFloat: return "aqi.medium"
    }
  }
}

// MARK: - Configuration State
class NotificationConfig: ObservableObject {
  // Basic
  @Published var notificationType: NotificationType = .success
  @Published var title: String = "Notification Title"
  @Published var message: String = "This is a notification message"

  // Presentation
  @Published var presentationMode: PresentationMode = .banner
  @Published var position: OverlayWindowManager.WindowPosition = .center

  // Transparency
  @Published var transparent: Bool = false
  @Published var transparentMaterial: NSVisualEffectView.Material = .hudWindow

  // Screen Blur
  @Published var screenBlur: Bool = false
  @Published var screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground
  @Published var dismissOnScreenTap: Bool = false

  // Customization
  @Published var width: CGFloat = 400
  @Published var height: CGFloat = 200
  @Published var moveable: Bool = false
  @Published var windowOpacity: CGFloat = 1.0
  @Published var autoDismiss: Bool = false
  @Published var autoDismissDelay: Double = 3.0
  @Published var showProgress: Bool = false
  @Published var addButtons: Bool = false

  // Media
  @Published var useCustomMedia: Bool = false
  @Published var mediaPath: String? = nil
  @Published var mediaType: MediaType = .svg
  @Published var mediaSize: CGSize = CGSize(width: 200, height: 200)
  @Published var useSVGNotification: Bool = false
  @Published var svgInteractive: Bool = false

  enum MediaType: String, CaseIterable {
    case svg = "SVG"
    case png = "PNG/JPG"

    var fileExtensions: [String] {
      switch self {
      case .svg: return ["svg"]
      case .png: return ["png", "jpg", "jpeg"]
      }
    }
  }

  enum NotificationType: String, CaseIterable {
    case success = "Success"
    case error = "Error"
    case warning = "Warning"
    case info = "Info"

    var icon: StandardNotification.IconType {
      switch self {
      case .success: return .success
      case .error: return .error
      case .warning: return .warning
      case .info: return .info
      }
    }
  }

  enum PresentationMode: String, CaseIterable {
    case fullScreen = "Full Screen"
    case banner = "Banner"
    case toast = "Toast"
    case custom = "Custom Position"

    func toOverlayMode() -> OverlayWindowManager.PresentationMode {
      switch self {
      case .fullScreen: return .fullScreen
      case .banner: return .banner(edge: .top, height: 120)
      case .toast: return .toast(corner: .topRight, size: CGSize(width: 300, height: 150))
      case .custom: return .custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300))
      }
    }
  }

  func generateCode() -> String {
    // Handle SVG full notification
    if useSVGNotification, let svgPath = mediaPath, mediaType == .svg {
      var code = "VibeNotify.shared.showSVG(\n"
      code += "  svgPath: \"\(svgPath)\",\n"
      code += "  title: \"\(title)\",\n"
      code += "  message: \"\(message)\",\n"
      code += "  svgSize: CGSize(width: \(Int(mediaSize.width)), height: \(Int(mediaSize.height)))"

      if svgInteractive {
        code += ",\n  interactive: true"
      }

      if presentationMode == .custom {
        code += ",\n  presentationMode: .custom(frame: CGRect(x: 100, y: 100, width: \(Int(width)), height: \(Int(height))))"
      } else {
        code += ",\n  presentationMode: \(presentationModeCode())"
      }

      if moveable {
        code += ",\n  moveable: true"
      }

      if transparent {
        code += ",\n  transparent: true"
        code += ",\n  transparentMaterial: .\(materialName(transparentMaterial))"
      }

      if screenBlur {
        code += ",\n  screenBlur: true"
        code += ",\n  screenBlurMaterial: .\(materialName(screenBlurMaterial))"
        if dismissOnScreenTap {
          code += ",\n  dismissOnScreenTap: true"
        }
      }

      code += "\n)"
      return code
    }

    var code = "VibeNotify.shared.show(\n"
    code += "  title: \"\(title)\",\n"
    code += "  message: \"\(message)\",\n"

    // Icon handling
    if useCustomMedia, let path = mediaPath {
      if mediaType == .svg {
        code += "  icon: .svg(\"\(path)\")"
      } else {
        code += "  icon: .image(NSImage(contentsOfFile: \"\(path)\")!)"
      }
    } else {
      code += "  icon: .\(notificationType.rawValue.lowercased())"
    }

    if transparent {
      code += ",\n  transparent: true"
      code += ",\n  transparentMaterial: .\(materialName(transparentMaterial))"
    }

    if screenBlur {
      code += ",\n  screenBlur: true"
      code += ",\n  screenBlurMaterial: .\(materialName(screenBlurMaterial))"
      if dismissOnScreenTap {
        code += ",\n  dismissOnScreenTap: true"
      }
    }

    if presentationMode == .custom {
      code += ",\n  position: .\(positionName(position))"
      code += ",\n  width: \(Int(width))"
      code += ",\n  height: \(Int(height))"
    } else {
      code += ",\n  presentationMode: \(presentationModeCode())"
    }

    if moveable {
      code += ",\n  moveable: true"
    }

    if windowOpacity < 1.0 {
      code += ",\n  windowOpacity: \(String(format: "%.2f", windowOpacity))"
    }

    if autoDismiss {
      code += ",\n  autoDismiss: StandardNotification.AutoDismiss(\n"
      code += "    delay: \(String(format: "%.1f", autoDismissDelay))"
      if showProgress {
        code += ",\n    showProgress: true"
      }
      code += "\n  )"
    }

    if addButtons {
      code += ",\n  buttons: [\n"
      code += "    StandardNotification.Button(\n"
      code += "      title: \"Confirm\",\n"
      code += "      style: .primary\n"
      code += "    ) {\n"
      code += "      print(\"Confirmed!\")\n"
      code += "    },\n"
      code += "    StandardNotification.Button(\n"
      code += "      title: \"Cancel\",\n"
      code += "      style: .secondary\n"
      code += "    ) {\n"
      code += "      print(\"Cancelled\")\n"
      code += "    }\n"
      code += "  ]"
    }

    code += "\n)"
    return code
  }

  func generateBuilderCode() -> String {
    var code = "VibeNotify.builder()\n"

    // Handle SVG mode
    if useSVGNotification || useCustomMedia, let path = mediaPath {
      if useSVGNotification && mediaType == .svg {
        code += "  .svg(\n"
        code += "    \"\(path)\",\n"
        code += "    size: CGSize(width: \(Int(mediaSize.width)), height: \(Int(mediaSize.height)))"
        if svgInteractive {
          code += ",\n    interactive: true"
        }
        code += "\n  )\n"
      } else if useCustomMedia {
        if mediaType == .svg {
          code += "  .icon(.svg(\"\(path)\"))\n"
        } else {
          code += "  .icon(.image(NSImage(contentsOfFile: \"\(path)\")!))\n"
        }
      }
    } else {
      code += "  .icon(.\(notificationType.rawValue.lowercased()))\n"
    }

    code += "  .title(\"\(title)\")\n"
    code += "  .message(\"\(message)\")\n"

    if transparent {
      code += "  .transparent(\n"
      code += "    true,\n"
      code += "    material: .\(materialName(transparentMaterial))\n"
      code += "  )\n"
    }

    if screenBlur {
      code += "  .screenBlur(\n"
      code += "    true,\n"
      code += "    material: .\(materialName(screenBlurMaterial))\n"
      code += "  )\n"
      if dismissOnScreenTap {
        code += "  .dismissOnScreenTap(true)\n"
      }
    }

    if presentationMode == .custom {
      code += "  .position(.\(positionName(position)))\n"
      code += "  .width(\(Int(width)))\n"
      code += "  .height(\(Int(height)))\n"
    } else {
      code += "  .presentationMode(\(presentationModeCode()))\n"
    }

    if moveable {
      code += "  .moveable(true)\n"
    }

    if windowOpacity < 1.0 {
      code += "  .windowOpacity(\(String(format: "%.2f", windowOpacity)))\n"
    }

    if autoDismiss {
      code += "  .autoDismiss(\n"
      code += "    after: \(String(format: "%.1f", autoDismissDelay))"
      if showProgress {
        code += ",\n    showProgress: true"
      }
      code += "\n  )\n"
    }

    if addButtons {
      code += "  .button(\n"
      code += "    StandardNotification.Button(\n"
      code += "      title: \"Confirm\",\n"
      code += "      style: .primary\n"
      code += "    ) {\n"
      code += "      print(\"Confirmed!\")\n"
      code += "    }\n"
      code += "  )\n"
      code += "  .button(\n"
      code += "    StandardNotification.Button(\n"
      code += "      title: \"Cancel\",\n"
      code += "      style: .secondary\n"
      code += "    ) {\n"
      code += "      print(\"Cancelled\")\n"
      code += "    }\n"
      code += "  )\n"
    }

    code += "  .show()"
    return code
  }

  private func materialName(_ material: NSVisualEffectView.Material) -> String {
    switch material {
    case .hudWindow: return "hudWindow"
    case .popover: return "popover"
    case .sidebar: return "sidebar"
    case .menu: return "menu"
    case .selection: return "selection"
    case .titlebar: return "titlebar"
    case .underWindowBackground: return "underWindowBackground"
    default: return "hudWindow"
    }
  }

  private func positionName(_ position: OverlayWindowManager.WindowPosition) -> String {
    switch position {
    case .topLeft: return "topLeft"
    case .top: return "top"
    case .topRight: return "topRight"
    case .left: return "left"
    case .center: return "center"
    case .right: return "right"
    case .bottomLeft: return "bottomLeft"
    case .bottom: return "bottom"
    case .bottomRight: return "bottomRight"
    }
  }

  private func presentationModeCode() -> String {
    switch presentationMode {
    case .fullScreen:
      return ".fullScreen"
    case .banner:
      return ".banner(edge: .top, height: 120)"
    case .toast:
      return ".toast(corner: .topRight, size: CGSize(width: 300, height: 150))"
    case .custom:
      return ".custom(frame: CGRect(x: 100, y: 100, width: 400, height: 300))"
    }
  }

  @MainActor
  func showNotification() {
    // Handle SVG full notification
    if useSVGNotification, let svgPath = mediaPath, mediaType == .svg {
      VibeNotify.shared.showSVG(
        svgPath: svgPath,
        title: title,
        message: message,
        svgSize: mediaSize,
        interactive: svgInteractive,
        presentationMode: presentationMode == .custom
          ? .custom(frame: CGRect(x: 100, y: 100, width: width, height: height))
          : presentationMode.toOverlayMode(),
        position: presentationMode == .custom ? position : nil,
        width: presentationMode == .custom ? width : nil,
        height: presentationMode == .custom ? height : nil,
        moveable: moveable,
        transparent: transparent,
        transparentMaterial: transparentMaterial,
        windowOpacity: windowOpacity,
        screenBlur: screenBlur,
        screenBlurMaterial: screenBlurMaterial,
        dismissOnScreenTap: dismissOnScreenTap
      )
      return
    }

    let buttons =
      addButtons
      ? [
        StandardNotification.Button(title: "Confirm", style: .primary) {
          print("Confirmed!")
        },
        StandardNotification.Button(title: "Cancel", style: .secondary) {
          print("Cancelled")
        },
      ] : []

    let autoDismissConfig =
      autoDismiss
      ? StandardNotification.AutoDismiss(delay: autoDismissDelay, showProgress: showProgress) : nil

    // Determine icon
    let iconToUse: StandardNotification.IconType
    if useCustomMedia, let path = mediaPath {
      if mediaType == .svg {
        iconToUse = .svg(path)
      } else if let nsImage = NSImage(contentsOfFile: path) {
        iconToUse = .image(nsImage)
      } else {
        iconToUse = notificationType.icon
      }
    } else {
      iconToUse = notificationType.icon
    }

    if presentationMode == .custom {
      VibeNotify.shared.show(
        title: title,
        message: message,
        icon: iconToUse,
        buttons: buttons,
        position: position,
        width: width,
        height: height,
        moveable: moveable,
        transparent: transparent,
        transparentMaterial: transparentMaterial,
        windowOpacity: windowOpacity,
        screenBlur: screenBlur,
        screenBlurMaterial: screenBlurMaterial,
        dismissOnScreenTap: dismissOnScreenTap,
        autoDismiss: autoDismissConfig
      )
    } else {
      VibeNotify.shared.show(
        title: title,
        message: message,
        icon: iconToUse,
        buttons: buttons,
        presentationMode: presentationMode.toOverlayMode(),
        moveable: moveable,
        transparent: transparent,
        transparentMaterial: transparentMaterial,
        windowOpacity: windowOpacity,
        screenBlur: screenBlur,
        screenBlurMaterial: screenBlurMaterial,
        dismissOnScreenTap: dismissOnScreenTap,
        autoDismiss: autoDismissConfig
      )
    }
  }

  func applyPreset(_ preset: NotificationPreset) {
    switch preset {
    case .successToast:
      notificationType = .success
      title = "Success!"
      message = "Operation completed successfully"
      presentationMode = .toast
      transparent = false
      screenBlur = false
      moveable = false
      autoDismiss = true
      autoDismissDelay = 3.0
      showProgress = true
      addButtons = false
      position = .center
      width = 350
      height = 200

    case .errorModal:
      notificationType = .error
      title = "Error Occurred"
      message = "Something went wrong. Please try again."
      presentationMode = .custom
      position = .center
      width = 450
      height = 250
      transparent = false
      screenBlur = true
      screenBlurMaterial = .underWindowBackground
      dismissOnScreenTap = false
      moveable = false
      autoDismiss = false
      addButtons = true

    case .warningBanner:
      notificationType = .warning
      title = "Warning"
      message = "Please review your settings before continuing"
      presentationMode = .banner
      transparent = false
      screenBlur = false
      moveable = false
      autoDismiss = true
      autoDismissDelay = 5.0
      showProgress = false
      addButtons = false

    case .blurredCenter:
      notificationType = .info
      title = "Information"
      message = "This is an important notification with screen blur"
      presentationMode = .custom
      position = .center
      width = 500
      height = 300
      transparent = true
      transparentMaterial = .hudWindow
      screenBlur = true
      screenBlurMaterial = .underWindowBackground
      dismissOnScreenTap = true
      moveable = true
      autoDismiss = false

    case .transparentFloat:
      notificationType = .info
      title = "Floating Notification"
      message = "A subtle, transparent notification"
      presentationMode = .custom
      position = .topRight
      width = 350
      height = 180
      transparent = true
      transparentMaterial = .popover
      windowOpacity = 0.9
      screenBlur = false
      moveable = true
      autoDismiss = true
      autoDismissDelay = 4.0
      addButtons = false
    }
  }

  func resetToDefaults() {
    notificationType = .success
    title = "Notification Title"
    message = "This is a notification message"
    presentationMode = .banner
    position = .center
    transparent = false
    transparentMaterial = .hudWindow
    screenBlur = false
    screenBlurMaterial = .underWindowBackground
    dismissOnScreenTap = false
    width = 400
    height = 200
    moveable = false
    windowOpacity = 1.0
    autoDismiss = false
    autoDismissDelay = 3.0
    showProgress = false
    addButtons = false
    useCustomMedia = false
    mediaPath = nil
    mediaType = .svg
    useSVGNotification = false
    svgInteractive = false
  }
}

// MARK: - Main Demo View
struct DemoContentView: View {
  @State private var selectedTopic: DemoTopic = .quickStart
  @StateObject private var config = NotificationConfig()
  @State private var copiedToClipboard = false

  var body: some View {
    NavigationSplitView {
      // Left Sidebar: Topic Selector
      TopicSidebar(selectedTopic: $selectedTopic)
    } content: {
      // Center: Configuration Panel
      ConfigurationPanel(topic: selectedTopic, config: config)
    } detail: {
      // Right: Code Generator
      CodeGeneratorPanel(
        config: config, selectedTopic: selectedTopic, copiedToClipboard: $copiedToClipboard)
    }
    .frame(minWidth: 1200, minHeight: 700)
  }
}

// MARK: - Topic Sidebar
struct TopicSidebar: View {
  @Binding var selectedTopic: DemoTopic

  var body: some View {
    List(DemoTopic.allCases, selection: $selectedTopic) { topic in
      HStack(spacing: 12) {
        Image(systemName: topic.icon)
          .font(.title3)
          .foregroundColor(.accentColor)
          .frame(width: 30)

        VStack(alignment: .leading, spacing: 4) {
          Text(topic.rawValue)
            .font(.headline)
          Text(topic.description)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 8)
      .tag(topic)
    }
    .navigationTitle("VibeNotify Demo")
    .frame(minWidth: 250)
  }
}

// MARK: - Configuration Panel
struct ConfigurationPanel: View {
  let topic: DemoTopic
  @ObservedObject var config: NotificationConfig

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Header
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Image(systemName: topic.icon)
              .font(.largeTitle)
              .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
              Text(topic.rawValue)
                .font(.title)
                .fontWeight(.bold)
              Text(topic.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }

        Divider()

        // Configuration based on topic
        switch topic {
        case .quickStart:
          QuickStartConfig(config: config)
        case .basicTypes:
          BasicTypesConfig(config: config)
        case .presentationModes:
          PresentationModesConfig(config: config)
        case .positioning:
          PositioningConfig(config: config)
        case .transparency:
          TransparencyConfig(config: config)
        case .screenBlur:
          ScreenBlurConfig(config: config)
        case .customization:
          CustomizationConfig(config: config)
        case .media:
          MediaConfig(config: config)
        case .builderAPI:
          BuilderAPIConfig(config: config)
        }

        Divider()

        // Preview and Dismiss Buttons
        HStack(spacing: 12) {
          Button(action: {
            config.showNotification()
          }) {
            HStack {
              Image(systemName: "play.fill")
              Text("Show Notification")
            }
            .frame(maxWidth: .infinity)
            .padding()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .keyboardShortcut("p", modifiers: .command)

          Button(action: {
            Task { @MainActor in
              VibeNotify.shared.dismissAll()
            }
          }) {
            HStack {
              Image(systemName: "xmark.circle.fill")
              Text("Dismiss All")
            }
            .frame(maxWidth: .infinity)
            .padding()
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .tint(.red)
          .keyboardShortcut("d", modifiers: .command)
        }
      }
      .padding(30)
    }
    .frame(minWidth: 400)
  }
}

// MARK: - Code Generator Panel
struct CodeGeneratorPanel: View {
  @ObservedObject var config: NotificationConfig
  let selectedTopic: DemoTopic
  @Binding var copiedToClipboard: Bool
  @State private var editableCode: String = ""
  @State private var isEditing: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(isEditing ? "Edit Code" : "Generated Code")
          .font(.headline)

        Spacer()

        if !isEditing {
          Button(action: copyToClipboard) {
            HStack(spacing: 6) {
              Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
              Text(copiedToClipboard ? "Copied!" : "Copy")
            }
          }
          .buttonStyle(.bordered)
        }

        Button(action: toggleEdit) {
          HStack(spacing: 6) {
            Image(systemName: isEditing ? "eye" : "pencil")
            Text(isEditing ? "View" : "Edit")
          }
        }
        .buttonStyle(.bordered)
      }

      if isEditing {
        TextEditor(text: $editableCode)
          .font(.system(.body, design: .monospaced))
          .frame(minHeight: 400)
          .padding(8)
          .background(Color(NSColor.textBackgroundColor))
          .cornerRadius(8)
          .border(Color.gray.opacity(0.3), width: 1)
      } else {
        ScrollView {
          Text(selectedTopic == .builderAPI ? config.generateBuilderCode() : config.generateCode())
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
      }

      if isEditing {
        Button(action: runEditedCode) {
          HStack {
            Image(systemName: "play.fill")
            Text("Run Code")
          }
          .frame(maxWidth: .infinity)
          .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
    }
    .padding()
    .frame(minWidth: 350)
    .onChange(of: selectedTopic) { _ in
      updateEditableCode()
    }
    .onChange(of: config.title) { _ in
      if !isEditing {
        updateEditableCode()
      }
    }
    .onChange(of: config.message) { _ in
      if !isEditing {
        updateEditableCode()
      }
    }
    .onAppear {
      updateEditableCode()
    }
  }

  private func updateEditableCode() {
    editableCode =
      selectedTopic == .builderAPI ? config.generateBuilderCode() : config.generateCode()
  }

  private func toggleEdit() {
    if !isEditing {
      updateEditableCode()
    }
    isEditing.toggle()
  }

  private func runEditedCode() {
    // Parse and execute the edited code
    // For now, we'll just show the notification with current config
    // In a real implementation, you'd parse the code string
    config.showNotification()
  }

  private func copyToClipboard() {
    let code = selectedTopic == .builderAPI ? config.generateBuilderCode() : config.generateCode()
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(code, forType: .string)
    copiedToClipboard = true

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      copiedToClipboard = false
    }
  }
}

// MARK: - Configuration Views

struct QuickStartConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Quick Start Presets")
        .font(.headline)

      Text("Select a preset to instantly configure a common notification pattern:")
        .font(.subheadline)
        .foregroundColor(.secondary)

      Divider()

      ScrollView {
        VStack(spacing: 12) {
          ForEach(NotificationPreset.allCases) { preset in
            PresetCard(preset: preset, config: config)
          }
        }
      }

      Divider()

      HStack {
        Button(action: {
          config.resetToDefaults()
        }) {
          HStack {
            Image(systemName: "arrow.counterclockwise")
            Text("Reset to Defaults")
          }
        }
        .buttonStyle(.bordered)

        Spacer()

        Text("Tip: Use ⌘P to preview, ⌘D to dismiss all")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}

struct PresetCard: View {
  let preset: NotificationPreset
  @ObservedObject var config: NotificationConfig

  var body: some View {
    Button(action: {
      config.applyPreset(preset)
    }) {
      HStack(spacing: 16) {
        Image(systemName: preset.icon)
          .font(.title2)
          .foregroundColor(.accentColor)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(preset.rawValue)
            .font(.headline)
            .foregroundColor(.primary)

          Text(presetDescription(preset))
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)
    }
    .buttonStyle(.plain)
  }

  func presetDescription(_ preset: NotificationPreset) -> String {
    switch preset {
    case .successToast:
      return "Quick success message with auto-dismiss and progress bar"
    case .errorModal:
      return "Critical error with screen blur and action buttons"
    case .warningBanner:
      return "Top banner warning that auto-dismisses after 5 seconds"
    case .blurredCenter:
      return "Centered notification with transparent blur effect"
    case .transparentFloat:
      return "Subtle floating notification in top-right corner"
    }
  }
}

struct BasicTypesConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Notification Type")
        .font(.headline)

      Picker("Type", selection: $config.notificationType) {
        ForEach(NotificationConfig.NotificationType.allCases, id: \.self) { type in
          Text(type.rawValue).tag(type)
        }
      }
      .pickerStyle(.segmented)

      Divider()

      Text("Size")
        .font(.headline)

      HStack {
        VStack(alignment: .leading) {
          Text("Width: \(Int(config.width))px")
            .font(.subheadline)
          Slider(value: $config.width, in: 250...1800, step: 50)
        }

        VStack(alignment: .leading) {
          Text("Height: \(Int(config.height))px")
            .font(.subheadline)
          Slider(value: $config.height, in: 150...1600, step: 50)
        }
      }

      Divider()

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
      config.position = .center
    }
  }
}

struct PresentationModesConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Presentation Mode")
        .font(.headline)

      Picker("Mode", selection: $config.presentationMode) {
        ForEach(NotificationConfig.PresentationMode.allCases, id: \.self) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)

      Picker("Notification Type", selection: $config.notificationType) {
        ForEach(NotificationConfig.NotificationType.allCases, id: \.self) { type in
          Text(type.rawValue).tag(type)
        }
      }
    }
  }
}

struct PositioningConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Window Position")
        .font(.headline)

      // Visual position grid
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          PositionButton(position: .topLeft, config: config)
          PositionButton(position: .top, config: config)
          PositionButton(position: .topRight, config: config)
        }
        HStack(spacing: 8) {
          PositionButton(position: .left, config: config)
          PositionButton(position: .center, config: config)
          PositionButton(position: .right, config: config)
        }
        HStack(spacing: 8) {
          PositionButton(position: .bottomLeft, config: config)
          PositionButton(position: .bottom, config: config)
          PositionButton(position: .bottomRight, config: config)
        }
      }

      Divider()

      HStack {
        VStack(alignment: .leading) {
          Text("Width: \(Int(config.width))px")
            .font(.subheadline)
          Slider(value: $config.width, in: 250...1850, step: 50)
        }

        VStack(alignment: .leading) {
          Text("Height: \(Int(config.height))px")
            .font(.subheadline)
          Slider(value: $config.height, in: 150...1650, step: 50)
        }
      }

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
    }
  }
}

struct PositionButton: View {
  let position: OverlayWindowManager.WindowPosition
  @ObservedObject var config: NotificationConfig

  var body: some View {
    Button(action: {
      config.position = position
      config.presentationMode = .custom
    }) {
      Text(positionLabel)
        .font(.caption)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(config.position == position ? Color.accentColor : Color.gray.opacity(0.2))
        .foregroundColor(config.position == position ? .white : .primary)
        .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }

  var positionLabel: String {
    switch position {
    case .topLeft: return "↖ Top Left"
    case .top: return "↑ Top"
    case .topRight: return "↗ Top Right"
    case .left: return "← Left"
    case .center: return "● Center"
    case .right: return "→ Right"
    case .bottomLeft: return "↙ Bottom Left"
    case .bottom: return "↓ Bottom"
    case .bottomRight: return "↘ Bottom Right"
    }
  }
}

struct TransparencyConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle("Enable Transparent Background", isOn: $config.transparent)
        .font(.headline)

      if config.transparent {
        Picker("Material", selection: $config.transparentMaterial) {
          Text("HUD Window").tag(NSVisualEffectView.Material.hudWindow)
          Text("Popover").tag(NSVisualEffectView.Material.popover)
          Text("Sidebar").tag(NSVisualEffectView.Material.sidebar)
          Text("Menu").tag(NSVisualEffectView.Material.menu)
          Text("Selection").tag(NSVisualEffectView.Material.selection)
          Text("Titlebar").tag(NSVisualEffectView.Material.titlebar)
          Text("Under Window").tag(NSVisualEffectView.Material.underWindowBackground)
        }
      }

      Divider()

      Text("Window Opacity: \(String(format: "%.0f", config.windowOpacity * 100))%")
        .font(.headline)
      Slider(value: $config.windowOpacity, in: 0.1...1.0, step: 0.05)

      Divider()

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
    }
  }
}

struct ScreenBlurConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle("Enable Screen Blur", isOn: $config.screenBlur)
        .font(.headline)

      if config.screenBlur {
        Picker("Blur Material", selection: $config.screenBlurMaterial) {
          Text("HUD Window").tag(NSVisualEffectView.Material.hudWindow)
          Text("Popover").tag(NSVisualEffectView.Material.popover)
          Text("Menu").tag(NSVisualEffectView.Material.menu)
          Text("Under Window").tag(NSVisualEffectView.Material.underWindowBackground)
        }

        Toggle("Dismiss on Screen Tap", isOn: $config.dismissOnScreenTap)
      }

      Divider()

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
    }
  }
}

struct CustomizationConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Size")
        .font(.headline)

      HStack {
        VStack(alignment: .leading) {
          Text("Width: \(Int(config.width))px")
          Slider(value: $config.width, in: 250...800, step: 50)
        }

        VStack(alignment: .leading) {
          Text("Height: \(Int(config.height))px")
          Slider(value: $config.height, in: 150...600, step: 50)
        }
      }

      Divider()

      Toggle("Moveable Window", isOn: $config.moveable)
        .font(.headline)

      Toggle("Add Action Buttons", isOn: $config.addButtons)
        .font(.headline)

      Divider()

      Toggle("Auto Dismiss", isOn: $config.autoDismiss)
        .font(.headline)

      if config.autoDismiss {
        HStack {
          Text("Delay: \(String(format: "%.1f", config.autoDismissDelay))s")
          Slider(value: $config.autoDismissDelay, in: 1.0...10.0, step: 0.5)
        }

        Toggle("Show Progress Bar", isOn: $config.showProgress)
      }

      Divider()

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
    }
  }
}

struct MediaConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Media Type")
        .font(.headline)

      Toggle("Use SVG Full Notification", isOn: $config.useSVGNotification)
        .help("Use SVG as main notification content (not just icon)")

      if !config.useSVGNotification {
        Toggle("Use Custom Icon", isOn: $config.useCustomMedia)
          .help("Use custom SVG/image as notification icon")
      }

      Divider()

      if config.useCustomMedia || config.useSVGNotification {
        Picker("Media Type", selection: $config.mediaType) {
          ForEach(NotificationConfig.MediaType.allCases, id: \.self) { type in
            Text(type.rawValue).tag(type)
          }
        }
        .pickerStyle(.segmented)

        Button(action: selectMediaFile) {
          HStack {
            Image(systemName: "folder")
            Text("Select \(config.mediaType.rawValue) File")
          }
        }
        .buttonStyle(.bordered)

        if let path = config.mediaPath {
          VStack(alignment: .leading, spacing: 8) {
            Text("Selected File:")
              .font(.subheadline)
              .foregroundColor(.secondary)
            Text(URL(fileURLWithPath: path).lastPathComponent)
              .font(.caption)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .padding(8)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(6)

          // Preview for images
          if config.mediaType == .png, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: 200, maxHeight: 200)
              .cornerRadius(8)
              .padding(.vertical, 8)
          }
        }

        Divider()

        if config.useSVGNotification {
          Text("Window Size")
            .font(.headline)

          Text("Controls the notification window dimensions")
            .font(.caption)
            .foregroundColor(.secondary)

          HStack {
            VStack(alignment: .leading) {
              Text("Width: \(Int(config.width))px")
                .font(.subheadline)
              Slider(value: $config.width, in: 300...1000, step: 50)
            }

            VStack(alignment: .leading) {
              Text("Height: \(Int(config.height))px")
                .font(.subheadline)
              Slider(value: $config.height, in: 200...800, step: 50)
            }
          }

          Divider()
        }

        Text(config.useSVGNotification ? "SVG Image Size" : "Media Size")
          .font(.headline)

        if config.useSVGNotification {
          Text("Controls the SVG image dimensions inside the window")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        HStack {
          VStack(alignment: .leading) {
            Text("Width: \(Int(config.mediaSize.width))px")
              .font(.subheadline)
            Slider(
              value: Binding(
                get: { config.mediaSize.width },
                set: { config.mediaSize = CGSize(width: $0, height: config.mediaSize.height) }
              ),
              in: 50...600,
              step: 10
            )
          }

          VStack(alignment: .leading) {
            Text("Height: \(Int(config.mediaSize.height))px")
              .font(.subheadline)
            Slider(
              value: Binding(
                get: { config.mediaSize.height },
                set: { config.mediaSize = CGSize(width: config.mediaSize.width, height: $0) }
              ),
              in: 50...600,
              step: 10
            )
          }
        }

        if config.useSVGNotification && config.mediaType == .svg {
          Divider()

          Toggle("Interactive SVG", isOn: $config.svgInteractive)
            .help("Allow user interaction with SVG elements")
        }

        Divider()
      }

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    .onAppear {
      config.presentationMode = .custom
      config.position = .center
    }
  }

  private func selectMediaFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = config.mediaType.fileExtensions.compactMap { ext in
      UTType(filenameExtension: ext)
    }

    if panel.runModal() == .OK, let url = panel.url {
      config.mediaPath = url.path
    }
  }
}

struct BuilderAPIConfig: View {
  @ObservedObject var config: NotificationConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Builder Pattern Configuration")
        .font(.headline)

      Text(
        "The builder API provides a declarative way to configure notifications. All the options you configure here will be shown using the builder pattern in the code panel."
      )
      .font(.subheadline)
      .foregroundColor(.secondary)
      .padding(.vertical, 8)

      Divider()

      Picker("Notification Type", selection: $config.notificationType) {
        ForEach(NotificationConfig.NotificationType.allCases, id: \.self) { type in
          Text(type.rawValue).tag(type)
        }
      }
      .pickerStyle(.segmented)

      Divider()

      Text("Size")
        .font(.headline)

      HStack {
        VStack(alignment: .leading) {
          Text("Width: \(Int(config.width))px")
            .font(.subheadline)
          Slider(value: $config.width, in: 250...1800, step: 50)
        }

        VStack(alignment: .leading) {
          Text("Height: \(Int(config.height))px")
            .font(.subheadline)
          Slider(value: $config.height, in: 150...1600, step: 50)
        }
      }

      Divider()

      TextField("Title", text: $config.title)
        .textFieldStyle(.roundedBorder)

      TextField("Message", text: $config.message, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)

      Toggle("Transparent Background", isOn: $config.transparent)
      Toggle("Screen Blur", isOn: $config.screenBlur)
      Toggle("Moveable", isOn: $config.moveable)
      Toggle("Auto Dismiss", isOn: $config.autoDismiss)
      Toggle("Add Buttons", isOn: $config.addButtons)
    }
    .onAppear {
      config.presentationMode = .custom
      config.position = .center
    }
  }
}

#Preview {
  DemoContentView()
}
