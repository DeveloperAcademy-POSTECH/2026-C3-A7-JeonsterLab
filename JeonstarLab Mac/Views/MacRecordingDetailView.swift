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
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(package.displayTitle)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Text("\(package.recordingDateText) · 수신 \(package.receivedAtText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    sectionCard(title: "녹화 정보") {
                        MacRecordingInfoPanel(package: package)
                    }

                    sectionCard(title: "결과") {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("결과 요약", value: package.resultSummaryText)

                            TextField("이름", text: $package.displayName, prompt: Text(package.recordingDateTitle))
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: package.displayName) {
                                    onSaveLabel(package)
                                }

                            TextEditor(text: $package.notes)
                                .frame(minHeight: 72)
                                .onChange(of: package.notes) {
                                    onSaveLabel(package)
                                }
                        }
                    }

                    if !package.parseMessages.isEmpty {
                        sectionCard(title: "파일 상태") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(package.parseMessages, id: \.self) { message in
                                    Text(message)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    sectionCard(title: "스냅 이벤트") {
                        VStack(alignment: .leading, spacing: 12) {
                            MacSnapEventListView(
                                events: package.workingSnapEvents,
                                snapEventLabels: $package.snapEventLabels,
                                folders: folders,
                                folderForEvent: { event in
                                    folderForEvent(package, event)
                                },
                                hasSegment: hasSegment(for:),
                                onAddToFolder: { event, folder in
                                    onAddSnapToFolder(event, package, folder)
                                },
                                onRemoveFromFolder: { event, folder in
                                    onRemoveSnapFromFolder(event, package, folder)
                                },
                                onSelect: { event in
                                    selectSnapEvent(event)
                                    withAnimation {
                                        scrollProxy.scrollTo(Self.graphSectionID, anchor: .top)
                                    }
                                },
                                onDelete: requestDeleteSnapEvent(_:)
                            )
                            .onChange(of: package.snapEventLabels) {
                                onSaveLabel(package)
                            }
                        }
                    }

                    sectionCard(title: "그래프") {
                        if let csvErrorMessage {
                            Text(csvErrorMessage)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                        } else if samples.isEmpty {
                            ProgressView("CSV 로딩 중")
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    Toggle("저장된 스냅 미리보기", isOn: $showsSavedSnapPreviews)
                                        .toggleStyle(.switch)

                                    Spacer()

                                    Button("전체 보기") {
                                        resetVisibleRangeToFull()
                                    }

                                    Button("선택 구간 보기") {
                                        focusVisibleRange(on: chartSelection)
                                    }
                                    .disabled(chartSelection == nil)

                                    Button("축소") {
                                        zoomVisibleRange(scale: 0.8)
                                    }

                                    Button("확대") {
                                        zoomVisibleRange(scale: 1.25)
                                    }
                                }
                                selectionPanel
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
                            }
                        }
                    }
                    .id(Self.graphSectionID)
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(28)
            }
        }
        .task(id: package.folderURL) {
            loadCSV()
        }
        .onChange(of: package.folderURL) {
            resetTransientStateForPackageSwitch()
        }
        .alert("스냅 구간을 변경할까요?", isPresented: $showsEditConfirmation) {
            Button("취소", role: .cancel) {}
            Button("변경하기", role: .destructive) {
                applySnapEdit()
            }
        } message: {
            Text("선택한 스냅의 시작·끝 시간이 새 구간으로 변경됩니다.\n이 작업은 되돌릴 수 없습니다.")
        }
        .alert(
            "이 스냅 이벤트를 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            presenting: pendingDeleteEvent
        ) { event in
            Button("취소", role: .cancel) {
                pendingDeleteEvent = nil
            }
            Button("삭제", role: .destructive) {
                deleteSnapEvent(event)
                pendingDeleteEvent = nil
            }
        } message: { _ in
            Text("삭제하면 현재 녹화의 스냅 목록에서 사라집니다.\n이 작업은 되돌릴 수 없습니다.")
        }
    }

    private static let graphSectionID = "graph-section"
    private static let selectionChangeTolerance = 0.001

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
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var manualSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("선택 구간")
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
                    Button("스냅 저장하기") {
                        saveManualSnap()
                    }
                    .disabled(draft?.canSave != true || hasSelectionConflict)

                    Button("선택 지우기") {
                        self.chartSelection = nil
                    }
                }
            } else {
                Text("그래프 위에서 드래그해 수동 스냅 구간을 선택하세요.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func focusedSnapPanel(_ editDraft: SnapEditDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("선택한 스냅")
                        .font(.headline)
                    Text("그래프에서 구간을 움직이거나 양 끝을 조절하면 수정할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("선택 해제") {
                    clearFocusedSnap()
                }
            }

            editStatsColumn(
                title: "현재 구간",
                event: editDraft.originalEvent,
                draft: originalDraft(for: editDraft)
            )
        }
    }

    private func editSelectionPanel(_ editDraft: SnapEditDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("스냅 구간 수정")
                        .font(.headline)
                    Text("초록색은 기존 구간, 파란색은 새 후보 구간입니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("수정 취소") {
                    clearFocusedSnap()
                }
            }

            HStack(alignment: .top, spacing: 14) {
                editStatsColumn(
                    title: "기존",
                    event: editDraft.originalEvent,
                    draft: originalDraft(for: editDraft)
                )

                Divider()

                editStatsColumn(
                    title: "후보",
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

            Button("스냅 변경하기") {
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
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
            GridRow {
                selectionMetric("시작", formattedSeconds(selection.startTime))
                selectionMetric("끝", formattedSeconds(selection.endTime))
                selectionMetric("길이", formattedSeconds(selection.duration))
            }
            GridRow {
                selectionMetric("샘플", sampleCount.map { "\($0)개" } ?? "-")
                selectionMetric("최대 가속도", formatted(peakAcceleration, suffix: "g"))
                selectionMetric("최대 각속도", formatted(peakGyro, suffix: "rad/s"))
            }
            GridRow {
                selectionMetric("피크", formatted(peakTime, suffix: "s"))
                selectionMetric("주 회전축", dominantAxis ?? "-")
                selectionMetric("저장 가능", canSave ? "가능" : "불가")
            }
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
                Text("구간 정보 없음")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var conflictWarning: some View {
        Group {
            if hasSelectionConflict {
                VStack(alignment: .leading, spacing: 4) {
                    Text("스냅이 충돌되는 부분이 있습니다.")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text("기존 스냅과 겹치지 않도록 범위를 조정해주세요.")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
    }

    private func loadCSV() {
        guard let csvURL = package.csvURL else {
            samples = []
            csvErrorMessage = "recording.csv 파일이 없습니다."
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
            editMessage = "스냅 구간이 변경되었습니다."
        } catch {
            editErrorMessage = "세그먼트 갱신 실패: \(error.localizedDescription)"
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
        .frame(minWidth: 120, alignment: .leading)
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
