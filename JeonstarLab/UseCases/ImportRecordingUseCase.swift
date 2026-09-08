//
//  ImportRecordingUseCase.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Receive")

@MainActor
final class ImportRecordingUseCase {

    private let repository: RecordingRepositoryProtocol

    /// 저장 성공 후 호출 — List 갱신 등에 활용.
    var onRecordingSaved: ((RecordingSession) -> Void)?

    init(repository: RecordingRepositoryProtocol) {
        self.repository = repository
    }

    /// WCSession metadata를 파싱하여 RecordingSession을 구성하고 영구 저장.
    @discardableResult
    func execute(tempFileURL: URL, metadata: [String: Any]) throws -> RecordingSession {
        logger.debug("▶︎ [8] ImportUseCase.execute — metadata keys: \(metadata.keys.joined(separator: ", "))")

        guard
            let idString    = metadata["sessionID"]   as? String,
            let id          = UUID(uuidString: idString),
            let startedAtTS = metadata["startedAt"]   as? TimeInterval,
            let duration    = metadata["duration"]    as? TimeInterval,
            let sampleCount = metadata["sampleCount"] as? Int,
            let rate        = metadata["samplingRate"] as? Int
        else {
            logger.error("✗ [8] metadata 파싱 실패 — raw: \(metadata)")
            throw ImportRecordingError.malformedMetadata
        }

        guard duration.isFinite, (0...2_678_400).contains(duration),
              startedAtTS.isFinite, (0...4_102_444_800).contains(startedAtTS),
              sampleCount > 0, rate > 0, rate <= 1000 else {
            throw ImportRecordingError.malformedMetadata
        }
        let samples = try MotionSampleSerializer.read(from: tempFileURL)
        guard samples.count == sampleCount else { throw ImportRecordingError.malformedMetadata }

        let session = RecordingSession(
            id:          id,
            startedAt:   Date(timeIntervalSince1970: startedAtTS),
            duration:    duration,
            sampleCount: sampleCount,
            fileName:    "WMTF-\(id.uuidString).bin",
            samplingRate: rate
        )
        try repository.save(session: session, from: tempFileURL)
        logger.debug("✔ [8b] repository.save 완료")

        onRecordingSaved?(session)
        return session
    }
}

enum ImportRecordingError: LocalizedError {
    case malformedMetadata

    var errorDescription: String? {
        "The metadata received from Apple Watch is invalid."
    }
}
