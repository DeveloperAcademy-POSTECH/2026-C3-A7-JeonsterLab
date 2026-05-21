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

    let repository:          RecordingRepositoryProtocol
    let labelRepo:           ActivityLabelRepositoryProtocol
    let manageLabelsUseCase: ManageActivityLabelsUseCase
    private let assignLabelUseCase: AssignLabelUseCase
    private let exportCSVUseCase:   ExportCSVUseCase

    init(
        repository:          RecordingRepositoryProtocol,
        labelRepo:           ActivityLabelRepositoryProtocol,
        manageLabelsUseCase: ManageActivityLabelsUseCase,
        assignLabelUseCase:  AssignLabelUseCase,
        exportCSVUseCase:    ExportCSVUseCase
    ) {
        self.repository          = repository
        self.labelRepo           = labelRepo
        self.manageLabelsUseCase = manageLabelsUseCase
        self.assignLabelUseCase  = assignLabelUseCase
        self.exportCSVUseCase    = exportCSVUseCase
    }

    func load() {
        recordings = repository.recordings
    }

    func delete(sessionID: UUID) {
        try? repository.delete(sessionID: sessionID)
        load()
    }

    func labelName(for session: RecordingSession) -> String? {
        guard let id = session.activityLabelID else { return nil }
        return labelRepo.label(for: id)?.name
    }

    func makeDetailViewModel(for session: RecordingSession) -> RecordingDetailViewModel {
        RecordingDetailViewModel(
            session:            session,
            repository:         repository,
            assignLabelUseCase: assignLabelUseCase,
            exportCSVUseCase:   exportCSVUseCase,
            labelRepo:          labelRepo
        )
    }

    func makeManagementViewModel() -> ActivityLabelManagementViewModel {
        ActivityLabelManagementViewModel(useCase: manageLabelsUseCase)
    }
}
