import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

@MainActor
struct OverlayLifetimeTests {

  /// Reproduces the id-reuse pattern used by the consuming client: it tracks a single
  /// active overlay id and dismisses the previous one before showing the next. If the
  /// main window for that id is gone by the time `dismiss` runs, the blur window must
  /// still be torn down — it must never be orphaned with no owner and no route to close.
  @Test func dismissClosesBlurWindowEvenWhenMainWindowAlreadyGone() async throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }

    #expect(manager.blurWindows[id] != nil, "precondition: blur window should exist after show")

    // Simulate the main window having already been removed from `activeWindows` by the
    // time dismiss(id:) is called for this id (e.g. a prior teardown path, or id reuse).
    manager.activeWindows.removeValue(forKey: id)

    manager.dismiss(id: id, animated: false)

    #expect(manager.blurWindows[id] == nil, "blur window must not be orphaned")
  }
}
