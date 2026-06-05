//
//  MacSnapEventListView.swift
//  JeonstarLab Mac
//

import SwiftUI
import AppKit

struct MacSnapEventListView: View {
    let events: [WorkingSnapEvent]
    @Binding var snapEventLabels: [String: SnapEventLabelPayload]
    let folders: [SnapFolder]
    let folderForEvent: (WorkingSnapEvent) -> SnapFolder?
    let hasSegment: (WorkingSnapEvent) -> Bool
    let onAddToFolder: (WorkingSnapEvent, SnapFolder) -> Void
    let onRemoveFromFolder: (WorkingSnapEvent, SnapFolder) -> Void
    let onSelect: (WorkingSnapEvent) -> Void
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
                            Button {
                                onSelect(event)
                            } label: {
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
                                    segmentStatusDot(for: event)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("그래프에서 이 스냅 구간 보기")

                            Button(role: .destructive) {
                                onDelete(event)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("스냅 이벤트 제거")
                        }

                        HStack(alignment: .top, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("라벨")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                NumberShortcutPopUpButton(
                                    placeholder: currentLabel(for: event).displayName,
                                    selectedIndex: labelSelectedIndex(for: event),
                                    options: labelShortcutOptions(for: key)
                                )
                                .frame(width: 122, height: 24)
                            }

                            TextField("스냅 노트", text: notesBinding(for: key), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("폴더")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            folderMembershipControls(for: event)
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

    @ViewBuilder
    private func folderMembershipControls(for event: WorkingSnapEvent) -> some View {
        let assignedFolder = folderForEvent(event)
        let label = currentLabel(for: event)
        HStack(alignment: .center, spacing: 10) {
            if let assignedFolder {
                Text("\(assignedFolder.name) 폴더에 포함됨")
                    .font(.callout)

                Button("폴더에서 제거", role: .destructive) {
                    onRemoveFromFolder(event, assignedFolder)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("아직 폴더에 추가되지 않았습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if label == .unlabeled {
                    Text("라벨을 먼저 선택해야 폴더에 추가할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    NumberShortcutPopUpButton(
                        placeholder: "폴더에 추가",
                        selectedIndex: nil,
                        emptyMessage: "생성된 폴더가 없습니다.",
                        options: folderShortcutOptions(for: event)
                    )
                    .frame(width: 104, height: 24)
                }
            }
        }
    }

    private func labelSelectedIndex(for event: WorkingSnapEvent) -> Int? {
        RecordingPackageLabel.allCases.firstIndex(of: currentLabel(for: event))
    }

    private func labelShortcutOptions(for key: String) -> [NumberShortcutMenuOption] {
        RecordingPackageLabel.allCases.enumerated().map { index, label in
            NumberShortcutMenuOption(index: index + 1, title: label.displayName) {
                labelBinding(for: key).wrappedValue = label
            }
        }
    }

    private func folderShortcutOptions(for event: WorkingSnapEvent) -> [NumberShortcutMenuOption] {
        folders.enumerated().map { index, folder in
            NumberShortcutMenuOption(index: index + 1, title: folder.name) {
                onAddToFolder(event, folder)
            }
        }
    }

    private func currentLabel(for event: WorkingSnapEvent) -> RecordingPackageLabel {
        snapEventLabels[event.snapID]?.label ?? event.label
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

    private func segmentStatusDot(for event: WorkingSnapEvent) -> some View {
        let exists = hasSegment(event)
        return Circle()
            .fill(exists ? Color.green : Color.red)
            .frame(width: 9, height: 9)
            .help(exists ? "세그먼트 생성됨" : "세그먼트 없음")
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

private struct NumberShortcutMenuOption: Identifiable {
    let index: Int
    let title: String
    let action: () -> Void

    var id: Int { index }
    var prefixedTitle: String { "\(index). \(title)" }
    var hasShortcut: Bool { (1...9).contains(index) }
}

private struct NumberShortcutPopUpButton: NSViewRepresentable {
    let placeholder: String
    let selectedIndex: Int?
    var emptyMessage: String = "선택할 항목이 없습니다."
    let options: [NumberShortcutMenuOption]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popUpButton.controlSize = .small
        popUpButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        popUpButton.target = context.coordinator
        popUpButton.action = #selector(Coordinator.selectItem(_:))
        return popUpButton
    }

    func updateNSView(_ popUpButton: NSPopUpButton, context: Context) {
        context.coordinator.options = options
        popUpButton.removeAllItems()

        if options.isEmpty {
            popUpButton.addItem(withTitle: emptyMessage)
            popUpButton.item(at: 0)?.isEnabled = false
            popUpButton.isEnabled = false
            return
        }

        popUpButton.isEnabled = true
        for option in options {
            let item = NSMenuItem(
                title: option.prefixedTitle,
                action: #selector(Coordinator.selectItem(_:)),
                keyEquivalent: option.hasShortcut ? "\(option.index)" : ""
            )
            item.target = context.coordinator
            item.tag = option.index
            popUpButton.menu?.addItem(item)
        }

        if let selectedIndex, options.indices.contains(selectedIndex) {
            popUpButton.selectItem(at: selectedIndex)
        } else {
            popUpButton.addItem(withTitle: placeholder)
            if let placeholderItem = popUpButton.item(withTitle: placeholder) {
                placeholderItem.isEnabled = false
                popUpButton.select(placeholderItem)
            }
        }
    }

    final class Coordinator: NSObject {
        var options: [NumberShortcutMenuOption] = []

        @objc func selectItem(_ sender: Any?) {
            let tag: Int?
            if let menuItem = sender as? NSMenuItem {
                tag = menuItem.tag
            } else if let popUpButton = sender as? NSPopUpButton {
                tag = popUpButton.selectedItem?.tag
            } else {
                tag = nil
            }

            guard let tag,
                  let option = options.first(where: { $0.index == tag }) else {
                return
            }
            option.action()
        }
    }
}
