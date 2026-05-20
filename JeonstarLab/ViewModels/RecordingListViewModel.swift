//
//  RecordingListViewModel.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

@Observable
@MainActor
final class RecordingListViewModel {

    private(set) var recordings: [RecordingSession] = []
    let repository: RecordingRepositoryProtocol

    init(repository: RecordingRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        recordings = repository.recordings
    }

    func delete(sessionID: UUID) {
        try? repository.delete(sessionID: sessionID)
        load()
    }
}
