//
//  MacSnapEventListView.swift
//  JeonstarLab Mac
//

import SwiftUI
import AppKit

struct MacSnapEventListView: View {
    @Environment(\.projectLabelOptions) private var projectLabels
    let events: [WorkingSnapEvent]
    @Binding var snapEventLabels: [String: SnapEventLabelPayload]
    let folders: [SnapFolder]
    let folderForEvent: (WorkingSnapEvent) -> SnapFolder?
    let hasSegment: (WorkingSnapEvent) -> Bool
    let onAddToFolder: (WorkingSnapEvent, SnapFolder) -> Void
    let onRemoveFromFolder: (WorkingSnapEvent, SnapFolder) -> Void
    let onSelect: (WorkingSnapEvent) -> Void
    let onDelete: (WorkingSnapEvent) -> Void

    var isInspector = false
    var selectedSnapID: String?

    var body: some View {
        if events.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No snaps yet.").fontWeight(.medium)
                Text("Select a range on a chart, then save it as a snap.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        } else {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(events) { event in
                    if isInspector {
                        inspector(for: event)
                    } else {
                        summaryRow(for: event)
                    }
                }
            }
        }
    }

    private func summaryRow(for event: WorkingSnapEvent) -> some View {
        HStack(spacing: 8) {
            Button { onSelect(event) } label: {
                HStack(spacing: 12) {
                    Text(title(for: event)).font(.callout.weight(.semibold))
                        .frame(width: 48, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentLabel(for: event).displayName).fontWeight(.medium)
                        Text(event.sourceType.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(rangeText(for: event)).monospacedDigit().font(.callout)
                    segmentStatusDot(for: event)
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Select this snap to edit its label, notes, and range")
            .accessibilityLabel("Select snap \(title(for: event)), \(currentLabel(for: event).displayName)")
            Button(role: .destructive) { onDelete(event) } label: {
                Label("Delete Snap", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Delete snap")
        }
        .padding(10)
        .background(selectedSnapID == event.snapID ? EditorPalette.accent.opacity(0.13) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private func inspector(for event: WorkingSnapEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Snap \(title(for: event))").font(.headline)
                Spacer()
                sourceBadge(event.sourceType)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Label").font(.caption).foregroundStyle(.secondary)
                NumberShortcutMenuButton(
                    title: currentLabel(for: event).displayName,
                    labelStyle: currentLabel(for: event),
                    options: labelShortcutOptions(for: event.snapID)
                )
                .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Notes").font(.caption).foregroundStyle(.secondary)
                TextField("Add snap notes…", text: notesBinding(for: event.snapID), axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Folder").font(.caption).foregroundStyle(.secondary)
                folderMembershipControls(for: event)
            }
            Text("Labels and notes are saved automatically.")
                .font(.caption2).foregroundStyle(.secondary)
            Divider()
            HStack {
                metric("Peak Delay", event.peakDelay, suffix: "s")
                Spacer()
                VStack(alignment: .leading) {
                    Text("Confidence").font(.caption).foregroundStyle(.secondary)
                    Text(event.confidence ?? "–")
                }
            }
            HStack {
                Text("Segment File").foregroundStyle(.secondary)
                Spacer()
                segmentStatusDot(for: event)
            }
            .font(.caption)
        }
    }

    private func rangeText(for event: WorkingSnapEvent) -> String {
        guard let start = event.startTime, let end = event.endTime else { return "No range" }
        return String(format: "%.2f – %.2f s", start, end)
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
        VStack(alignment: .leading, spacing: 8) {
            if let assignedFolder {
                Text("In \(assignedFolder.name)")
                    .font(.callout)

                Button("Remove from Folder", role: .destructive) {
                    onRemoveFromFolder(event, assignedFolder)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Not added to a folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if label == .unlabeled {
                    Text("Choose a label before adding this snap to a folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    NumberShortcutMenuButton(
                        title: "Add to Folder",
                        emptyMessage: "No folders available.",
                        options: folderShortcutOptions(for: event)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func labelShortcutOptions(for key: String) -> [NumberShortcutMenuOption] {
        projectLabels.enumerated().map { index, definition in
            let label = definition.label
            return NumberShortcutMenuOption(index: index + 1, title: label.displayName, shortcut: definition.shortcut ?? 0) {
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
        if event.sourceType == .autoSegment { return "Auto" }
        if let eventIndex = event.eventIndex {
            return "#\(eventIndex + 1)"
        }
        return "Manual"
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
            .help(exists ? "Segment saved" : "Missing Segments")
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
    var shortcut: Int? = nil
    let action: () -> Void

    var id: Int { index }
    var shortcutNumber: Int { shortcut ?? index }
    var hasShortcut: Bool { (1...9).contains(shortcutNumber) }
}

private struct NumberShortcutMenuButton: View {
    let title: String
    var labelStyle: RecordingPackageLabel?
    var emptyMessage: String = "No options available."
    let options: [NumberShortcutMenuOption]

    @State private var isPresented = false

    var body: some View {
        button
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            NumberShortcutMenuContent(
                emptyMessage: emptyMessage,
                options: options,
                isPresented: $isPresented
            )
        }
    }

    @ViewBuilder
    private var button: some View {
        if let labelStyle {
            Button {
                isPresented = true
            } label: {
                labelContent
                    .font(.callout)
                    .foregroundStyle(labelStyle.chipForegroundColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(labelStyle.chipBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(labelStyle.chipBorderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                isPresented = true
            } label: {
                labelContent
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var labelContent: some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NumberShortcutMenuContent: View {
    let emptyMessage: String
    let options: [NumberShortcutMenuOption]
    @Binding var isPresented: Bool

    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if options.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(options) { option in
                    Button {
                        select(option)
                    } label: {
                        HStack {
                            Text(option.title)
                                .lineLimit(1)
                            Spacer()
                            if option.hasShortcut {
                                Text("\(option.shortcutNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
            }
        }
        .frame(minWidth: 180, alignment: .leading)
        .padding(.vertical, 6)
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
    }

    private func select(_ option: NumberShortcutMenuOption) {
        option.action()
        isPresented = false
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let number = shortcutNumber(from: event),
                  let option = options.first(where: { $0.hasShortcut && $0.shortcutNumber == number }) else {
                return event
            }

            select(option)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func shortcutNumber(from event: NSEvent) -> Int? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty,
              let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let number = Int(characters),
              (1...9).contains(number) else {
            return nil
        }

        return number
    }
}
