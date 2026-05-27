//
//  MacMotionChartsView.swift
//  JeonstarLab Mac
//

import Charts
import AppKit
import SwiftUI

struct MacMotionChartsView: View {
    let samples: [MotionCSVSample]
    let savedSnapEvents: [WorkingSnapEvent]
    let showSavedSnapPreviews: Bool
    let hasSelectionConflict: Bool
    let editingSnapID: String?
    let editingOriginalSelection: ChartTimeSelection?
    let showsCandidateSelection: Bool
    let fullTimeRange: ClosedRange<Double>
    @Binding var selection: ChartTimeSelection?
    @Binding var visibleTimeRange: ChartVisibleTimeRange

    @State private var activeDragMode: ChartSelectionDragMode?
    @State private var isSpacePressed = false
    @State private var hoverLocation: CGPoint?

    private let boundaryHandleThreshold: CGFloat = 24
    private let minimumZoomDuration = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            chartCard(title: "사용자 가속도") {
                axisChart(values: [
                    ("X", .blue, \.userAccX),
                    ("Y", .green, \.userAccY),
                    ("Z", .orange, \.userAccZ)
                ], yDomain: yDomain(for: [\.userAccX, \.userAccY, \.userAccZ]))
            }

            chartCard(title: "자이로스코프") {
                axisChart(values: [
                    ("X", .blue, \.rotationRateX),
                    ("Y", .green, \.rotationRateY),
                    ("Z", .orange, \.rotationRateZ)
                ], yDomain: yDomain(for: [\.rotationRateX, \.rotationRateY, \.rotationRateZ]))
            }

            chartCard(title: "자세") {
                axisChart(values: [
                    ("Roll", .blue, \.attitudeRoll),
                    ("Pitch", .green, \.attitudePitch),
                    ("Yaw", .orange, \.attitudeYaw)
                ], yDomain: yDomain(for: [\.attitudeRoll, \.attitudePitch, \.attitudeYaw]))
            }
        }
    }

    private func chartCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .frame(height: 220)
        }
    }

    private func axisChart(
        values: [(name: String, color: Color, keyPath: KeyPath<MotionCSVSample, Double>)],
        yDomain: ClosedRange<Double>
    ) -> some View {
        Chart {
            ForEach(values, id: \.name) { axis in
                ForEach(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.relativeTime),
                        y: .value(axis.name, sample[keyPath: axis.keyPath])
                    )
                    .foregroundStyle(by: .value("Axis", axis.name))
                    .lineStyle(.init(lineWidth: 1.4))
                }
            }

            if showSavedSnapPreviews {
                ForEach(savedSnapRanges) { range in
                    RectangleMark(
                        xStart: .value("Saved Snap Start", range.startTime),
                        xEnd: .value("Saved Snap End", range.endTime)
                    )
                    .foregroundStyle(.gray.opacity(0.10))

                    RuleMark(x: .value("Saved Snap Start", range.startTime))
                        .foregroundStyle(.gray.opacity(0.55))
                        .lineStyle(.init(lineWidth: 0.8, dash: [2, 3]))

                    RuleMark(x: .value("Saved Snap End", range.endTime))
                        .foregroundStyle(.gray.opacity(0.55))
                        .lineStyle(.init(lineWidth: 0.8, dash: [2, 3]))
                }
            }

            if let editingOriginalSelection {
                let normalized = editingOriginalSelection.normalized
                RectangleMark(
                    xStart: .value("Original Snap Start", normalized.startTime),
                    xEnd: .value("Original Snap End", normalized.endTime)
                )
                .foregroundStyle(.green.opacity(0.14))

                RuleMark(x: .value("Original Snap Start", normalized.startTime))
                    .foregroundStyle(.green)
                    .lineStyle(.init(lineWidth: 1.3, dash: [5, 3]))

                RuleMark(x: .value("Original Snap End", normalized.endTime))
                    .foregroundStyle(.green)
                    .lineStyle(.init(lineWidth: 1.3, dash: [5, 3]))
            }

            if let selection, showsCandidateSelection {
                let normalized = selection.normalized
                let selectionColor = hasSelectionConflict ? Color.red : Color.blue
                RectangleMark(
                    xStart: .value("Selection Start", normalized.startTime),
                    xEnd: .value("Selection End", normalized.endTime)
                )
                .foregroundStyle(selectionColor.opacity(0.14))

                RuleMark(x: .value("Selection Start", normalized.startTime))
                    .foregroundStyle(selectionColor)
                    .lineStyle(.init(lineWidth: 1.2, dash: [4, 3]))

                RuleMark(x: .value("Selection End", normalized.endTime))
                    .foregroundStyle(selectionColor)
                    .lineStyle(.init(lineWidth: 1.2, dash: [4, 3]))
            }
        }
        .chartForegroundStyleScale([
            "X": .blue,
            "Y": .green,
            "Z": .orange,
            "Roll": .blue,
            "Pitch": .green,
            "Yaw": .orange
        ])
        .chartXScale(domain: visibleTimeRange.range)
        .chartYScale(domain: yDomain)
        .chartXAxisLabel("relativeTime")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ChartInteractionOverlay(
                    onMagnify: { magnification, location in
                        updateZoom(
                            magnification: magnification,
                            location: location ?? hoverLocation,
                            proxy: proxy,
                            geometry: geometry
                        )
                    },
                    onSpacePan: { deltaX in
                        panVisibleRange(
                            deltaX: deltaX,
                            proxy: proxy,
                            geometry: geometry
                        )
                    },
                    onSpaceChanged: { isPressed in
                        isSpacePressed = isPressed
                        if isPressed {
                            activeDragMode = nil
                            NSCursor.openHand.set()
                        }
                    },
                    onMouseMoved: { location in
                        hoverLocation = location
                        updateCursor(
                            location: location,
                            proxy: proxy,
                            geometry: geometry
                        )
                    },
                    onDragChanged: { startLocation, currentLocation in
                        updateSelection(
                            startLocation: startLocation,
                            currentLocation: currentLocation,
                            proxy: proxy,
                            geometry: geometry
                        )
                    },
                    onDragEnded: {
                        activeDragMode = nil
                    }
                )
                .contentShape(Rectangle())
                .onDisappear {
                    activeDragMode = nil
                    isSpacePressed = false
                    hoverLocation = nil
                }
            }
        }
    }

    private func yDomain(
        for keyPaths: [KeyPath<MotionCSVSample, Double>]
    ) -> ClosedRange<Double> {
        let values = samples.flatMap { sample in
            keyPaths.map { sample[keyPath: $0] }
        }

        guard let minValue = values.min(),
              let maxValue = values.max() else {
            return -1...1
        }

        if minValue == maxValue {
            let padding = max(abs(minValue) * 0.1, 1)
            return (minValue - padding)...(maxValue + padding)
        }

        let padding = max((maxValue - minValue) * 0.08, 0.05)
        return (minValue - padding)...(maxValue + padding)
    }

    private func updateZoom(
        magnification: CGFloat,
        location: CGPoint?,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard abs(magnification) > 0.0001 else { return }

        let anchorTime = anchorTime(
            for: location,
            proxy: proxy,
            geometry: geometry
        )
        let scale = max(0.2, 1 + Double(magnification))
        visibleTimeRange = visibleTimeRange.zoomed(
            scale: scale,
            anchorTime: anchorTime,
            fullRange: fullTimeRange,
            minimumDuration: minimumVisibleDuration
        )
    }

    private func panVisibleRange(
        deltaX: CGFloat,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }

        let plotRect = geometry[plotFrame]
        guard plotRect.width > 0 else { return }

        let secondsPerPoint = visibleTimeRange.duration / Double(plotRect.width)
        visibleTimeRange = visibleTimeRange.panned(
            by: -Double(deltaX) * secondsPerPoint,
            fullRange: fullTimeRange,
            minimumDuration: minimumVisibleDuration
        )
    }

    private func anchorTime(
        for location: CGPoint?,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> Double? {
        guard let location,
              let plotFrame = proxy.plotFrame else {
            return nil
        }

        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else {
            return nil
        }

        return timeValue(for: location.x, plotRect: plotRect)
    }

    private var minimumVisibleDuration: Double {
        let fullDuration = fullTimeRange.upperBound - fullTimeRange.lowerBound
        return min(minimumZoomDuration, max(0, fullDuration))
    }

    private var savedSnapRanges: [SnapPreviewRange] {
        var seenIDs = Set<String>()
        return savedSnapEvents.compactMap { event in
            guard event.snapID != editingSnapID,
                  seenIDs.insert(event.snapID).inserted,
                  let startTime = event.startTime,
                  let endTime = event.endTime else {
                return nil
            }

            let normalized = ChartTimeSelection(
                startTime: startTime,
                endTime: endTime
            ).normalized
            guard normalized.duration > 0 else { return nil }

            return SnapPreviewRange(
                id: event.snapID,
                startTime: normalized.startTime,
                endTime: normalized.endTime
            )
        }
    }

    private func updateSelection(
        startLocation: CGPoint,
        currentLocation: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }

        let plotRect = geometry[plotFrame]
        guard plotRect.contains(startLocation) else { return }

        let startTime = timeValue(for: startLocation.x, plotRect: plotRect)
        let currentTime = timeValue(for: currentLocation.x, plotRect: plotRect)
        let mode = activeDragMode ?? dragMode(
            mouseDownX: startLocation.x,
            mouseDownTime: startTime,
            plotRect: plotRect
        )
        activeDragMode = mode

        switch mode {
        case .creating(let anchorTime):
            selection = ChartTimeSelection(
                startTime: anchorTime,
                endTime: currentTime
            ).normalized
        case .resizingStart(let fixedEndTime):
            selection = ChartTimeSelection(
                startTime: currentTime,
                endTime: fixedEndTime
            ).normalized
        case .resizingEnd(let fixedStartTime):
            selection = ChartTimeSelection(
                startTime: fixedStartTime,
                endTime: currentTime
            ).normalized
        case .moving(let originalStartTime, let originalEndTime, let anchorTime):
            let delta = currentTime - anchorTime
            let originalDuration = originalEndTime - originalStartTime
            var movedStartTime = originalStartTime + delta
            var movedEndTime = originalEndTime + delta

            if movedStartTime < fullTimeRange.lowerBound {
                movedStartTime = fullTimeRange.lowerBound
                movedEndTime = movedStartTime + originalDuration
            }

            if movedEndTime > fullTimeRange.upperBound {
                movedEndTime = fullTimeRange.upperBound
                movedStartTime = movedEndTime - originalDuration
            }

            selection = ChartTimeSelection(
                startTime: movedStartTime,
                endTime: movedEndTime
            ).normalized
        }
    }

    private func dragMode(
        mouseDownX: CGFloat,
        mouseDownTime: Double,
        plotRect: CGRect
    ) -> ChartSelectionDragMode {
        guard let selection else {
            return .creating(anchorTime: mouseDownTime)
        }

        let normalized = selection.normalized
        let startX = xPosition(for: normalized.startTime, plotRect: plotRect)
        let endX = xPosition(for: normalized.endTime, plotRect: plotRect)

        if abs(mouseDownX - startX) <= boundaryHandleThreshold {
            return .resizingStart(fixedEndTime: normalized.endTime)
        }
        if abs(mouseDownX - endX) <= boundaryHandleThreshold {
            return .resizingEnd(fixedStartTime: normalized.startTime)
        }
        if mouseDownX > min(startX, endX) && mouseDownX < max(startX, endX) {
            return .moving(
                originalStartTime: normalized.startTime,
                originalEndTime: normalized.endTime,
                anchorTime: mouseDownTime
            )
        }
        return .creating(anchorTime: mouseDownTime)
    }

    private func updateCursor(
        location: CGPoint?,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            NSCursor.arrow.set()
            return
        }

        guard let location else {
            NSCursor.arrow.set()
            return
        }

        let plotRect = geometry[plotFrame]
        cursor(for: location, plotRect: plotRect).set()
    }

    private func cursor(for location: CGPoint, plotRect: CGRect) -> NSCursor {
        guard plotRect.contains(location) else {
            return .arrow
        }

        if isSpacePressed {
            return .openHand
        }

        guard let selection else {
            return .crosshair
        }

        let normalized = selection.normalized
        let startX = xPosition(for: normalized.startTime, plotRect: plotRect)
        let endX = xPosition(for: normalized.endTime, plotRect: plotRect)

        if abs(location.x - startX) <= boundaryHandleThreshold
            || abs(location.x - endX) <= boundaryHandleThreshold {
            return .resizeLeftRight
        }
        if location.x > min(startX, endX) && location.x < max(startX, endX) {
            return .openHand
        }

        return .crosshair
    }

    private func timeValue(for xPosition: CGFloat, plotRect: CGRect) -> Double {
        guard plotRect.width > 0 else { return visibleTimeRange.lowerBound }

        let clampedX = min(max(xPosition, plotRect.minX), plotRect.maxX)
        let progress = (clampedX - plotRect.minX) / plotRect.width
        return visibleTimeRange.lowerBound + Double(progress) * visibleTimeRange.duration
    }

    private func xPosition(for time: Double, plotRect: CGRect) -> CGFloat {
        let duration = visibleTimeRange.duration
        guard duration > 0 else { return plotRect.minX }

        let clampedTime = min(max(time, visibleTimeRange.lowerBound), visibleTimeRange.upperBound)
        let progress = (clampedTime - visibleTimeRange.lowerBound) / duration
        return plotRect.minX + CGFloat(progress) * plotRect.width
    }
}

private enum ChartSelectionDragMode {
    case creating(anchorTime: Double)
    case resizingStart(fixedEndTime: Double)
    case resizingEnd(fixedStartTime: Double)
    case moving(originalStartTime: Double, originalEndTime: Double, anchorTime: Double)
}

private struct SnapPreviewRange: Identifiable {
    let id: String
    let startTime: Double
    let endTime: Double
}
