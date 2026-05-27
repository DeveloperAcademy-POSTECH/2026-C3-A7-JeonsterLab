//
//  MacSnapEventListView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacSnapEventListView: View {
    let events: [WorkingSnapEvent]
    @Binding var snapEventLabels: [String: SnapEventLabelPayload]
    let onDelete: (WorkingSnapEvent) -> Void

    var body: some View {
        if events.isEmpty {
            Text("표시할 스냅 이벤트가 없습니다.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(events) { event in
                    let key = event.snapID

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 14) {
                            Text(title(for: event))
                                .font(.headline)
                                .frame(width: 46, alignment: .leading)
                            sourceBadge(event.sourceType)
                            metric("시작", event.startTime, suffix: "s")
                            metric("끝", event.endTime, suffix: "s")
                            metric("피크", event.peakTime, suffix: "s")
                            metric("피크 시간차", event.peakDelay, suffix: "s")
                            metric("지속시간", event.snapDuration, suffix: "s")
                            metric("가속도", event.peakAcceleration, suffix: "g")
                            metric("회전", event.peakGyro, suffix: "rad/s")
                            Text(event.confidence ?? "-")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 56, alignment: .leading)
                            Spacer()
                            Button(role: .destructive) {
                                onDelete(event)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("스냅 이벤트 제거")
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
        labelBinding(for: String(key))
    }

    private func labelBinding(for key: String) -> Binding<RecordingPackageLabel> {
        Binding {
            snapEventLabels[key]?.label ?? .unlabeled
        } set: { newValue in
            var payload = snapEventLabels[key] ?? .empty
            payload.label = newValue
            payload.updatedAt = Date()
            snapEventLabels[key] = payload
        }
    }

    private func notesBinding(for key: String) -> Binding<String> {
        Binding {
            snapEventLabels[key]?.notes ?? ""
        } set: { newValue in
            var payload = snapEventLabels[key] ?? .empty
            payload.notes = newValue
            payload.updatedAt = Date()
            snapEventLabels[key] = payload
        }
    }

    private func title(for event: WorkingSnapEvent) -> String {
        if let eventIndex = event.eventIndex {
            return "\(eventIndex + 1)번"
        }
        return "수동"
    }

    private func sourceBadge(_ sourceType: SnapEventSourceType) -> some View {
        Text(sourceType.displayName)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(sourceType == .manual ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
            .foregroundStyle(sourceType == .manual ? .green : .blue)
            .clipShape(Capsule())
            .frame(minWidth: 72, alignment: .leading)
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
