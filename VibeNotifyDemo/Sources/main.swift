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

      // Customization Options
      VStack(alignment: .leading, spacing: 12) {
        Text("Customization Options")
          .font(.headline)

        VStack(spacing: 8) {
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
                transparentMaterial: .hudWindow
              )
            }
          }

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

      Spacer()

      // Dismiss All
      Button("Dismiss All Notifications") {
        Task { @MainActor in
          VibeNotify.shared.dismissAll()
        }
      }
      .buttonStyle(.bordered)
      .foregroundColor(.red)
    }
    .padding(40)
    .frame(minWidth: 700, minHeight: 800)
  }
}

#Preview {
  DemoContentView()
}
