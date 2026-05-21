//
//  StopRecordingUseCase.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Transfer")

@MainActor
final class StopRecordingUseCase {

    private let recorder: MotionRecorderProtocol
    private let storage:  RecordingStorageProtocol
    private let transfer: RecordingTransferProtocol

    init(
        recorder: MotionRecorderProtocol,
        storage:  RecordingStorageProtocol,
        transfer: RecordingTransferProtocol
    ) {
        self.recorder = recorder
        self.storage  = storage
        self.transfer = transfer
    }

    /// 녹화를 중지하고, 파일로 flush한 후 즉시 iPhone으로 전송 큐에 등록.
    func execute(sessionID: UUID, startedAt: Date) throws {
        logger.debug("▶︎ [1] stopRecording 호출 — sessionID: \(sessionID.uuidString)")
        recorder.stopRecording()

        let duration = Date().timeIntervalSince(startedAt)
        let (fileURL, sampleCount) = try storage.flush(sessionID: sessionID, startedAt: startedAt)

        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        let fileSize   = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        logger.debug("▶︎ [2] flush 완료 — samples: \(sampleCount), exists: \(fileExists), size: \(fileSize)B, path: \(fileURL.lastPathComponent)")

        let session = RecordingSession(
            id:          sessionID,
            startedAt:   startedAt,
            duration:    duration,
            sampleCount: sampleCount,
            fileName:    fileURL.lastPathComponent,
            samplingRate: 50
        )

        logger.debug("▶︎ [3] transfer 호출 시작")
        transfer.transfer(fileURL: fileURL, session: session)
        logger.debug("▶︎ [4] transferFile enqueue 완료")
        // 파일 삭제는 WatchSessionManager.didFinish 콜백에서 처리.
        // Apple 문서: "Do not modify or delete the file until after it has been delivered."
    }
}
