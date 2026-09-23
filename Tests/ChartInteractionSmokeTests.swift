import AppKit
import SwiftUI

@main
struct ChartInteractionSmokeTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless], backing: .buffered, defer: false)
        let view = ChartInteractionOverlay.InteractionView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView = view
        precondition(view.isFlipped, "Chart interaction must use GeometryReader's top-left coordinates")
        var captured: (CGPoint, CGPoint)?
        var clicks: [CGPoint] = []
        view.onClick = { clicks.append($0) }
        view.onDragChanged = { captured = ($0, $1) }
        for y in [20.0, 100.0, 180.0] {
            let down = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 40, y: 200 - y),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
            let drag = NSEvent.mouseEvent(with: .leftMouseDragged, location: NSPoint(x: 160, y: 200 - y),
                modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber,
                context: nil, eventNumber: 2, clickCount: 1, pressure: 1)!
            view.mouseDown(with: down)
            view.mouseDragged(with: drag)
            precondition(captured?.0 == CGPoint(x: 40, y: y))
            precondition(captured?.1 == CGPoint(x: 160, y: y))
            view.mouseUp(with: drag)
        }
        precondition(clicks.isEmpty, "Dragging must not select a suggestion as a click")
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 70, y: 160),
            modifierFlags: [], timestamp: 2, windowNumber: window.windowNumber,
            context: nil, eventNumber: 3, clickCount: 1, pressure: 1)!
        view.mouseDown(with: click)
        view.mouseUp(with: click)
        precondition(clicks == [CGPoint(x: 70, y: 40)])
        print("PASS: chart drag coordinates at top, middle, and bottom use the same top-left origin")
    }
}
