import AppKit
import Combine
import SwiftUI

class TabBarWindow: Window, NSToolbarDelegate {
  /// used to sync state between window and SwiftUI
  private var viewModel = ViewModel()

  // MARK Window

  /// titlebar tabs can't support the update accessory because of the way we layout
  /// the native tabs back into the menu bar.
  override var supportsUpdateAccessory: Bool { false }

  deinit {
    tabBarObserver = nil
  }

  override var title: String {
    didSet {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.viewModel.title = self.title
      }
    }
  }

  // MARK NSObject

  override func awakeFromNib() {
    super.awakeFromNib()

    // window doesn't show if height 0 set in xib
    // NOTE make immovable
    self.contentMaxSize.height = 0
    if let screen = NSScreen.main {
      self.setContentSize(CGSize.init(width: screen.frame.width, height: 0))
      self.setFrameTopLeftPoint(NSPoint(x: screen.frame.minX, y: screen.frame.maxY))
    }

    // we must hide the title since we're going to be moving tabs into
    // the titlebar which have their own title.
    self.titleVisibility = .hidden

    // create a toolbar
    let toolbar = NSToolbar(identifier: "TabbarToolbar")
    toolbar.delegate = self
    toolbar.centeredItemIdentifiers.insert(.title)
    self.toolbar = toolbar
    toolbarStyle = .unifiedCompact
  }

  // MARK NSWindow

  override func becomeMain() {
    super.becomeMain()

    // check if we have a tab bar and set it up if we have to. see the comment
    // on this function to learn why we need to check this here.
    setupTabBar()

    viewModel.isMainWindow = true
  }

  override func resignMain() {
    super.resignMain()

    viewModel.isMainWindow = false
  }

  override func sendEvent(_ event: NSEvent) {
    guard viewModel.hasTabBar else {
      super.sendEvent(event)
      return
    }

    let isRightClick =
      event.type == .rightMouseDown || (event.type == .otherMouseDown && event.buttonNumber == 2)
      || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
    guard isRightClick else {
      super.sendEvent(event)
      return
    }

    guard let tabBarView else {
      super.sendEvent(event)
      return
    }

    let locationInTabBar = tabBarView.convert(event.locationInWindow, from: nil)
    guard tabBarView.bounds.contains(locationInTabBar) else {
      super.sendEvent(event)
      return
    }

    tabBarView.rightMouseDown(with: event)
  }

  override func addTitlebarAccessoryViewController(
    _ childViewController: NSTitlebarAccessoryViewController
  ) {
    // If this is the tab bar then we need to set it up for the titlebar
    guard isTabBar(childViewController) else {
      // After dragging a tab into a new window, `hasTabBar` needs to be
      // updated to properly review window title
      viewModel.hasTabBar = false

      super.addTitlebarAccessoryViewController(childViewController)
      return
    }

    // When an existing tab is being dragged in to another tab group,
    // system will also try to add tab bar to this window, so we want to reset observer,
    // to put tab bar where we want again
    tabBarObserver = nil

    // Some setup needs to happen BEFORE it is added, such as layout. If
    // we don't do this before the call below, we'll trigger an AppKit
    // assertion.
    childViewController.layoutAttribute = .right

    super.addTitlebarAccessoryViewController(childViewController)

    // Setup the tab bar to go into the titlebar.
    DispatchQueue.main.async {
      // HACK: wait a tick before doing anything, to avoid edge cases during startup... :/
      // If we don't do this then on launch windows with restored state with tabs will end
      // up with messed up tab bars that don't show all tabs.
      self.setupTabBar()
    }
  }

  override func removeTitlebarAccessoryViewController(at index: Int) {
    guard let childViewController = titlebarAccessoryViewControllers[safe: index],
      isTabBar(childViewController)
    else {
      super.removeTitlebarAccessoryViewController(at: index)
      return
    }

    super.removeTitlebarAccessoryViewController(at: index)

    removeTabBar()
  }

  // MARK: Tab Bar Setup

  private var tabBarObserver: NSObjectProtocol? {
    didSet {
      // When we change this we want to clear our old observer
      guard let oldValue else { return }
      NotificationCenter.default.removeObserver(oldValue)
    }
  }

  func setupTabBar() {
    // we only want to setup the observer once
    guard tabBarObserver == nil else { return }

    guard
      let titlebarView,
      let tabBarView = self.tabBarView
    else { return }

    // view model updates must happen on their own ticks
    DispatchQueue.main.async { [weak self] in
      self?.viewModel.hasTabBar = true
    }

    // Find our clip view
    guard let clipView = tabBarView.firstSuperview(withClassName: "NSTitlebarAccessoryClipView")
    else { return }
    guard let accessoryView = clipView.subviews[safe: 0] else { return }
    guard let toolbarView = titlebarView.firstDescendant(withClassName: "NSToolbarView") else {
      return
    }

    // NOTE + button should open spotlight search &/or configurable?
    // Make sure tabBar's height won't be stretched
    // guard let newTabButton = titlebarView.firstDescendant(withClassName: "NSTabBarNewTabButton")
    // else { return }
    // tabBarView.frame.size.height = newTabButton.frame.width

    // The container is the view that we'll constrain our tab bar within.
    let container = toolbarView

    // Constrain the accessory clip view (the parent of the accessory view
    // usually that clips the children) to the container view.
    clipView.translatesAutoresizingMaskIntoConstraints = false
    accessoryView.translatesAutoresizingMaskIntoConstraints = false

    // NOTE should be configurable
    // setup all our constraints
    NSLayoutConstraint.activate([
      clipView.leftAnchor.constraint(equalTo: container.leftAnchor),
      clipView.rightAnchor.constraint(equalTo: container.rightAnchor),
      clipView.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
      clipView.heightAnchor.constraint(equalTo: container.heightAnchor),
      accessoryView.leftAnchor.constraint(equalTo: clipView.leftAnchor),
      accessoryView.rightAnchor.constraint(equalTo: clipView.rightAnchor),
      accessoryView.topAnchor.constraint(equalTo: clipView.topAnchor),
      accessoryView.heightAnchor.constraint(equalTo: clipView.heightAnchor),
    ])

    clipView.needsLayout = true
    accessoryView.needsLayout = true

    // Setup an observer for the NSTabBar frame. When system appearance changes or
    // other events occur, the tab bar can resize and clear our constraints. When this
    // happens, we need to remove our custom constraints and re-apply them once the
    // tab bar has proper dimensions again to avoid constraint conflicts.
    // print("5")
    tabBarView.postsFrameChangedNotifications = true
    tabBarObserver = NotificationCenter.default.addObserver(
      forName: NSView.frameDidChangeNotification,
      object: tabBarView,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }

      // Remove the observer so we can call setup again.
      self.tabBarObserver = nil

      // Wait a tick to let the new tab bars appear and then set them up.
      DispatchQueue.main.async {
        self.setupTabBar()

        // Relabel tabs — the frame change may be from a drag reorder.
        // self.terminalController?.relabelTabs()
      }
    }
  }

  func removeTabBar() {
    // View model needs to be updated on another tick because it
    // triggers view updates.
    DispatchQueue.main.async {
      self.viewModel.hasTabBar = false
    }

    // Clear our observations
    self.tabBarObserver = nil
  }

  // MARK: NSToolbarDelegate

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.title, .flexibleSpace, .space]
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    return [.flexibleSpace, .title, .flexibleSpace]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case .title:
      let item = NSToolbarItem(itemIdentifier: .title)
      item.view = NSHostingView(rootView: TitleItem(viewModel: viewModel))
      // Fix: https://github.com/ghostty-org/ghostty/discussions/9027
      item.view?.setContentCompressionResistancePriority(.required, for: .horizontal)
      item.visibilityPriority = .user
      item.isEnabled = true

      // This is the documented way to avoid the glass view on an item.
      // We don't want glass on our title.
      item.isBordered = false

      return item
    default:
      return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
  }

  // override func close() {
  //   NSRunningApplication.runningApplications(processIdentifier: self.pid)

  //   guard surfaceTree.contains(where: { $0.needsConfirmQuit }) else {
  //     closeTabImmediately()
  //     return
  //   }

  //   confirmClose(
  //     messageText: "Close Tab?",
  //     informativeText:
  //       "The terminal still has a running process. If you close the tab the process will be killed."
  //   ) {
  //     self.closeTabImmediately()
  //   }
  //   super.close()
  // }

  class ViewModel: ObservableObject {
    @Published var titleFont: NSFont?
    @Published var title: String = "nativebar"
    @Published var hasTabBar: Bool = false
    @Published var isMainWindow: Bool = true
  }

}

extension NSToolbarItem.Identifier {
  /// Displays the title of the window
  static let title = NSToolbarItem.Identifier("Title")
}

extension TabBarWindow {
  /// Displays the window title
  struct TitleItem: View {
    @ObservedObject var viewModel: ViewModel

    var title: String {
      // An empty title makes this view zero-sized and NSToolbar on macOS
      // tahoe just deletes the item when that happens. So we use a space
      // instead to ensure there's always some size.
      return viewModel.title.isEmpty ? " " : viewModel.title
    }

    var body: some View {
      if !viewModel.hasTabBar {
        titleText
      } else {
        // 1x1.gif strikes again! For real: if we render a zero-sized
        // view here then the toolbar just disappears our view. I don't
        // know. On macOS 26.1+ the view no longer disappears, but the
        // toolbar still logs an ambiguous content size warning.
        Color.clear.frame(width: 1, height: 1)
      }
    }

    @ViewBuilder
    var titleText: some View {
      Text(title)
        .font(viewModel.titleFont.flatMap(Font.init(_:)))
        .foregroundStyle(viewModel.isMainWindow ? .primary : .secondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .greatestFiniteMagnitude, alignment: .center)
        .opacity(viewModel.hasTabBar ? 0 : 1)  // hide when in fullscreen mode, where title bar will appear in the leading area under window buttons
    }
  }
}
