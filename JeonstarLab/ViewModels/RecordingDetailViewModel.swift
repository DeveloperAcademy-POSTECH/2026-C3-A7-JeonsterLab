//
//  RecordingDetailViewModel.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

@Observable
@MainActor
final class RecordingDetailViewModel {

    private(set) var samples:        [MotionSample] = []
    private(set) var isLoading:      Bool = false
    private(set) var errorMessage:   String?
    private(set) var availableLabels:[ActivityLabel] = []
    private(set) var session:        RecordingSession

    var showLabelPicker: Bool = false
    var exportURL:       URL?

    private let repository:         RecordingRepositoryProtocol
    private let assignLabelUseCase: AssignLabelUseCase
    private let exportCSVUseCase:   ExportCSVUseCase
    private let labelRepo:          ActivityLabelRepositoryProtocol

    init(
        session:            RecordingSession,
        repository:         RecordingRepositoryProtocol,
        assignLabelUseCase: AssignLabelUseCase,
        exportCSVUseCase:   ExportCSVUseCase,
        labelRepo:          ActivityLabelRepositoryProtocol
    ) {
        self.session            = session
        self.repository         = repository
        self.assignLabelUseCase = assignLabelUseCase
        self.exportCSVUseCase   = exportCSVUseCase
        self.labelRepo          = labelRepo
    }

    var title: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var durationText: String {
        let total = Int(session.duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    var sampleCountText: String {
        "\(session.sampleCount)개 (\(session.samplingRate)Hz)"
    }

    var labelDisplayName: String {
        guard let id = session.activityLabelID else { return "없음" }
        return labelRepo.label(for: id)?.name ?? "없음"
    }

    var hasLabel: Bool { session.activityLabelID != nil }

    func loadSamples() async {
        isLoading = true
        defer { isLoading = false }
        do {
            samples = try repository.loadSamples(for: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLabels() {
        availableLabels = labelRepo.labels
    }

    func assignLabel(_ labelID: UUID?) {
        try? assignLabelUseCase.execute(sessionID: session.id, labelID: labelID)
        session = RecordingSession(
            id:              session.id,
            startedAt:       session.startedAt,
            duration:        session.duration,
            sampleCount:     session.sampleCount,
            fileName:        session.fileName,
            samplingRate:    session.samplingRate,
            activityLabelID: labelID
        )
    }

    func exportCSV() {
        do {
            exportURL = try exportCSVUseCase.execute(sessionID: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
