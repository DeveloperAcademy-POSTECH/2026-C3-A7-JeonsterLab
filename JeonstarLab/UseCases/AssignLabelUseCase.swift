//
//  AssignLabelUseCase.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

@MainActor
final class AssignLabelUseCase {
    private let repository: RecordingRepositoryProtocol

    init(repository: RecordingRepositoryProtocol) {
        self.repository = repository
    }

    func execute(sessionID: UUID, labelID: UUID?) throws {
        try repository.assignLabel(labelID, to: sessionID)
    }
}
