import AppKit
import SwiftUI
import VibeNotify

@main
struct VibeNotifyDemoApp: App {
  var body: some Scene {
    WindowGroup {
      DemoContentView()
    }
  }
}

struct DemoContentView: View {
  @State private var notificationID: UUID?

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Text("VibeNotify Demo")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("Test different notification styles")
          .foregroundColor(.secondary)

        Divider()
          .padding()

        // Standard Notifications
        VStack(alignment: .leading, spacing: 12) {
          Text("Standard Notifications")
            .font(.headline)

          HStack(spacing: 12) {
            Button("Success") {
              Task { @MainActor in
                VibeNotify.shared.success(message: "Operation completed successfully!")
              }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button("Error") {
              Task { @MainActor in
                VibeNotify.shared.error(message: "Something went wrong!")
              }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button("Warning") {
              Task { @MainActor in
                VibeNotify.shared.warning(message: "Please be careful!")
              }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Info") {
              Task { @MainActor in
                VibeNotify.shared.info(message: "Here's some information")
              }
            }
            .buttonStyle(.borderedProminent)
          }
        }

        Divider()

        // Presentation Modes
        VStack(alignment: .leading, spacing: 12) {
          Text("Presentation Modes")
            .font(.headline)

          HStack(spacing: 12) {
            Button("Full Screen") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Full Screen Notification",
                  message: "This covers the entire screen",
                  icon: .info,
                  presentationMode: .fullScreen
                )
              }
            }

            Button("Top Banner") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Top Banner",
                  message: "Appears at the top of the screen",
                  icon: .success,
                  presentationMode: .banner(edge: .top, height: 120)
                )
              }
            }

            Button("Toast (Corner)") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Toast",
                  message: "Small notification in corner",
                  icon: .info,
                  presentationMode: .toast(corner: .topRight, size: CGSize(width: 300, height: 150))
                )
              }
            }
          }
        }

        Divider()

        // Builder API Example
        VStack(alignment: .leading, spacing: 12) {
          Text("Builder API")
            .font(.headline)

          Button("Show with Builder") {
            Task { @MainActor in
              VibeNotify.builder()
                .title("Welcome to VibeNotify")
                .message("This notification was created using the builder API")
                .icon(.success)
                .autoDismiss(after: 5.0, showProgress: true)
                .presentationMode(.banner(edge: .top, height: 150))
                .show()
            }
          }
          .buttonStyle(.borderedProminent)
        }

        Divider()

        // Custom Actions
        VStack(alignment: .leading, spacing: 12) {
          Text("Custom Actions")
            .font(.headline)

          Button("With Buttons") {
            Task { @MainActor in
              let buttons = [
                StandardNotification.Button(title: "Confirm", style: .primary) {
                  print("Confirmed!")
                },
                StandardNotification.Button(title: "Cancel", style: .secondary) {
                  print("Cancelled")
                },
              ]

              VibeNotify.shared.show(
                title: "Confirm Action",
                message: "Do you want to proceed?",
                icon: .warning,
                buttons: buttons
              )
            }
          }
        }

        Divider()

        // Transparent Materials
        VStack(alignment: .leading, spacing: 12) {
          Text("Transparent Materials")
            .font(.headline)

          HStack(spacing: 8) {
            Button("HUD Window") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "HUD Window",
                  message: "Heads-up display style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .hudWindow
                )
              }
            }

            Button("Popover") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Popover",
                  message: "Popover menu style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .popover
                )
              }
            }

            Button("Sidebar") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Sidebar",
                  message: "Sidebar style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .sidebar
                )
              }
            }

            Button("Menu") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Menu",
                  message: "Menu style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .menu
                )
              }
            }
          }

          HStack(spacing: 8) {
            Button("Selection") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Selection",
                  message: "Selection style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .selection
                )
              }
            }

            Button("Titlebar") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Titlebar",
                  message: "Titlebar style material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .titlebar
                )
              }
            }

            Button("Under Window") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Under Window",
                  message: "Under window background material (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 380,
                  height: 180,
                  moveable: true,
                  transparent: true,
                  transparentMaterial: .underWindowBackground
                )
              }
            }
          }
        }

        Divider()

        // Screen Blur Materials
        VStack(alignment: .leading, spacing: 12) {
          Text("Screen Blur Materials")
            .font(.headline)

          HStack(spacing: 8) {
            Button("HUD Window") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Screen Blur: HUD",
                  message: "Full screen with HUD material blur",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 200,
                  screenBlur: true,
                  screenBlurMaterial: .hudWindow,
                  dismissOnScreenTap: true
                )
              }
            }

            Button("Popover") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Screen Blur: Popover",
                  message: "Full screen with popover material blur",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 200,
                  screenBlur: true,
                  screenBlurMaterial: .popover,
                  dismissOnScreenTap: true
                )
              }
            }

            Button("Menu") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Screen Blur: Menu",
                  message: "Full screen with menu material blur",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 200,
                  screenBlur: true,
                  screenBlurMaterial: .menu,
                  dismissOnScreenTap: true
                )
              }
            }

            Button("Under Window") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Screen Blur: Under Window",
                  message: "Full screen with under window material blur",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 200,
                  screenBlur: true,
                  screenBlurMaterial: .underWindowBackground,
                  dismissOnScreenTap: true
                )
              }
            }
          }
        }

        Divider()

        // Window Opacity Examples
        VStack(alignment: .leading, spacing: 12) {
          Text("Window Opacity")
            .font(.headline)

          HStack(spacing: 8) {
            Button("100% Opaque") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Fully Opaque",
                  message: "Window opacity: 1.0 (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 350,
                  height: 180,
                  moveable: true,
                  windowOpacity: 1.0
                )
              }
            }

            Button("85% Opaque") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Semi-Transparent",
                  message: "Window opacity: 0.85 (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 350,
                  height: 180,
                  moveable: true,
                  windowOpacity: 0.85
                )
              }
            }

            Button("50% Opaque") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Half Transparent",
                  message: "Window opacity: 0.5 (drag to compare)",
                  icon: .info,
                  position: .center,
                  width: 350,
                  height: 180,
                  moveable: true,
                  windowOpacity: 0.5
                )
              }
            }

            Button("10% Opaque") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Extra Transparent",
                  message: "Window opacity: 0.1 (drag to compare)",
                  icon: .success,
                  position: .center,
                  width: 350,
                  height: 180,
                  moveable: true,
                  windowOpacity: 0.1
                )
              }
            }
          }
        }

        Divider()

        // Customization Options
        VStack(alignment: .leading, spacing: 12) {
          Text("Customization Options")
            .font(.headline)

          HStack(spacing: 8) {
            Button("Position: Center") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Centered Notification",
                  message: "This notification is centered on screen",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 200
                )
              }
            }

            Button("Position: Bottom Right") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Bottom Right",
                  message: "Positioned in bottom right corner",
                  icon: .success,
                  position: .bottomRight,
                  width: 350,
                  height: 150
                )
              }
            }

            Button("Moveable Notification") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Drag Me!",
                  message: "This notification can be moved around",
                  icon: .info,
                  position: .center,
                  width: 400,
                  height: 180,
                  moveable: true
                )
              }
            }

            Button("Transparent Background") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "Transparent Effect",
                  message: "This notification has a transparent blur background",
                  icon: .success,
                  position: .center,
                  width: 400,
                  height: 180,
                  transparent: true,
                  transparentMaterial: .menu
                )
              }
            }
          }

          HStack(spacing: 8) {
            Button("Custom Size + Position") {
              Task { @MainActor in
                VibeNotify.builder()
                  .title("Fully Customized")
                  .message("Custom width, height, position, moveable, and transparent!")
                  .icon(.warning)
                  .position(.topLeft)
                  .width(450)
                  .height(220)
                  .moveable(true)
                  .transparent(true, material: .popover)
                  .autoDismiss(after: 6.0, showProgress: true)
                  .show()
              }
            }

            Button("Full Screen Blur 🌟") {
              Task { @MainActor in
                VibeNotify.shared.show(
                  title: "20-20-20 Rule",
                  message:
                    "Save your eyes !! Every 20 minutes, look at something 20 feet away for 20 seconds.",
                  icon: .info,
                  position: .center,
                  width: 500,
                  height: 250,
                  screenBlur: true,
                  screenBlurMaterial: .underWindowBackground,
                  dismissOnScreenTap: true
                )
              }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button("Screen Blur + Transparent") {
              Task { @MainActor in
                VibeNotify.builder()
                  .title("Ultra Focus Mode")
                  .message("Screen and notification both blurred!")
                  .icon(.success)
                  .position(.center)
                  .width(450)
                  .height(200)
                  .transparent(true, material: .hudWindow)
                  .screenBlur(true, material: .underWindowBackground)
                  .dismissOnScreenTap(true)
                  .autoDismiss(after: 5.0)
                  .show()
              }
            }
          }
          .buttonStyle(.bordered)
        }

        Divider()
          .padding(.vertical)

        // Dismiss All
        Button("Dismiss All Notifications") {
          Task { @MainActor in
            VibeNotify.shared.dismissAll()
          }
        }
        .buttonStyle(.bordered)
        .foregroundColor(.red)
        .padding(.bottom, 20)
      }
      .padding(40)
    }
    .frame(minWidth: 700, minHeight: 800)
  }
}

#Preview {
  DemoContentView()
}
