//
//  MacSnapEventListView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacSnapEventListView: View {
    let events: [SnapEventExport]
    @Binding var snapLabels: [Int: SnapEventLabelPayload]

    var body: some View {
        if events.isEmpty {
            Text("표시할 스냅 이벤트가 없습니다.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(events) { event in
                    let key = event.labelKey

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 14) {
                            Text("\((event.eventIndex ?? 0) + 1)번")
                                .font(.headline)
                                .frame(width: 46, alignment: .leading)
                            metric("피크", event.peakTime, suffix: "s")
                            metric("피크 시간차", event.peakDelay, suffix: "s")
                            metric("지속시간", event.snapDuration, suffix: "s")
                            metric("가속도", event.peakAcceleration, suffix: "g")
                            metric("회전", event.peakGyro, suffix: "rad/s")
                            Text(event.confidence ?? "-")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 56, alignment: .leading)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Picker("라벨", selection: labelBinding(for: key)) {
                                ForEach(RecordingPackageLabel.allCases) { label in
                                    Text(label.displayName).tag(label)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 130)

                            TextField("스냅 노트", text: notesBinding(for: key), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, 6)

                    Divider()
                }
            }
        }
    }

    private func labelBinding(for key: Int) -> Binding<RecordingPackageLabel> {
        Binding {
            snapLabels[key]?.label ?? .unlabeled
        } set: { newValue in
            var payload = snapLabels[key] ?? .empty
            payload.label = newValue
            payload.updatedAt = Date()
            snapLabels[key] = payload
        }
    }

    private func notesBinding(for key: Int) -> Binding<String> {
        Binding {
            snapLabels[key]?.notes ?? ""
        } set: { newValue in
            var payload = snapLabels[key] ?? .empty
            payload.notes = newValue
            payload.updatedAt = Date()
            snapLabels[key] = payload
        }
    }

    private func metric(_ title: String, _ value: Double?, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatted(value, suffix: suffix))
                .font(.callout)
        }
        .frame(minWidth: 76, alignment: .leading)
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%@", locale: Locale(identifier: "en_US_POSIX"), value, suffix)
    }
}
