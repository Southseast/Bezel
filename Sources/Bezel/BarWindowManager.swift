import AppKit

/// Keeps one black bar window per targeted display and re-syncs everything
/// whenever the screen configuration or any setting changes. All paths are
/// idempotent, so observers can simply call `setup()` again.
///
/// Uses only public APIs: `.canJoinAllSpaces` floats the bar over every
/// desktop. Known limitation: during *animated* Cmd+Tab space switches the
/// window server briefly detaches floating-level windows, so the bar can blink
/// for the duration of the transition. Eliminating that requires private
/// CGS space tricks that either break the menu bar layering or risk breakage
/// on macOS updates, so the blink is accepted.
@MainActor
final class BarWindowManager {
    static let shared = BarWindowManager()

    private var windows: [String: BlackBarWindow] = [:]
    private var observers: [NSObjectProtocol] = []
    private var started = false
    private var fullscreenScreens: Set<String> = []

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setup() }
        })
        observers.append(center.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setup() }
        })

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            observers.append(workspaceCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.updateFullscreenVisibility() }
            })
        }

        DispatchQueue.main.async { [weak self] in
            self?.setup()
            self?.updateFullscreenVisibility()
        }
    }

    func setup() {
        let enabled = BarSettings.bool(BarSettings.enabled, default: true)
        let animated = BarSettings.bool(BarSettings.animated, default: true)

        guard enabled else {
            // Retire the windows so no full-screen ones linger while the
            // feature is off; they are recreated when it is re-enabled.
            let retired = windows
            windows.removeAll()
            retired.values.forEach { $0.hideAndClose(animated: animated) }
            return
        }

        let builtInOnly = BarSettings.bool(BarSettings.builtInOnly, default: false)
        let targets = builtInOnly ? NSScreen.screens.filter(\.isBuiltInDisplay) : NSScreen.screens
        let targetUUIDs = Set(targets.compactMap(\.displayUUID))

        // Drop windows for screens that are gone or no longer targeted.
        for uuid in windows.keys.filter({ !targetUUIDs.contains($0) }) {
            windows.removeValue(forKey: uuid)?.hideAndClose(animated: animated)
        }

        let roundedCorners = BarSettings.bool(BarSettings.roundedCorners, default: true)
        for screen in targets {
            guard let uuid = screen.displayUUID else { continue }

            // Zero when the menu bar auto-hides (or the display has none):
            // the band then just spans the notch height, which is what the
            // revealed menu bar roughly covers anyway.
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            let notchHeight = screen.safeAreaInsets.top > 0
                ? screen.safeAreaInsets.top
                : BarSettings.fallbackNotchHeight
            let notchOverflow = max(0, notchHeight - menuBarHeight)

            if windows[uuid] == nil {
                windows[uuid] = BlackBarWindow()
            }
            let bar = windows[uuid]!
            bar.applyContent(menuBarHeight: menuBarHeight, notchOverflow: notchOverflow,
                             roundedCorners: roundedCorners, animated: animated)
            // Window spans the whole screen: the drawn content is the top band,
            // and the bottom corner pieces live at the opposite end.
            bar.setFrame(screen.frame, display: true)

            if fullscreenScreens.contains(uuid) {
                bar.hideWithAnimation(animated)
            } else {
                bar.showWithAnimation(animated)
            }
        }
    }

    /// A targeted screen is fullscreen when either its name equals the
    /// frontmost app's name (macOS renames it) or a layer-0 window covers its
    /// frame exactly. Nothing to tint there — fade the bar out.
    private func updateFullscreenVisibility() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName
        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] ?? []

        var covered: Set<String> = []
        for screen in NSScreen.screens {
            let frame = screen.frame
            let nameMatch = frontmost == screen.localizedName
            let exactWindow = onScreen.contains { w in
                guard w[kCGWindowLayer as String] as? Int == 0,
                      let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                      let x = b["X"], let y = b["Y"],
                      let width = b["Width"], let height = b["Height"] else { return false }
                return abs(x - frame.minX) < 0.5 && abs(y - frame.minY) < 0.5
                    && abs(width - frame.width) < 0.5 && abs(height - frame.height) < 0.5
            }
            if (nameMatch || exactWindow), let uuid = screen.displayUUID {
                covered.insert(uuid)
            }
        }

        guard covered != fullscreenScreens else { return }
        fullscreenScreens = covered
        setup()
    }
}
