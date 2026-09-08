//
//  SnapAnalysisSummaryView.swift
//  Wrist Motion
//

import SwiftUI

struct SnapAnalysisSummaryView: View {
    let result: SnapAnalysisResult
    @Binding var selectedEventIndex: Int

    private var selectedEvent: SnapEventSummary? {
        result.event(at: selectedEventIndex)
    }

    var body: some View {
        if result.events.isEmpty {
            ContentUnavailableView(
                "No Snaps",
                systemImage: "waveform.slash",
                description: Text("No possible flipping snaps were found.")
            )
        } else if let selectedEvent {
            VStack(alignment: .leading, spacing: 12) {
                header

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "Snap Time",
                        value: selectedEvent.snapPeakTimeText,
                        caption: "Since recording started"
                    )

                    SnapMetricCard(
                        title: "Snap Confidence",
                        value: selectedEvent.confidenceText,
                        caption: "Initial estimate"
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "Peak Acceleration",
                        value: selectedEvent.peakAccelerationText,
                        caption: "Snap intensity"
                    )

                    SnapMetricCard(
                        title: "Peak Rotation",
                        value: selectedEvent.peakGyroText,
                        caption: "Wrist rotation"
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "Peak Delay",
                        value: selectedEvent.peakDelayText,
                        caption: "Acceleration–rotation timing"
                    )

                    SnapMetricCard(
                        title: "Snap Duration",
                        value: selectedEvent.snapDurationText,
                        caption: "Core range duration"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Snap Range", value: selectedEvent.snapRangeText)
                    LabeledContent("Dominant Axis", value: selectedEvent.dominantAxisText)
                    LabeledContent("Roll Range", value: selectedEvent.rollRangeText)
                    LabeledContent("Pitch Range", value: selectedEvent.pitchRangeText)
                    LabeledContent("Yaw Range", value: selectedEvent.yawRangeText)
                }
                .font(.subheadline)

                Text(selectedEvent.interpretation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.vertical, 4)
            .onChange(of: result.events.count) { _, newCount in
                guard newCount > 0 else {
                    selectedEventIndex = 0
                    return
                }

                if selectedEventIndex >= newCount {
                    selectedEventIndex = newCount - 1
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Detected Flips")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(result.events.count) possible snaps")
                    .font(.subheadline)
                    .bold()
            }

            Spacer()

            Picker("", selection: $selectedEventIndex) {
                ForEach(result.events.indices, id: \.self) { index in
                    Text(result.events[index].eventTitle)
                        .tag(index)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

struct SnapMetricCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
