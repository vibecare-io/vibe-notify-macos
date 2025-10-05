import AppKit
import SwiftUI

// Import VibeNotify - note: this will be uncommented after library compiles
// For now, we'll create a basic demo app structure

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
                        // VibeNotify.shared.success(message: "Operation completed successfully!")
                        print("Success notification triggered")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button("Error") {
                        // VibeNotify.shared.error(message: "Something went wrong!")
                        print("Error notification triggered")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button("Warning") {
                        // VibeNotify.shared.warning(message: "Please be careful!")
                        print("Warning notification triggered")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button("Info") {
                        // VibeNotify.shared.info(message: "Here's some information")
                        print("Info notification triggered")
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
                        /*
                        VibeNotify.shared.show(
                            title: "Full Screen Notification",
                            message: "This covers the entire screen",
                            icon: .info,
                            presentationMode: .fullScreen
                        )
                        */
                        print("Full screen notification triggered")
                    }

                    Button("Top Banner") {
                        /*
                        VibeNotify.shared.show(
                            title: "Top Banner",
                            message: "Appears at the top of the screen",
                            icon: .success,
                            presentationMode: .banner(edge: .top, height: 120)
                        )
                        */
                        print("Top banner triggered")
                    }

                    Button("Toast (Corner)") {
                        /*
                        VibeNotify.shared.show(
                            title: "Toast",
                            message: "Small notification in corner",
                            icon: .info,
                            presentationMode: .toast(corner: .topRight, size: CGSize(width: 300, height: 150))
                        )
                        */
                        print("Toast notification triggered")
                    }
                }
            }

            Divider()

            // Builder API Example
            VStack(alignment: .leading, spacing: 12) {
                Text("Builder API")
                    .font(.headline)

                Button("Show with Builder") {
                    /*
                    VibeNotify.builder()
                        .title("Welcome to VibeNotify")
                        .message("This notification was created using the builder API")
                        .icon(.success)
                        .autoDismiss(after: 5.0, showProgress: true)
                        .presentationMode(.banner(edge: .top, height: 150))
                        .show()
                    */
                    print("Builder API notification triggered")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Custom Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Actions")
                    .font(.headline)

                Button("With Buttons") {
                    /*
                    let buttons = [
                        StandardNotification.Button(title: "Confirm", style: .primary) {
                            print("Confirmed!")
                        },
                        StandardNotification.Button(title: "Cancel", style: .secondary) {
                            print("Cancelled")
                        }
                    ]

                    VibeNotify.shared.show(
                        title: "Confirm Action",
                        message: "Do you want to proceed?",
                        icon: .warning,
                        buttons: buttons
                    )
                    */
                    print("Notification with buttons triggered")
                }
            }

            Spacer()

            // Dismiss All
            Button("Dismiss All Notifications") {
                // VibeNotify.shared.dismissAll()
                print("Dismiss all triggered")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding(40)
        .frame(minWidth: 600, minHeight: 600)
    }
}

#Preview {
    DemoContentView()
}
