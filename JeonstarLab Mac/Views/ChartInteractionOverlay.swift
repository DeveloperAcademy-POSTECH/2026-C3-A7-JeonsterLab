//
//  ChartInteractionOverlay.swift
//  JeonstarLab Mac
//

import AppKit
import SwiftUI

struct ChartInteractionOverlay: NSViewRepresentable {
    var onMagnify: (CGFloat, CGPoint?) -> Void
    var onSpacePan: (CGFloat) -> Void
    var onSpaceChanged: (Bool) -> Void
    var onMouseMoved: (CGPoint?) -> Void
    var onDragChanged: (CGPoint, CGPoint) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.onMagnify = onMagnify
        view.onSpacePan = onSpacePan
        view.onSpaceChanged = onSpaceChanged
        view.onMouseMoved = onMouseMoved
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onMagnify = onMagnify
        nsView.onSpacePan = onSpacePan
        nsView.onSpaceChanged = onSpaceChanged
        nsView.onMouseMoved = onMouseMoved
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }

    final class InteractionView: NSView {
        var onMagnify: ((CGFloat, CGPoint?) -> Void)?
        var onSpacePan: ((CGFloat) -> Void)?
        var onSpaceChanged: ((Bool) -> Void)?
        var onMouseMoved: ((CGPoint?) -> Void)?
        var onDragChanged: ((CGPoint, CGPoint) -> Void)?
        var onDragEnded: (() -> Void)?

        private var keyDownMonitor: Any?
        private var keyUpMonitor: Any?
        private var isSpacePressed = false
        private var dragStart: CGPoint?
        private var lastDragX: CGFloat?
        private var trackingArea: NSTrackingArea?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor

            let magnifyRecognizer = NSMagnificationGestureRecognizer(
                target: self,
                action: #selector(handleMagnification(_:))
            )
            addGestureRecognizer(magnifyRecognizer)
            installKeyMonitors()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            removeKeyMonitors()
        }

        override var acceptsFirstResponder: Bool { true }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }

            let area = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                owner: self
            )
            trackingArea = area
            addTrackingArea(area)
        }

        override func mouseMoved(with event: NSEvent) {
            onMouseMoved?(convert(event.locationInWindow, from: nil))
        }

        override func mouseExited(with event: NSEvent) {
            onMouseMoved?(nil)
        }

        override func mouseDown(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            dragStart = location
            lastDragX = isSpacePressed ? location.x : nil
            window?.makeFirstResponder(self)
        }

        override func mouseDragged(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            guard isSpacePressed else {
                onDragChanged?(dragStart ?? location, location)
                return
            }

            if let lastDragX {
                onSpacePan?(location.x - lastDragX)
            }
            lastDragX = location.x
        }

        override func mouseUp(with event: NSEvent) {
            dragStart = nil
            lastDragX = nil
            onDragEnded?()
        }

        @objc private func handleMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
            guard recognizer.state == .began || recognizer.state == .changed else { return }
            onMagnify?(recognizer.magnification, recognizer.location(in: self))
            recognizer.magnification = 0
        }

        private func installKeyMonitors() {
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 49 {
                    setSpacePressed(true)
                }
                return event
            }

            keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 49 {
                    setSpacePressed(false)
                }
                return event
            }
        }

        private func removeKeyMonitors() {
            if let keyDownMonitor {
                NSEvent.removeMonitor(keyDownMonitor)
            }
            if let keyUpMonitor {
                NSEvent.removeMonitor(keyUpMonitor)
            }
        }

        private func setSpacePressed(_ isPressed: Bool) {
            guard isSpacePressed != isPressed else { return }
            isSpacePressed = isPressed
            if !isPressed {
                lastDragX = nil
            }
            onSpaceChanged?(isPressed)
        }
    }
}
