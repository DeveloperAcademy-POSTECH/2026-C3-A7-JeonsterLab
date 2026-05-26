//
//  MacSnapEventListView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacSnapEventListView: View {
    let events: [SnapEventExport]

    var body: some View {
        if events.isEmpty {
            Text("표시할 스냅 이벤트가 없습니다.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(events) { event in
                    HStack(spacing: 14) {
                        Text("\((event.eventIndex ?? 0) + 1)번")
                            .font(.headline)
                            .frame(width: 46, alignment: .leading)
                        metric("피크", event.peakTime, suffix: "s")
                        metric("가속도", event.peakAcceleration, suffix: "g")
                        metric("회전", event.peakGyro, suffix: "rad/s")
                        Text(event.confidence ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
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
        .frame(minWidth: 84, alignment: .leading)
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%@", locale: Locale(identifier: "en_US_POSIX"), value, suffix)
    }
}
