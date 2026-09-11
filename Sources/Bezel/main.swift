import AppKit

let app = NSApplication.shared
// Top-level code runs on the main thread before the run loop starts.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
