//
//  WatchTransferService.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Transfer")

/// RecordingTransferProtocol → WatchSessionManager.sendFile 어댑터.
final class WatchTransferService: RecordingTransferProtocol {

    private let sessionManager: WatchSessionManager

    init(sessionManager: WatchSessionManager) {
        self.sessionManager = sessionManager
    }

    func transfer(fileURL: URL, session: RecordingSession) {
        let metadata: [String: Any] = [
            "sessionID":    session.id.uuidString,
            "fileName":     session.fileName,
            "startedAt":    session.startedAt.timeIntervalSince1970,
            "duration":     session.duration,
            "sampleCount":  session.sampleCount,
            "samplingRate": session.samplingRate
        ]
        logger.debug("▶︎ [3a] WatchTransferService.transfer — sessionID: \(session.id.uuidString), sampleCount: \(session.sampleCount)")
        sessionManager.sendFile(file: fileURL, metadata: metadata)
    }
}
