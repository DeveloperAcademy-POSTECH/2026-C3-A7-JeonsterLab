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

    private let session:    RecordingSession
    private let repository: RecordingRepositoryProtocol

    init(session: RecordingSession, repository: RecordingRepositoryProtocol) {
        self.session    = session
        self.repository = repository
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

    var currentSession: RecordingSession {
        session
    }

    var recordingRepository: RecordingRepositoryProtocol {
        repository
    }

    func exportRecording() throws -> [URL] {
        try RecordingExportService(repository: repository)
            .export(session: session)
    }

    func loadSamples() async {
        isLoading = true
        defer { isLoading = false }
        do {
            samples = try repository.loadSamples(for: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
