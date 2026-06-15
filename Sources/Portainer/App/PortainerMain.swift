import AppKit
import Combine
import SwiftUI

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
final class FirstMouseHostingController<Content: View>: NSViewController {
    private let hostingView: FirstMouseHostingView<Content>

    init(rootView: Content) {
        hostingView = FirstMouseHostingView(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = hostingView
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let store = ContainerStore(runtime: AppleContainerCLIClient())
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMenu()
        store.$uiMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.applyWindowMode(mode)
            }
            .store(in: &cancellables)
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
        Task {
            await store.refresh()
            store.startSystemMetricsCollection()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopSystemMetricsCollection()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    private func showMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        let root = RootView()
            .environmentObject(store)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Calyx"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = FirstMouseHostingController(rootView: root)
        makeWindowTransparent(window)
        hideNativeWindowButtons(window)
        window.makeKeyAndOrderFront(nil)
        window.sharingType = .readOnly
        mainWindow = window
        applyWindowMode(store.uiMode)
    }

    @objc private func refresh() {
        Task { await store.refresh() }
    }

    @objc private func startContainer() {
        Task { await store.startSelectedContainer() }
    }

    @objc private func stopContainer() {
        Task { await store.stopSelectedContainer() }
    }

    @objc private func restartContainer() {
        Task { await store.restartSelectedContainer() }
    }

    @objc func showSettingsFromUI() {
        showSettings()
    }

    @objc private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView()
            .environmentObject(store)
            .frame(width: 520, height: 430)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = FirstMouseHostingController(rootView: view)
        makeWindowTransparent(window)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.sharingType = .readOnly
        settingsWindow = window
    }

    private func configureMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Calyx", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let containerItem = NSMenuItem()
        mainMenu.addItem(containerItem)
        let containerMenu = NSMenu(title: "Container")
        containerItem.submenu = containerMenu
        containerMenu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        containerMenu.addItem(.separator())
        containerMenu.addItem(withTitle: "Start", action: #selector(startContainer), keyEquivalent: "s")
        containerMenu.addItem(withTitle: "Stop", action: #selector(stopContainer), keyEquivalent: ".")
        containerMenu.addItem(withTitle: "Restart", action: #selector(restartContainer), keyEquivalent: "R")

        let modeItem = NSMenuItem()
        mainMenu.addItem(modeItem)
        let modeMenu = NSMenu(title: "Mode")
        modeItem.submenu = modeMenu
        modeMenu.addItem(withTitle: "Full Window", action: #selector(useFullMode), keyEquivalent: "1")
        modeMenu.addItem(withTitle: "Drawer", action: #selector(useDrawerMode), keyEquivalent: "2")

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Show Calyx", action: #selector(showMainWindowFromMenu), keyEquivalent: "0")
    }

    @objc private func showMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func useFullMode() {
        store.setUIMode(.full)
    }

    @objc private func useDrawerMode() {
        store.setUIMode(.drawer)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(startContainer):
            store.canStartSelected
        case #selector(stopContainer), #selector(restartContainer):
            store.canStopSelected
        default:
            true
        }
    }

    private func applyWindowMode(_ mode: AppUIMode) {
        guard let window = mainWindow else { return }
        let size: NSSize
        let minSize: NSSize
        switch mode {
        case .full:
            size = NSSize(width: 1400, height: 860)
            minSize = NSSize(width: 1180, height: 760)
            window.title = "Calyx"
            window.isMovableByWindowBackground = false
        case .drawer:
            size = NSSize(width: 560, height: 468)
            minSize = NSSize(width: 500, height: 420)
            window.title = "Calyx"
            window.isMovableByWindowBackground = true
        }
        window.minSize = minSize
        window.setContentSize(size)
        window.center()
        hideNativeWindowButtons(window)
        window.sharingType = .readOnly
    }

    private func hideNativeWindowButtons(_ window: NSWindow) {
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func makeWindowTransparent(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

@main
enum PortainerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
