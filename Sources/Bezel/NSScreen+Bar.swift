import AppKit
import CoreGraphics

extension NSScreen {
    /// Returns a persistent UUID for this display.
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let uuidString = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
        return uuidString
    }

    /// Whether this display is the Mac's built-in screen.
    var isBuiltInDisplay: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }

    static func screen(withUUID uuid: String) -> NSScreen? {
        NSScreen.screens.first { $0.displayUUID == uuid }
    }
}
