//
//  MacMotionChartsView.swift
//  JeonstarLab Mac
//

import Charts
import SwiftUI

struct MacMotionChartsView: View {
    let samples: [MotionCSVSample]

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
    }
}
