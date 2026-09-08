//
//  MacRecordingDetailView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacRecordingDetailView: View {
    @Binding var package: ReceivedRecordingPackage
    let folders: [SnapFolder]
    let folderForEvent: (ReceivedRecordingPackage, WorkingSnapEvent) -> SnapFolder?
    let onAddSnapToFolder: (WorkingSnapEvent, ReceivedRecordingPackage, SnapFolder) -> Void
    let onRemoveSnapFromFolder: (WorkingSnapEvent, ReceivedRecordingPackage, SnapFolder) -> Void
    let onSaveLabel: (ReceivedRecordingPackage) -> Void

    @State private var samples: [MotionCSVSample] = []
    @State private var csvErrorMessage: String?
    @State private var chartSelection: ChartTimeSelection?
    @State private var visibleTimeRange = ChartVisibleTimeRange.full(0...1)
    @State private var showsSavedSnapPreviews = true
    @State private var editDraft: SnapEditDraft?
    @State private var showsEditConfirmation = false
    @State private var pendingDeleteEvent: WorkingSnapEvent?
    @State private var showsDeleteConfirmation = false
    @State private var editMessage: String?
    @State private var editErrorMessage: String?
    @State private var isEditingTitle = false
    @State private var draftDisplayName = ""

    private var manualSnapDraft: ManualSnapDraft? {
        guard let chartSelection else { return nil }
        return SnapSelectionAnalyzer.analyze(selection: chartSelection, samples: samples)
    }

    private var hasSelectionConflict: Bool {
        guard let chartSelection, chartSelection.isUsable else { return false }
        return overlapsExistingSnap(selection: chartSelection, excludingSnapID: editDraft?.snapID)
    }

    private var hasFocusedSnapRangeChange: Bool {
        guard let editDraft,
              let originalSelection = editDraft.originalSelection,
              let chartSelection else {
            return false
        }

        let candidate = chartSelection.normalized
        let original = originalSelection.normalized
        return abs(candidate.startTime - original.startTime) > Self.selectionChangeTolerance
            || abs(candidate.endTime - original.endTime) > Self.selectionChangeTolerance
    }

    private var fullTimeRange: ClosedRange<Double> {
        let times = samples.map(\.relativeTime)
        return (times.min() ?? 0)...(times.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleHeader
                    Text("\(package.recordingDateText) · \(package.sampleCountText) samples")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    chartWorkspace
                    sectionCard(title: "Motion Snaps · \(package.workingSnapEvents.count)") {
                        snapList(package.workingSnapEvents, inspector: false)
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 500, maxWidth: .infinity)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectionPanel
                    if let event = package.workingSnapEvents.first(where: { $0.snapID == editDraft?.snapID }) {
                        snapList([event], inspector: true)
                            .padding(.horizontal, 14)
                    }
                    Divider()
                    DisclosureGroup("Recording Information") {
                        MacRecordingInfoPanel(package: package)
                            .padding(.top, 12)
                    }
                    DisclosureGroup("Participant Information") {
                        participantInfoCard.padding(.top, 12)
                    }
                    if !package.parseMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("File Status", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            ForEach(package.parseMessages, id: \.self) { message in
                                Text(message).font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(width: 310)
            .background(EditorPalette.surface)
        }
        .background(EditorPalette.background)
        .onChange(of: package.snapEventLabels) { onSaveLabel(package) }
        .task(id: package.folderURL) {
            loadCSV()
        }
        .onChange(of: package.folderURL) {
            resetTransientStateForPackageSwitch()
        }
        .alert("Update this snap range?", isPresented: $showsEditConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Update", role: .destructive) {
                applySnapEdit()
            }
        } message: {
            Text("The selected snap's start and end times will be replaced.\nThis action cannot be undone.")
        }
        .alert(
            "Delete this snap?",
            isPresented: $showsDeleteConfirmation,
            presenting: pendingDeleteEvent
        ) { event in
            Button("Cancel", role: .cancel) {
                pendingDeleteEvent = nil
            }
            Button("Delete", role: .destructive) {
                deleteSnapEvent(event)
                pendingDeleteEvent = nil
            }
        } message: { _ in
            Text("This snap will be removed from the recording.\nThis action cannot be undone.")
        }
    }

    private var chartWorkspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    chartPreviewToggle
                    Spacer()
                    chartNavigation
                }
                VStack(alignment: .leading, spacing: 8) {
                    chartPreviewToggle
                    chartNavigation
                }
            }
            if let csvErrorMessage {
                ContentUnavailableView("Motion Data Unavailable", systemImage: "waveform",
                                       description: Text(csvErrorMessage))
            } else if samples.isEmpty {
                ProgressView("Loading CSV")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                MacMotionChartsView(
                    samples: samples,
                    savedSnapEvents: package.workingSnapEvents,
                    showSavedSnapPreviews: showsSavedSnapPreviews,
                    hasSelectionConflict: hasSelectionConflict,
                    editingSnapID: editDraft?.snapID,
                    editingOriginalSelection: editDraft?.originalSelection,
                    showsCandidateSelection: editDraft == nil || hasFocusedSnapRangeChange,
                    fullTimeRange: fullTimeRange,
                    selection: $chartSelection,
                    visibleTimeRange: $visibleTimeRange
                )
                Text("Drag to select · Drag handles to resize · Hold Space and drag to pan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartPreviewToggle: some View {
        Toggle("Show Saved Snaps", isOn: $showsSavedSnapPreviews)
            .toggleStyle(.checkbox)
            .controlSize(.small)
    }

    private var chartNavigation: some View {
        HStack(spacing: 8) {
            Button("Fit All") { resetVisibleRangeToFull() }
            Button("Fit Selection") { focusVisibleRange(on: chartSelection) }
                .disabled(chartSelection == nil)
            Button { zoomVisibleRange(scale: 0.8) } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Zoom out")
            Button { zoomVisibleRange(scale: 1.25) } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Zoom in")
        }
        .controlSize(.small)
    }

    private func snapList(_ events: [WorkingSnapEvent], inspector: Bool) -> some View {
        MacSnapEventListView(
            events: events,
            snapEventLabels: $package.snapEventLabels,
            folders: folders,
            folderForEvent: { folderForEvent(package, $0) },
            hasSegment: hasSegment(for:),
            onAddToFolder: { onAddSnapToFolder($0, package, $1) },
            onRemoveFromFolder: { onRemoveSnapFromFolder($0, package, $1) },
            onSelect: selectSnapEvent(_:),
            onDelete: requestDeleteSnapEvent(_:),
            isInspector: inspector,
            selectedSnapID: editDraft?.snapID
        )
    }

    private static let graphSectionID = "graph-section"
    private static let selectionChangeTolerance = 0.001

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingTitle {
                HStack(spacing: 8) {
                    TextField("Recording Name", text: $draftDisplayName, prompt: Text(package.recordingDateTitle))
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        package.displayName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        isEditingTitle = false
                        onSaveLabel(package)
                    }

                    Button("Cancel") {
                        draftDisplayName = package.displayName
                        isEditingTitle = false
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(package.displayTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Button {
                        draftDisplayName = package.displayName
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit Recording Name")
                }
            }
        }
    }

    private var participantInfoCard: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("Name or Nickname")
                    .foregroundStyle(.secondary)
                TextField("Not set", text: $package.participantInfo.nameOrNickname)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: package.participantInfo.nameOrNickname) {
                        onSaveLabel(package)
                    }
            }

            GridRow {
                Text("Gender")
                    .foregroundStyle(.secondary)
                Picker("Gender", selection: $package.participantInfo.gender) {
                    ForEach(ParticipantGenderOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: package.participantInfo.gender) {
                    onSaveLabel(package)
                }
            }

            GridRow {
                Text("Age Group")
                    .foregroundStyle(.secondary)
                Picker("Age Group", selection: $package.participantInfo.ageGroup) {
                    ForEach(ParticipantAgeGroupOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: package.participantInfo.ageGroup) {
                    onSaveLabel(package)
                }
            }

            GridRow {
                Text("Height (cm)")
                    .foregroundStyle(.secondary)
                TextField("e.g. 174", text: heightBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
            }

            GridRow {
                Text("Dominant Hand")
                    .foregroundStyle(.secondary)
                Picker("Dominant Hand", selection: $package.participantInfo.dominantHand) {
                    ForEach(ParticipantDominantHandOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: package.participantInfo.dominantHand) {
                    onSaveLabel(package)
                }
            }

            GridRow {
                Text("Experience")
                    .foregroundStyle(.secondary)
                Picker("Experience", selection: $package.participantInfo.skillLevel) {
                    ForEach(ParticipantSkillLevelOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: package.participantInfo.skillLevel) {
                    onSaveLabel(package)
                }
            }

            GridRow(alignment: .top) {
                Text("Notes")
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                TextEditor(text: $package.participantInfo.memo)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(4)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary)
                    }
                    .onChange(of: package.participantInfo.memo) {
                        onSaveLabel(package)
                    }
            }
        }
    }

    private var heightBinding: Binding<String> {
        Binding(
            get: { package.participantInfo.heightCM },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                package.participantInfo.heightCM = filtered
                onSaveLabel(package)
            }
        )
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let editDraft {
                if hasFocusedSnapRangeChange {
                    editSelectionPanel(editDraft)
                } else {
                    focusedSnapPanel(editDraft)
                }
            } else {
                manualSelectionPanel
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorPalette.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var manualSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected Range")
                .font(.headline)

            if let editMessage {
                Text(editMessage)
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            if let chartSelection {
                let normalized = chartSelection.normalized
                let draft = manualSnapDraft

                selectionStatsGrid(
                    selection: normalized,
                    sampleCount: draft?.sampleCount,
                    peakAcceleration: draft?.peakAcceleration,
                    peakGyro: draft?.peakGyro,
                    peakTime: draft?.peakTime,
                    dominantAxis: draft?.dominantAxis,
                    canSave: draft?.canSave == true && !hasSelectionConflict
                )

                conflictWarning

                HStack {
                    Button("Save Snap") {
                        saveManualSnap()
                    }
                    .disabled(draft?.canSave != true || hasSelectionConflict)

                    Button("Clear Selection") {
                        self.chartSelection = nil
                    }
                }
            } else {
                Text("Drag across a chart to select a manual snap range.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func focusedSnapPanel(_ editDraft: SnapEditDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected Snap")
                        .font(.headline)
                    Text("Move the range or drag its handles on the chart to edit it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear Selection") {
                    clearFocusedSnap()
                }
            }

            editStatsColumn(
                title: "Current Range",
                event: editDraft.originalEvent,
                draft: originalDraft(for: editDraft)
            )
        }
    }

    private func editSelectionPanel(_ editDraft: SnapEditDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Snap Range")
                        .font(.headline)
                    Text("Green marks the original range; blue marks your proposed range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel Edit") {
                    clearFocusedSnap()
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                editStatsColumn(
                    title: "Original",
                    event: editDraft.originalEvent,
                    draft: originalDraft(for: editDraft)
                )

                Divider()

                editStatsColumn(
                    title: "Proposed",
                    event: nil,
                    draft: manualSnapDraft
                )
            }

            conflictWarning

            if let editErrorMessage {
                Text(editErrorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let editMessage {
                Text(editMessage)
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            Button("Update Snap") {
                showsEditConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(manualSnapDraft?.canSave != true || hasSelectionConflict)
        }
    }

    private func selectionStatsGrid(
        selection: ChartTimeSelection,
        sampleCount: Int?,
        peakAcceleration: Double?,
        peakGyro: Double?,
        peakTime: Double?,
        dominantAxis: String?,
        canSave: Bool
    ) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
            selectionMetric("Start", formattedSeconds(selection.startTime))
            selectionMetric("End", formattedSeconds(selection.endTime))
            selectionMetric("Duration", formattedSeconds(selection.duration))
            selectionMetric("Samples", sampleCount.map { "\($0)" } ?? "–")
            selectionMetric("Peak Acceleration", formatted(peakAcceleration, suffix: "g"))
            selectionMetric("Peak Rotation", formatted(peakGyro, suffix: "rad/s"))
            selectionMetric("Peak Time", formatted(peakTime, suffix: "s"))
            selectionMetric("Dominant Axis", dominantAxis ?? "–")
            selectionMetric("Can Save", canSave ? "Yes" : "No")
        }
    }

    private func editStatsColumn(
        title: String,
        event: WorkingSnapEvent?,
        draft: ManualSnapDraft?
    ) -> some View {
        let selection = draft?.selection.normalized ?? selection(for: event)
        let sampleCount = draft?.sampleCount
        let peakAcceleration = draft?.peakAcceleration ?? event?.peakAcceleration
        let peakGyro = draft?.peakGyro ?? event?.peakGyro
        let peakTime = draft?.peakTime ?? event?.peakTime
        let dominantAxis = draft?.dominantAxis ?? event?.dominantAxis

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let selection {
                selectionStatsGrid(
                    selection: selection,
                    sampleCount: sampleCount,
                    peakAcceleration: peakAcceleration,
                    peakGyro: peakGyro,
                    peakTime: peakTime,
                    dominantAxis: dominantAxis,
                    canSave: draft?.canSave ?? true
                )
            } else {
                Text("No range information")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var conflictWarning: some View {
        Group {
            if hasSelectionConflict {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This range overlaps another snap.")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text("Adjust the range so it does not overlap an existing snap.")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
    }

    private func loadCSV() {
        guard let csvURL = package.csvURL else {
            samples = []
            csvErrorMessage = "Missing recording.csv."
            resetVisibleRangeToFull()
            return
        }

        do {
            samples = try MotionCSVParser.parse(url: csvURL)
            csvErrorMessage = nil
            resetVisibleRangeToFull()
        } catch {
            samples = []
            csvErrorMessage = error.localizedDescription
            resetVisibleRangeToFull()
        }
    }

    private func saveManualSnap() {
        guard let manualSnapDraft, manualSnapDraft.canSave, !hasSelectionConflict else { return }
        editMessage = nil
        editErrorMessage = nil
        package.addManualSnapEvent(from: manualSnapDraft)
        chartSelection = nil
        onSaveLabel(package)
    }

    private func requestDeleteSnapEvent(_ event: WorkingSnapEvent) {
        pendingDeleteEvent = event
        showsDeleteConfirmation = true
    }

    private func deleteSnapEvent(_ event: WorkingSnapEvent) {
        if editDraft?.snapID == event.snapID {
            clearFocusedSnap()
        }
        package.deleteSnapEvent(id: event.snapID)
        onSaveLabel(package)
    }

    private func hasSegment(for event: WorkingSnapEvent) -> Bool {
        SnapSegmentExporter.segmentExists(
            package: package,
            snapID: event.snapID
        )
    }

    private func selectSnapEvent(_ event: WorkingSnapEvent) {
        guard let selection = selection(for: event) else { return }
        editDraft = SnapEditDraft(originalEvent: event)
        chartSelection = selection
        focusVisibleRange(on: selection)
        editMessage = nil
        editErrorMessage = nil
    }

    private func resetTransientStateForPackageSwitch() {
        chartSelection = nil
        editDraft = nil
        showsEditConfirmation = false
        pendingDeleteEvent = nil
        showsDeleteConfirmation = false
        isEditingTitle = false
        draftDisplayName = package.displayName
        resetVisibleRangeToFull()
        editMessage = nil
        editErrorMessage = nil
    }

    private func clearFocusedSnap() {
        editDraft = nil
        chartSelection = nil
        resetVisibleRangeToFull()
        editMessage = nil
        editErrorMessage = nil
    }

    private func applySnapEdit() {
        guard let editDraft,
              let manualSnapDraft,
              manualSnapDraft.canSave,
              !hasSelectionConflict else {
            return
        }

        let updatedEvent = editedEvent(
            from: editDraft.originalEvent,
            draft: manualSnapDraft
        )

        do {
            _ = try SnapSegmentExporter.export(
                package: package,
                event: updatedEvent,
                samples: samples
            )
            package.replaceSnapEvent(updatedEvent)
            onSaveLabel(package)
            self.editDraft = nil
            self.chartSelection = nil
            focusVisibleRange(on: selection(for: updatedEvent))
            editErrorMessage = nil
            editMessage = "Snap range updated."
        } catch {
            editErrorMessage = "Failed to update segment: \(error.localizedDescription)"
        }
    }

    private func resetVisibleRangeToFull() {
        visibleTimeRange = .full(fullTimeRange)
    }

    private func focusVisibleRange(on selection: ChartTimeSelection?) {
        guard let selection else { return }

        let normalized = selection.normalized
        let padded = ChartVisibleTimeRange(
            lowerBound: normalized.startTime - 1,
            upperBound: normalized.endTime + 1
        )
        visibleTimeRange = padded.clamped(
            to: fullTimeRange,
            minimumDuration: minimumVisibleDuration
        )
    }

    private func zoomVisibleRange(scale: Double) {
        visibleTimeRange = visibleTimeRange.zoomed(
            scale: scale,
            anchorTime: (visibleTimeRange.lowerBound + visibleTimeRange.upperBound) / 2,
            fullRange: fullTimeRange,
            minimumDuration: minimumVisibleDuration
        )
    }

    private var minimumVisibleDuration: Double {
        let fullDuration = fullTimeRange.upperBound - fullTimeRange.lowerBound
        return min(0.5, max(0, fullDuration))
    }

    private func editedEvent(
        from originalEvent: WorkingSnapEvent,
        draft: ManualSnapDraft
    ) -> WorkingSnapEvent {
        var updatedEvent = originalEvent
        let normalized = draft.selection.normalized
        let labelPayload = package.snapEventLabels[originalEvent.snapID]

        updatedEvent.startTime = normalized.startTime
        updatedEvent.peakTime = draft.peakTime
        updatedEvent.endTime = normalized.endTime
        updatedEvent.snapDuration = draft.snapDuration
        updatedEvent.peakAcceleration = draft.peakAcceleration
        updatedEvent.peakGyro = draft.peakGyro
        updatedEvent.peakDelay = draft.peakTime - normalized.startTime
        updatedEvent.dominantAxis = draft.dominantAxis
        updatedEvent.rollRange = draft.rollRange
        updatedEvent.pitchRange = draft.pitchRange
        updatedEvent.yawRange = draft.yawRange
        updatedEvent.label = labelPayload?.label ?? originalEvent.label
        updatedEvent.notes = labelPayload?.notes ?? originalEvent.notes
        updatedEvent.updatedAt = Date()

        return updatedEvent
    }

    private func originalDraft(for editDraft: SnapEditDraft) -> ManualSnapDraft? {
        guard let selection = editDraft.originalSelection else { return nil }
        return SnapSelectionAnalyzer.analyze(selection: selection, samples: samples)
    }

    private func selection(for event: WorkingSnapEvent?) -> ChartTimeSelection? {
        guard let event,
              let startTime = event.startTime,
              let endTime = event.endTime else {
            return nil
        }
        return ChartTimeSelection(startTime: startTime, endTime: endTime).normalized
    }

    private func overlapsExistingSnap(
        selection: ChartTimeSelection,
        excludingSnapID: String? = nil
    ) -> Bool {
        let selected = selection.normalized
        return package.workingSnapEvents.contains { event in
            if event.snapID == excludingSnapID {
                return false
            }
            guard let eventStart = event.startTime,
                  let eventEnd = event.endTime else {
                return false
            }

            let existing = ChartTimeSelection(
                startTime: eventStart,
                endTime: eventEnd
            ).normalized
            guard existing.duration > 0 else { return false }
            return selected.startTime < existing.endTime
                && selected.endTime > existing.startTime
        }
    }

    private func selectionMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedSeconds(_ value: Double) -> String {
        formatted(value, suffix: "s")
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%@", locale: Locale(identifier: "en_US_POSIX"), value, suffix)
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorSurface()
    }
}
