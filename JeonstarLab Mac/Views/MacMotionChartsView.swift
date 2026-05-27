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
    @Binding var selection: ChartTimeSelection?

    @State private var activeDragMode: ChartSelectionDragMode?

    private let boundaryHandleThreshold: CGFloat = 10

    private var timeRange: ClosedRange<Double> {
        let times = samples.map(\.relativeTime)
        return (times.min() ?? 0)...(times.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            chartCard(title: "사용자 가속도") {
                axisChart(values: [
                    ("X", .blue, \.userAccX),
                    ("Y", .green, \.userAccY),
                    ("Z", .orange, \.userAccZ)
                ])
            }

            chartCard(title: "자이로스코프") {
                axisChart(values: [
                    ("X", .blue, \.rotationRateX),
                    ("Y", .green, \.rotationRateY),
                    ("Z", .orange, \.rotationRateZ)
                ])
            }

            chartCard(title: "자세") {
                axisChart(values: [
                    ("Roll", .blue, \.attitudeRoll),
                    ("Pitch", .green, \.attitudePitch),
                    ("Yaw", .orange, \.attitudeYaw)
                ])
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
        values: [(name: String, color: Color, keyPath: KeyPath<MotionCSVSample, Double>)]
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

            if let selection {
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
        .chartXAxisLabel("relativeTime")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                updateSelection(
                                    startLocation: value.startLocation,
                                    currentLocation: value.location,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                            .onEnded { _ in
                                activeDragMode = nil
                            }
                    )
                    .onContinuousHover { phase in
                        updateCursor(
                            hoverPhase: phase,
                            proxy: proxy,
                            geometry: geometry
                        )
                    }
            }
        }
    }

    private var savedSnapRanges: [SnapPreviewRange] {
        var seenIDs = Set<String>()
        return savedSnapEvents.compactMap { event in
            guard seenIDs.insert(event.snapID).inserted,
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

            if movedStartTime < timeRange.lowerBound {
                movedStartTime = timeRange.lowerBound
                movedEndTime = movedStartTime + originalDuration
            }

            if movedEndTime > timeRange.upperBound {
                movedEndTime = timeRange.upperBound
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
        hoverPhase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            NSCursor.arrow.set()
            return
        }

        switch hoverPhase {
        case .active(let location):
            let plotRect = geometry[plotFrame]
            cursor(for: location, plotRect: plotRect).set()
        case .ended:
            NSCursor.arrow.set()
        }
    }

    private func cursor(for location: CGPoint, plotRect: CGRect) -> NSCursor {
        guard plotRect.contains(location) else {
            return .arrow
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
        guard plotRect.width > 0 else { return timeRange.lowerBound }

        let clampedX = min(max(xPosition, plotRect.minX), plotRect.maxX)
        let progress = (clampedX - plotRect.minX) / plotRect.width
        let duration = timeRange.upperBound - timeRange.lowerBound
        return timeRange.lowerBound + Double(progress) * duration
    }

    private func xPosition(for time: Double, plotRect: CGRect) -> CGFloat {
        let duration = timeRange.upperBound - timeRange.lowerBound
        guard duration > 0 else { return plotRect.minX }

        let clampedTime = min(max(time, timeRange.lowerBound), timeRange.upperBound)
        let progress = (clampedTime - timeRange.lowerBound) / duration
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
