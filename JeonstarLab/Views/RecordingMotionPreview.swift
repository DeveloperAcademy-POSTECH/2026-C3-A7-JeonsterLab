import Charts
import SwiftUI

struct RecordingMotionPreview: View {
    let samples: [MotionSample]
    let samplingRate: Int
    @State private var kind: MotionPreviewKind = .acceleration
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let times = MotionPreviewTimeline.seconds(samples: samples, samplingRate: samplingRate)
        VStack(alignment: .leading, spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                picker.pickerStyle(.menu)
            } else {
                picker.pickerStyle(.segmented)
            }
            HStack {
                Text(kind == .acceleration ? "User Acceleration" : kind.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(kind.unit).font(.caption).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(kind.axes, id: \.name) { axis in
                    ForEach(samples.indices, id: \.self) { index in
                        let value = samples[index][keyPath: axis.value]
                        if value.isFinite {
                            LineMark(x: .value("Time", times[index]), y: .value(axis.name, value))
                                .foregroundStyle(by: .value("Axis", axis.name))
                                .lineStyle(StrokeStyle(lineWidth: 1.3))
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: kind.axes.map(\.name), range: [Color.blue, .green, .orange])
            .chartXScale(domain: 0...max(times.last ?? 0, 0.02))
            .chartXAxisLabel("Time (s)")
            .chartLegend(position: .bottom, alignment: .leading)
            .chartPlotStyle { $0.clipped() }
            .frame(height: 220)
            .accessibilityLabel("\(kind.title), three axes, \(samples.count) motion samples")
        }
        .padding(.vertical, 8)
    }

    private var picker: some View {
        Picker("Sensor", selection: $kind) {
            ForEach(MotionPreviewKind.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden()
    }
}
