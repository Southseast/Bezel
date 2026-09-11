import Cocoa

/// Full-width black strip that tints the entire menu bar black, so a notched
/// Mac's notch blends seamlessly into it.
///
/// Sits just BELOW the system menu bar (`.mainMenu - 1`): the menu bar's
/// translucent background samples the pure black, while its items (clock,
/// status icons, app menus) keep rendering on top — fully visible and
/// clickable. Mouse events pass through (`ignoresMouseEvents`). The window
/// manager additionally fades it out while a targeted screen is fullscreen,
/// where there is no menu bar to tint.
///
/// The window spans the whole screen: a plain AppKit view draws the top band,
/// and a child view draws concave-arc corner pieces at all four screen corners
/// covering the desktop slivers between the bar, the screen contour and app
/// windows' rounded corners. The corner pieces fade in/out independently so
/// toggling the "fill rounded corners" setting animates consistently.
class BlackBarWindow: NSPanel {
    /// Reach of the concave corner pieces from each screen edge. Matches the
    /// typical app window corner radius (macOS 26 ≈ 14pt) so their edges are
    /// concentric with window corners and no wallpaper shows through.
    static let cornerPieceSize: CGFloat = 14

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        // Below the system menu bar (so its items stay usable), above all app windows.
        level = .mainMenu - 1
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true

        collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        alphaValue = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func applyContent(menuBarHeight: CGFloat, notchOverflow: CGFloat, roundedCorners: Bool, animated: Bool) {
        let view: BlackBarView
        if let existing = contentView as? BlackBarView {
            view = existing
            view.update(menuBarHeight: menuBarHeight, notchOverflow: notchOverflow,
                        roundedCorners: roundedCorners, animatePieces: animated)
        } else {
            view = BlackBarView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            view.autoresizingMask = [.width, .height]
            view.update(menuBarHeight: menuBarHeight, notchOverflow: notchOverflow,
                        roundedCorners: roundedCorners, animatePieces: false)
            contentView = view
        }
    }

    /// Whether the bar should currently be shown; lets the delayed safety
    /// check distinguish a dropped animation from an intentional hide.
    private(set) var wantsVisible = false

    func showWithAnimation(_ animated: Bool, duration: TimeInterval = 0.6) {
        wantsVisible = true
        orderFrontRegardless()
        // Already fully visible (e.g. setup() re-ran after a space change):
        // restarting the fade here would flash the bar, so do nothing.
        guard animated, alphaValue < 1 else {
            alphaValue = 1
            return
        }
        // Animate from transparent. Occasionally the animation is silently
        // dropped (window not fully realized yet), so the completion handler
        // pins the final value and a delayed check re-asserts it — otherwise
        // the bar would sit invisible at alpha 0 forever.
        alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self, self.wantsVisible else { return }
            self.alphaValue = 1
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) { [weak self] in
            guard let self, self.wantsVisible, self.alphaValue < 1 else { return }
            self.alphaValue = 1
        }
    }

    func hideWithAnimation(_ animated: Bool, duration: TimeInterval = 0.6, completion: (() -> Void)? = nil) {
        wantsVisible = false
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().alphaValue = 0
            }, completionHandler: completion)
        } else {
            alphaValue = 0
            completion?()
        }
    }

    /// Fades the bar out, then orders it out and closes it so no hidden
    /// full-screen windows linger once it is no longer needed.
    func hideAndClose(animated: Bool, duration: TimeInterval = 0.6) {
        hideWithAnimation(animated, duration: duration) { [weak self] in
            self?.orderOut(nil)
            self?.close()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // AppKit clamps windows below the menu bar unless they sit at a higher level;
    // this bar must cover the menu bar strip itself.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Draws the immersive frame: the menu bar band + notch filler, and a child view
/// holding the four concave corner pieces (so their visibility can fade).
final class BlackBarView: NSView {
    private var menuBarHeight: CGFloat = 0 { didSet { needsDisplay = true } }
    /// Extra full-width black below the band when the notch is taller than the
    /// menu bar. Zero on setups where the notch fits within the bar.
    private var notchOverflow: CGFloat = 0 { didSet { needsDisplay = true } }

    private lazy var cornerPiecesView: CornerPiecesView = {
        let view = CornerPiecesView(frame: bounds)
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        return view
    }()

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    func update(menuBarHeight: CGFloat, notchOverflow: CGFloat, roundedCorners: Bool, animatePieces: Bool) {
        let paramsChanged = menuBarHeight != self.menuBarHeight || notchOverflow != self.notchOverflow
        let targetAlpha: CGFloat = roundedCorners ? 1 : 0
        let cornersChanged = cornerPiecesView.alphaValue != targetAlpha
        guard paramsChanged || cornersChanged || cornerPiecesView.menuBarHeight != menuBarHeight else {
            return
        }

        self.menuBarHeight = menuBarHeight
        self.notchOverflow = notchOverflow
        needsDisplay = true

        cornerPiecesView.menuBarHeight = menuBarHeight
        if cornerPiecesView.alphaValue != targetAlpha {
            if animatePieces {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.6
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    cornerPiecesView.animator().alphaValue = targetAlpha
                }
            } else {
                cornerPiecesView.alphaValue = targetAlpha
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()

        // Main band (square top corners: the black display bezel absorbs them)
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: menuBarHeight)).fill()

        // Full-width filler when the notch is taller than the menu bar
        if notchOverflow > 0 {
            NSBezierPath(
                rect: NSRect(x: 0, y: menuBarHeight, width: bounds.width, height: notchOverflow)
            ).fill()
        }
    }
}

/// The four concave corner pieces at the screen edges. Drawn in a separate view
/// so toggling them can crossfade without touching the menu bar band.
final class CornerPiecesView: NSView {
    var menuBarHeight: CGFloat = 0 { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        drawTopPiece(leading: true)
        drawTopPiece(leading: false)
        drawBottomPiece(leading: true)
        drawBottomPiece(leading: false)
    }

    /// Concave quarter arc concentric with an app window's rounded corner:
    /// hugs the window's own edge so no wallpaper shows in between.
    private func drawTopPiece(leading: Bool) {
        let s = BlackBarWindow.cornerPieceSize
        let k: CGFloat = 0.5523
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: menuBarHeight))
        path.line(to: NSPoint(x: s, y: menuBarHeight))
        path.curve(
            to: NSPoint(x: 0, y: menuBarHeight + s),
            controlPoint1: NSPoint(x: s - s * k, y: menuBarHeight),
            controlPoint2: NSPoint(x: 0, y: menuBarHeight + s * k)
        )
        path.close()
        if !leading {
            path.transform(using: AffineTransform(m11: -1, m12: 0, m21: 0, m22: 1,
                                                  tX: bounds.width, tY: 0))
        }
        path.fill()
    }

    private func drawBottomPiece(leading: Bool) {
        let s = BlackBarWindow.cornerPieceSize
        let k: CGFloat = 0.5523
        let H = bounds.height
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: H))
        path.line(to: NSPoint(x: 0, y: H - s))
        path.curve(
            to: NSPoint(x: s, y: H),
            controlPoint1: NSPoint(x: 0, y: H - s + s * k),
            controlPoint2: NSPoint(x: s - s * k, y: H)
        )
        path.close()
        if !leading {
            path.transform(using: AffineTransform(m11: -1, m12: 0, m21: 0, m22: 1,
                                                  tX: bounds.width, tY: 0))
        }
        path.fill()
    }
}
