import Cocoa
import Combine
import Foundation
import SwiftUI

class TabBarController:
  NSWindowController,
  NSWindowDelegate
// TabGroupCloseCoordinator.Controller
{

  // MARK static

  /// strong references to all living controllers, as NSWindow.windowController does not reliably retain the controller
  private static var retainedControllers: Set<TabBarController> = []

  /// track the previously selected tab so we can detect actual tab switches
  static private(set) weak var lastMain: TabBarController? = nil

  /// get all controllers from NSApplication
  static var all: [TabBarController] {
    return NSApplication.shared.windows.compactMap {
      $0.windowController as? TabBarController
    }
  }

  /// get relevant controller, ideally main
  static var preferredParent: TabBarController? {
    all.first {
      $0.window?.isMainWindow ?? false
    } ?? lastMain ?? all.last
  }

  static func newTab(
    from explicitParent: NSWindow? = nil,
    pid processIdentifier: pid_t
  ) -> TabBarController? {
    print("[TabBarController] | fn newTab")

    let controller = TabBarController.init(pid: processIdentifier)

    let parentWindow =
      explicitParent
      ?? Self.preferredParent?.window
      ?? NSApp.mainWindow

    guard let parentWindow = parentWindow else {
      controller.showWindow(self)
      NSApp.activate(ignoringOtherApps: true)
      return controller
    }

    if let newWindow = controller.window {
      parentWindow.addTabbedWindow(newWindow, ordered: .above)
    }

    if parentWindow.isMiniaturized { parentWindow.deminiaturize(self) }
    controller.showWindow(self)
    NSApp.activate(ignoringOtherApps: true)

    controller.relabelTabs()
    return controller
  }

  // MARK instance

  override var windowNibName: NSNib.Name {
    return "TabBar"
  }

  /// reference to application tied to tab/window
  private var processIdentifier: pid_t? = nil
  private var runningApplication: NSRunningApplication? {
    guard let pid = processIdentifier else { return nil }
    return NSRunningApplication(processIdentifier: pid)
  }

  /// observer for app termination, used during graceful close flow
  private var terminationObserver: NSObjectProtocol? = nil
  /// observer for external app termination i.e. user quit the app outside of nativebar
  private var externalTerminationObserver: NSObjectProtocol? = nil

  // MARK TabGroupCloseCoordinator.Controller
  // lazy private(set) var tabGroupCloseCoordinator = TabGroupCloseCoordinator()

  init(
    pid processIdentifier: pid_t
  ) {
    super.init(window: nil)

    self.processIdentifier = processIdentifier
    Self.retainedControllers.insert(self)
    observeExternalTermination()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    if let observer = terminationObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    if let observer = externalTerminationObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    print("[TabBarController] | deinit \(Unmanaged.passUnretained(self).toOpaque())")
  }

  // MARK NSObject

  override func awakeFromNib() {
    guard let window else {
      print("[TabBarController] | fn awakeFromNib() | no window")
      return
    }
  }

  // MARK NSWindowDelegate

  func windowDidBecomeMain(_ notification: Notification) {
    let previousTab = Self.lastMain
    Self.lastMain = self

    relabelTabs()

    guard previousTab != nil, previousTab !== self else { return }
    activateApplication()
  }

  func windowWillClose(_ notification: Notification) {
    Self.retainedControllers.remove(self)

    DispatchQueue.main.async {
      // NOTE why first
      Self.all.first?.relabelTabs()
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // we handle closing explicitly after the process responds
    closeTab()
    return false
  }

  // MARK NSWindowController

  override func windowDidLoad() {
    super.windowDidLoad()

    guard let window else { return }

    // must set the window title from our process here (not from the
    // caller) because addTabbedWindow is async and AppKit can reorder tabs —
    // setting the title externally can end up on the wrong window
    if let app = runningApplication {
      window.title = app.localizedName ?? "unknown"
    }
  }

  // override func windowWillLoad() {
  //   shouldCascadeWindows = false
  // }

  // MARK methods

  /// calls fn terminateApplication and closes the tab if its dies
  private func closeTab() {
    terminateApplication { [weak self] in
      guard let self, let window = self.window else { return }
      window.close()
    }
  }

  // NOTE can be used for environment cleanup?
  private func closeAllTabs() {
    guard let window = window else { return }

    let controllers: [TabBarController] = (window.tabGroup?.windows ?? [window]).compactMap {
      $0.windowController as? TabBarController
    }

    let group = DispatchGroup()
    for controller in controllers {
      group.enter()
      controller.terminateApplication {
        group.leave()
      }
    }

    group.notify(queue: .main) {
      // all processes terminated (or were already dead). Close all windows.
      for controller in controllers {
        controller.window?.close()
      }
    }
  }

  @objc func gotoTab(_ index: Int) {
    guard let tabGroup = window?.tabGroup else {
      return
    }
    let windows = tabGroup.windows
    guard index >= 0, index < windows.count else {
      return
    }
    NSApp.activate()  // when nativebar isn't focused
    windows[index].makeKeyAndOrderFront(nil)
  }

  func relabelTabs() {
    guard let windows = window?.tabGroup?.windows ?? window.map({ [$0] }) else { return }
    for (i, window) in windows.enumerated() {
      guard let w = window as? TabBarWindow else { continue }
      if i < 9 {
        w.keyEquivalent = "⌘\(i + 1)"
      } else {
        w.keyEquivalent = nil
      }
    }
  }

  private func activateApplication() {
    guard let app = runningApplication, !app.isTerminated else { return }
    guard let pid = processIdentifier else { return }

    print(
      "[TabBarcontroller] | fn activateApplication| \(runningApplication!.localizedName) -> \(runningApplication!.processIdentifier)"
    )

    // 3 types -> unhide, de-minimize, activate

    if app.isHidden { app.unhide() }

    let axApp = AXUIElementCreateApplication(pid)
    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      axApp,
      kAXWindowsAttribute as CFString,
      &windowsRef
    )
    if result == .success, let windows = windowsRef as? [AXUIElement] {
      for window in windows {
        var minimizedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
          window,
          kAXMinimizedAttribute as CFString,
          &minimizedRef
        )
        if let isMinimized = minimizedRef as? Bool, isMinimized {
          AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            false as CFBoolean
          )
        }
      }
    }

    if !app.isActive { app.activate() }
  }

  private func terminateApplication(completion: @escaping () -> Void) {
    print(
      "[TabBarcontroller] | fn terminateApplication | \(runningApplication!.localizedName) -> \(runningApplication!.processIdentifier)"
    )

    guard let app = runningApplication, !app.isTerminated else {
      completion()
      return
    }

    // send a polite quit request i.e. user confirmed or no unsaved state
    let didSend = app.terminate()
    if !didSend {
      print("[ERROR] | failed to terminate")
      completion()
      return
    }

    // clear previous observer and watch for the app to terminate
    if let observer = terminationObserver {
      NSWorkspace
        .shared
        .notificationCenter
        .removeObserver(observer)
      terminationObserver = nil
    }
    terminationObserver = NSWorkspace
      .shared
      .notificationCenter
      .addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        guard let self else { return }
        guard
          let terminatedApp = notification
            .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
          terminatedApp.processIdentifier == self.processIdentifier
        else { return }

        if let observer = self.terminationObserver {
          NSWorkspace
            .shared
            .notificationCenter
            .removeObserver(observer)
          self.terminationObserver = nil
        }

        completion()
      }
  }

  /// Watches for the process to terminate externally (e.g. user quit the app via
  /// Cmd+Q in that app, Activity Monitor, etc.). When detected, closes this tab.
  private func observeExternalTermination() {
    guard let pid = processIdentifier else { return }

    externalTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }

      // If terminationObserver is active, we initiated this close ourselves — let
      // that flow handle it instead.
      guard self.terminationObserver == nil else { return }

      guard
        let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        terminatedApp.processIdentifier == pid
      else { return }

      print("[TabBarController] | external termination detected for pid \(pid)")
      self.window?.close()
    }
  }
}
