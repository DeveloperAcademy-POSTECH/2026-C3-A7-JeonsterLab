//
//  ActivityLabelManagementViewModel.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

@Observable
@MainActor
final class ActivityLabelManagementViewModel {
    private(set) var labels: [ActivityLabel] = []
    private let useCase: ManageActivityLabelsUseCase

    init(useCase: ManageActivityLabelsUseCase) {
        self.useCase = useCase
    }

    func load() {
        labels = useCase.labels
    }

    func addLabel(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? useCase.addLabel(name: trimmed)
        load()
    }

    func deleteLabel(at offsets: IndexSet) {
        for i in offsets {
            try? useCase.deleteLabel(labelID: labels[i].id)
        }
        load()
    }
}
