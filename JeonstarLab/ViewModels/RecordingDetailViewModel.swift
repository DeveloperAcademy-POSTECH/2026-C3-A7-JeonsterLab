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

    private(set) var samples:      [MotionSample] = []
    private(set) var isLoading:    Bool = false
    private(set) var errorMessage: String?
    private(set) var memoErrorMessage: String?
    var recordingMemo: String

    private var session:    RecordingSession
    private let repository: RecordingRepositoryProtocol

    init(session: RecordingSession, repository: RecordingRepositoryProtocol) {
        self.session    = session
        self.repository = repository
        self.recordingMemo = session.memo
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
        "\(session.sampleCount) samples (\(session.samplingRate) Hz)"
    }

    var currentSession: RecordingSession {
        session
    }

    var savedRecordingMemo: String {
        session.memo
    }

    var hasRecordingMemoChanges: Bool {
        recordingMemo != session.memo
    }

    var recordingRepository: RecordingRepositoryProtocol {
        repository
    }

    func exportRecording() throws -> [URL] {
        try RecordingExportService(repository: repository)
            .export(session: session)
    }

    func loadSamples() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let loaded = try await repository.loadSamplesForReview(for: session.id)
            try Task.checkCancellation()
            samples = loaded
        } catch is CancellationError {
            // Navigating away is not a failed import or a corrupt recording.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRecordingMemo(_ memo: String) {
        do {
            try repository.updateMemo(for: session.id, memo: memo)
            session = RecordingSession(
                id: session.id,
                startedAt: session.startedAt,
                duration: session.duration,
                sampleCount: session.sampleCount,
                fileName: session.fileName,
                samplingRate: session.samplingRate,
                memo: memo
            )
            memoErrorMessage = nil
        } catch {
            memoErrorMessage = error.localizedDescription
        }
    }

    func resetRecordingMemoDraft() {
        recordingMemo = session.memo
        memoErrorMessage = nil
    }
}
