import AppKit
import Cocoa
import SwiftUI

@main
class AppDelegate:
  NSObject,
  NSApplicationDelegate
{
  /// determines if we initialize the tabs
  private var applicationHasBecomeActive: Bool = false

  // MARK NSApplicationDelegate

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    print("[AppDelegate] | initializing observers")
    // NotificationCenter
    //   .default
    //   .addObserver(
    //     self,
    //     selector: #selector(nativebarNewWindow(_:)),
    //     name: NSNotification.Name("calebsideras.nativebar.newwindow"),
    //     object: nil
    //   )

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidLaunch(_:)),
      name: NSWorkspace.didLaunchApplicationNotification,
      object: nil
    )

    // NOTE
    // using tab menu items for shortcuts
    // if let mainMenu = NSApp.mainMenu {
    //   let tabMenu = NSMenu(title: "Tabs")
    //   for i in 1...9 {
    //     let item = NSMenuItem(
    //       title: "Tab \(i)",
    //       action: #selector(gotoTabMenuItem(_:)),
    //       keyEquivalent: "\(i)"
    //     )
    //     item.tag = i - 1  // 0-based index
    //     tabMenu.addItem(item)
    //   }
    //   let tabMenuItem = NSMenuItem(title: "Tabs", action: nil, keyEquivalent: "")
    //   tabMenuItem.submenu = tabMenu
    //   mainMenu.addItem(tabMenuItem)
    // }

    // NOTE no idea if this is the best way to do it

    // when other apps focused
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handleTabHotkey(event)
    }
    // when app focused
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if self?.handleTabHotkey(event) == true {
        return nil  // consume the event
      }
      return event
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    if !applicationHasBecomeActive {
      applicationHasBecomeActive = true

      // NOTE pid is unique per app, not window
      let selfBundleID = Bundle.main.bundleIdentifier
      for runningApplication in NSWorkspace
        .shared
        .runningApplications
        .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != selfBundleID }
      {
        _ = TabBarController.newTab(pid: runningApplication.processIdentifier)
      }

      // NOTE figure out optimal way to display tabbar if no apps are active
      // if TabBarController.all.isEmpty {
      //   _ = TabBarController.newWindow()
      // }
    }
  }

  @objc private func applicationDidLaunch(_ notification: Notification) {
    guard
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      app.activationPolicy == .regular,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else { return }
    _ = TabBarController.newTab(pid: app.processIdentifier)
  }

  // func applicationWillTerminate(_ aNotification: Notification) {
  //   // Insert code here to tear down your application
  // }
  // func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
  //   return true
  // }

  // MARK methods

  // @objc private func gotoTabMenuItem(_ sender: NSMenuItem) {
  //   guard
  //     let controller = TabBarController.all.first(where: {
  //       $0.window?.isMainWindow ?? false
  //     }) ?? TabBarController.all.first
  //   else { return }
  //   controller.gotoTab(sender.tag)
  // }

  @discardableResult
  private func handleTabHotkey(_ event: NSEvent) -> Bool {
    print("[AppDelegate] | fn handleTabHotkey")
    guard
      event
        .modifierFlags
        .intersection(.deviceIndependentFlagsMask) == .option
    else {
      return false
    }

    guard let characters = event.charactersIgnoringModifiers,
      let digit = Int(characters),
      digit >= 1, digit <= 9
    else {
      return false
    }

    guard let controller = TabBarController.preferredParent
    else {
      return false
    }

    controller.gotoTab(digit - 1)
    return true
  }

  // NOTE below might be useful later
  // @IBAction func newTab(_ sender: Any?) {
  //   print("[AppDelegate] | @IBAction fn newTab()")
  //   NotificationCenter.default.post(
  //     name: NSNotification.Name("calebsideras.nativebar.newtab"),
  //     object: nil,
  //   )
  // }
  // @objc private func nativebarNewTab(_ notification: Notification) {
  //   print("[AppDelegate] | @objc private func nativebarNewTab")
  //   _ = TabBarController.newTab()
  // }
}
