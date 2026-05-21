//
//  RecordingRepository.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import SwiftData

/// RecordingRepositoryProtocol 구현체.
/// SwiftData(메타데이터) + FileManager(raw binary) 조합.
@MainActor
final class RecordingRepository: RecordingRepositoryProtocol {

    private let modelContext: ModelContext
    private let fileStore:    RecordingFileStoreProtocol

    init(modelContext: ModelContext, fileStore: RecordingFileStoreProtocol) {
        self.modelContext = modelContext
        self.fileStore    = fileStore
    }

    var recordings: [RecordingSession] {
        let descriptor = FetchDescriptor<RecordingEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map(\.asRecordingSession)
    }

    func save(session: RecordingSession, from tempFileURL: URL) throws {
        try fileStore.moveToDocuments(from: tempFileURL, fileName: session.fileName)
        let entity = RecordingEntity(session: session)
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(sessionID: UUID) throws {
        let id = sessionID
        let descriptor = FetchDescriptor<RecordingEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        try fileStore.delete(fileName: entity.fileName)
        modelContext.delete(entity)
        try modelContext.save()
    }

    func loadSamples(for sessionID: UUID) throws -> [MotionSample] {
        let id = sessionID
        let descriptor = FetchDescriptor<RecordingEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RecordingRepositoryError.notFound
        }
        let url = try fileStore.urlForFile(named: entity.fileName)
        return try MotionSampleSerializer.read(from: url)
    }

    func assignLabel(_ labelID: UUID?, to sessionID: UUID) throws {
        let id = sessionID
        let descriptor = FetchDescriptor<RecordingEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        entity.activityLabelID = labelID
        try modelContext.save()
    }
}
