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
                "스냅 없음",
                systemImage: "waveform.slash",
                description: Text("뒤집기 스냅으로 보이는 구간을 찾지 못했습니다.")
            )
        } else if let selectedEvent {
            VStack(alignment: .leading, spacing: 12) {
                header

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "스냅 발생 시점",
                        value: selectedEvent.snapPeakTimeText,
                        caption: "녹화 시작 기준"
                    )

                    SnapMetricCard(
                        title: "스냅 신뢰도",
                        value: selectedEvent.confidenceText,
                        caption: "초기 추정값"
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "최대 가속도",
                        value: selectedEvent.peakAccelerationText,
                        caption: "스냅 강도"
                    )

                    SnapMetricCard(
                        title: "최대 회전속도",
                        value: selectedEvent.peakGyroText,
                        caption: "손목 회전"
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    SnapMetricCard(
                        title: "피크 시간차",
                        value: selectedEvent.peakDelayText,
                        caption: "힘-회전 타이밍"
                    )

                    SnapMetricCard(
                        title: "스냅 지속시간",
                        value: selectedEvent.snapDurationText,
                        caption: "핵심 구간 길이"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("스냅 구간", value: selectedEvent.snapRangeText)
                    LabeledContent("주 회전축", value: selectedEvent.dominantAxisText)
                    LabeledContent("Roll 변화량", value: selectedEvent.rollRangeText)
                    LabeledContent("Pitch 변화량", value: selectedEvent.pitchRangeText)
                    LabeledContent("Yaw 변화량", value: selectedEvent.yawRangeText)
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
                Text("감지된 뒤집기")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(result.events.count)개 스냅 후보")
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
