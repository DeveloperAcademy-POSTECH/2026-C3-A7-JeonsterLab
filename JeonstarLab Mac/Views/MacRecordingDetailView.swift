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
    @State private var showsSavedSnapPreviews = true

    private var manualSnapDraft: ManualSnapDraft? {
        guard let chartSelection else { return nil }
        return SnapSelectionAnalyzer.analyze(selection: chartSelection, samples: samples)
    }

    private var hasSelectionConflict: Bool {
        guard let chartSelection, chartSelection.isUsable else { return false }
        return overlapsExistingSnap(selection: chartSelection)
    }

    var body: some View {
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
                            onDelete: deleteSnapEvent(_:)
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
                            Toggle("저장된 스냅 미리보기", isOn: $showsSavedSnapPreviews)
                                .toggleStyle(.switch)
                            selectionPanel
                            MacMotionChartsView(
                                samples: samples,
                                savedSnapEvents: package.workingSnapEvents,
                                showSavedSnapPreviews: showsSavedSnapPreviews,
                                hasSelectionConflict: hasSelectionConflict,
                                selection: $chartSelection
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(28)
        }
        .task(id: package.folderURL) {
            loadCSV()
        }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("선택 구간")
                .font(.headline)

            if let chartSelection {
                let normalized = chartSelection.normalized
                let draft = manualSnapDraft

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        selectionMetric("시작", formattedSeconds(normalized.startTime))
                        selectionMetric("끝", formattedSeconds(normalized.endTime))
                        selectionMetric("길이", formattedSeconds(normalized.duration))
                    }
                    GridRow {
                        selectionMetric("샘플", "\(draft?.sampleCount ?? 0)개")
                        selectionMetric("최대 가속도", formatted(draft?.peakAcceleration, suffix: "g"))
                        selectionMetric("최대 각속도", formatted(draft?.peakGyro, suffix: "rad/s"))
                    }
                    GridRow {
                        selectionMetric("피크", formatted(draft?.peakTime, suffix: "s"))
                        selectionMetric("주 회전축", draft?.dominantAxis ?? "-")
                        selectionMetric("저장 가능", draft?.canSave == true && !hasSelectionConflict ? "가능" : "불가")
                    }
                }

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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadCSV() {
        guard let csvURL = package.csvURL else {
            samples = []
            csvErrorMessage = "recording.csv 파일이 없습니다."
            return
        }

        do {
            samples = try MotionCSVParser.parse(url: csvURL)
            csvErrorMessage = nil
        } catch {
            samples = []
            csvErrorMessage = error.localizedDescription
        }
    }

    private func saveManualSnap() {
        guard let manualSnapDraft, manualSnapDraft.canSave, !hasSelectionConflict else { return }
        package.addManualSnapEvent(from: manualSnapDraft)
        chartSelection = nil
        onSaveLabel(package)
    }

    private func deleteSnapEvent(_ event: WorkingSnapEvent) {
        package.deleteSnapEvent(id: event.snapID)
        onSaveLabel(package)
    }

    private func hasSegment(for event: WorkingSnapEvent) -> Bool {
        SnapSegmentExporter.segmentExists(
            package: package,
            snapID: event.snapID
        )
    }

    private func overlapsExistingSnap(selection: ChartTimeSelection) -> Bool {
        let selected = selection.normalized
        return package.workingSnapEvents.contains { event in
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
