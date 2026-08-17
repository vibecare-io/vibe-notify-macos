import AppKit
import SwiftUI
import Testing

@testable import VibeNotify

@MainActor
struct OverlayLifetimeTests {

  /// Reproduces the shape of the consuming client's id-reuse pattern (see
  /// `PluginInterrupt.flash()`): it tracks a single active overlay id, dismisses
  /// the previous one, then mints a *new* `UUID()` for the next show — so the old
  /// id's main window can go away (here: simulated by direct dict removal) with the
  /// blur window still standing. That blur window must still be torn down when
  /// `dismiss` is called for its own id — it must never be orphaned with no owner
  /// and no route to close.
  @Test func dismissClosesBlurWindowEvenWhenMainWindowAlreadyGone() async throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }
    let mainWindow = manager.activeWindows[id]

    #expect(manager.blurWindows[id] != nil, "precondition: blur window should exist after show")

    // Simulate the main window having already been removed from `activeWindows` by the
    // time dismiss(id:) is called for this id (e.g. a prior teardown path, or id reuse).
    manager.activeWindows.removeValue(forKey: id)

    manager.dismiss(id: id, animated: false)

    #expect(manager.blurWindows[id] == nil, "blur window must not be orphaned")

    // dismiss(id:) never got a chance to close the main window (its dict entry was
    // already gone), so this test — not the manager — owns closing what it opened.
    mainWindow?.close()
  }

  /// Step 3 of the fix: a defensive sweep closes any blur window left with no
  /// matching main window, even when the `dismiss(id:)` call in question is for a
  /// *different* id entirely. Shows both A and B with `screenBlur`, orphans A's
  /// blur window by dropping A's main-window entry directly, then dismisses B —
  /// a call with nothing to do with A's id — and confirms the sweep still reaps A.
  /// Asserts both that the dictionary entry is gone *and* that the window itself
  /// closed: the entry disappearing is not the same as the window closing, and
  /// only the latter is the user-visible bug (an unreachable dark sheet on screen).
  @Test func dismissSweepsOrphanedBlurWindowForUnrelatedID() async throws {
    let manager = OverlayWindowManager.shared
    let idA = UUID()
    let idB = UUID()

    _ = manager.show(
      id: idA,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }
    _ = manager.show(
      id: idB,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }

    let blurWindowA = try #require(manager.blurWindows[idA])
    let mainWindowA = try #require(manager.activeWindows[idA])

    // Simulate A's main window already being gone while B is still fully live.
    manager.activeWindows.removeValue(forKey: idA)

    manager.dismiss(id: idB, animated: false)

    #expect(manager.blurWindows[idA] == nil, "orphaned entry for A must be swept")
    #expect(blurWindowA.isVisible == false, "A's blur window must actually close, not just lose its dict entry")

    // A's main window was deliberately dropped from the dict above (simulating the
    // orphaning precondition) and dismiss(id: idB) has no reason to touch it — this
    // test owns closing what it opened.
    mainWindowA.close()
  }

  /// A stale `animateDismiss` completion must not evict a *fresher* window that has
  /// since taken over the same id. `show(id:)` reusing an id mid-fade is not exercised
  /// by the two current call sites (both mint a fresh `UUID()` per show — see
  /// `PluginInterrupt.flash()`), so this is latent, not live, today. But `show(id:)`
  /// is public, and once the screen dim goes from 10% to 55% an orphan like this stops
  /// being cosmetic and becomes an inescapable dark sheet with no way to close it.
  ///
  /// Sequence: show id X, begin an *animated* dismiss (0.25s fade, so its completion
  /// is still pending), immediately show X again before the fade finishes, then let
  /// the stale fade's completion actually run. It must recognize the window at `id`
  /// is no longer the one it was closing, and leave the fresh windows alone.
  @Test func staleAnimatedDismissCompletionDoesNotEvictReusedID() async throws {
    let manager = OverlayWindowManager.shared
    let id = UUID()

    _ = manager.show(
      id: id,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }

    // Begin tearing down the original windows for `id`, animated — their removal
    // from the dictionaries is deferred to animateDismiss's completion handler,
    // which hasn't run yet.
    manager.dismiss(id: id, animated: true)

    // Reuse the same id for a fresh show while the fade above is still in flight.
    _ = manager.show(
      id: id,
      configuration: .init(screenBlur: true, animatePresentation: false)
    ) {
      EmptyView()
    }
    let freshBlurWindow = try #require(manager.blurWindows[id])
    let freshMainWindow = try #require(manager.activeWindows[id])

    // Give the stale fade's completion handler (0.25s duration) time to fire.
    try await Task.sleep(for: .seconds(0.6))

    #expect(
      manager.blurWindows[id] === freshBlurWindow,
      "a stale completion must not evict the fresh blur window")
    #expect(
      manager.activeWindows[id] === freshMainWindow,
      "a stale completion must not evict the fresh main window")
    #expect(freshBlurWindow.isVisible, "the fresh blur window must still be on screen")
    #expect(freshMainWindow.isVisible, "the fresh main window must still be on screen")

    // Dismissing the (reused) id now must still work and close the fresh windows —
    // this is also how the test cleans up what it opened.
    manager.dismiss(id: id, animated: false)
    #expect(manager.blurWindows[id] == nil)
    #expect(manager.activeWindows[id] == nil)
    #expect(freshBlurWindow.isVisible == false)
    #expect(freshMainWindow.isVisible == false)
  }
}
