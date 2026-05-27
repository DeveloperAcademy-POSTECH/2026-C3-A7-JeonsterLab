//
//  MacMotionChartsView.swift
//  JeonstarLab Mac
//

import Charts
import SwiftUI

struct MacMotionChartsView: View {
    let samples: [MotionCSVSample]
    @Binding var selection: ChartTimeSelection?

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

            if let selection {
                let normalized = selection.normalized
                RectangleMark(
                    xStart: .value("Selection Start", normalized.startTime),
                    xEnd: .value("Selection End", normalized.endTime)
                )
                .foregroundStyle(.blue.opacity(0.12))

                RuleMark(x: .value("Selection Start", normalized.startTime))
                    .foregroundStyle(.blue)
                    .lineStyle(.init(lineWidth: 1.2, dash: [4, 3]))

                RuleMark(x: .value("Selection End", normalized.endTime))
                    .foregroundStyle(.blue)
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
                                    startX: value.startLocation.x,
                                    currentX: value.location.x,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                    )
            }
        }
    }

    private func updateSelection(
        startX: CGFloat,
        currentX: CGFloat,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }

        let plotRect = geometry[plotFrame]
        let startTime = timeValue(for: startX, plotRect: plotRect)
        let endTime = timeValue(for: currentX, plotRect: plotRect)

        selection = ChartTimeSelection(
            startTime: startTime,
            endTime: endTime
        ).normalized
    }

    private func timeValue(for xPosition: CGFloat, plotRect: CGRect) -> Double {
        guard plotRect.width > 0 else { return timeRange.lowerBound }

        let clampedX = min(max(xPosition, plotRect.minX), plotRect.maxX)
        let progress = (clampedX - plotRect.minX) / plotRect.width
        let duration = timeRange.upperBound - timeRange.lowerBound
        return timeRange.lowerBound + Double(progress) * duration
    }
}
