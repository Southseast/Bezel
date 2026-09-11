import AppKit
import Combine
import ServiceManagement

/// Status item whose click (left or right) opens the menu directly; all
/// settings live in the menu as checkable items.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    /// (defaults key, localized-menu-title key) for every checkable item, in
    /// display order.
    private let settingItems: [(key: String, titleKey: String)] = [
        (BarSettings.enabled, "menu.enable"),
        (BarSettings.builtInOnly, "menu.built_in_only"),
        (BarSettings.roundedCorners, "menu.rounded_corners"),
        (BarSettings.animated, "menu.fade_animation"),
        (BarSettings.launchAtLogin, "menu.launch_at_login"),
    ]

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        BarWindowManager.shared.start()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Bezel"
        )
        // Anchoring the menu to the item makes ANY click (left or right)
        // open it natively.
        item.menu = menu
        statusItem = item

        for (key, titleKey) in settingItems {
            let menuItem = menu.addItem(
                withTitle: localized(titleKey),
                action: #selector(toggleSetting(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = key
            if key == BarSettings.animated {
                menu.addItem(.separator())
            }
        }
        menu.addItem(.separator())
        menu.addItem(
            withTitle: localized("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.delegate = self

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStates() }
            .store(in: &cancellables)

        refreshStates()
    }

    @objc private func toggleSetting(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let newValue = !BarSettings.bool(key, default: BarSettings.defaultValue(for: key))
        UserDefaults.standard.set(newValue, forKey: key)
        if key == BarSettings.launchAtLogin {
            applyLaunchAtLogin(newValue)
        }
    }

    private func applyLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            UserDefaults.standard.set(!isEnabled, forKey: BarSettings.launchAtLogin)
        }
        refreshStates()
    }

    private func refreshStates() {
        statusItem?.button?.appearsDisabled =
            !BarSettings.bool(BarSettings.enabled, default: true)
        for item in menu.items {
            guard let key = item.representedObject as? String else { continue }
            item.state = BarSettings.bool(key, default: BarSettings.defaultValue(for: key)) ? .on : .off
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshStates()
    }
}
