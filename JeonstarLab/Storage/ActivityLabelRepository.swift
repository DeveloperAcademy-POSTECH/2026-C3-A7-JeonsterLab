//
//  ActivityLabelRepository.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation
import SwiftData

@MainActor
final class ActivityLabelRepository: ActivityLabelRepositoryProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var labels: [ActivityLabel] {
        let descriptor = FetchDescriptor<ActivityLabelEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map(\.asActivityLabel)
    }

    func add(name: String) throws {
        let entity = ActivityLabelEntity(name: name)
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(labelID: UUID) throws {
        let id = labelID
        let descriptor = FetchDescriptor<ActivityLabelEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entity)
        try modelContext.save()
    }

    func label(for id: UUID) -> ActivityLabel? {
        let descriptor = FetchDescriptor<ActivityLabelEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? modelContext.fetch(descriptor).first)?.asActivityLabel
    }
}
