//
//  ManageActivityLabelsUseCase.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

@MainActor
final class ManageActivityLabelsUseCase {
    private let labelRepo:     ActivityLabelRepositoryProtocol
    private let recordingRepo: RecordingRepositoryProtocol

    init(labelRepo: ActivityLabelRepositoryProtocol, recordingRepo: RecordingRepositoryProtocol) {
        self.labelRepo     = labelRepo
        self.recordingRepo = recordingRepo
    }

    var labels: [ActivityLabel] { labelRepo.labels }

    func addLabel(name: String) throws {
        try labelRepo.add(name: name)
    }

    /// 레이블 삭제 + 해당 레이블이 붙은 녹화 세션에서 레이블 해제.
    func deleteLabel(labelID: UUID) throws {
        try labelRepo.delete(labelID: labelID)
        let affected = recordingRepo.recordings.filter { $0.activityLabelID == labelID }
        for session in affected {
            try? recordingRepo.assignLabel(nil, to: session.id)
        }
    }
}
