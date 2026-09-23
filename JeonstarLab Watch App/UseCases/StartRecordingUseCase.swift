//
//  StartRecordingUseCase.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

@MainActor
final class StartRecordingUseCase {

    private let recorder: MotionRecorderProtocol
    private let storage:  RecordingStorageProtocol

    init(recorder: MotionRecorderProtocol, storage: RecordingStorageProtocol) {
        self.recorder = recorder
        self.storage  = storage
    }

    /// 새 녹화를 시작. 이 세션에 할당된 UUID를 반환.
    func execute() throws -> UUID {
        let sessionID = UUID()
        try storage.begin(sessionID: sessionID, startedAt: Date())
        try recorder.startRecording { [storage] sample in
            storage.append(sample)
        }
        return sessionID
    }
}
