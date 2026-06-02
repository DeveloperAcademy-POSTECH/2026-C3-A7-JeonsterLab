//
//  FileReceiveService.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import WatchConnectivity
import os

private let logger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Receive")

/// WatchSessionManager.onFileReceived 클로저에서 호출.
/// WCSessionFile → ImportRecordingUseCase로 위임.
@MainActor
final class FileReceiveService {

    private let importUseCase: ImportRecordingUseCase
    private let sessionManager: WatchSessionManager

    init(importUseCase: ImportRecordingUseCase, sessionManager: WatchSessionManager) {
        self.importUseCase = importUseCase
        self.sessionManager = sessionManager
    }

    func handle(file: WCSessionFile) {
        logger.debug("▶︎ [7] FileReceiveService.handle — file: \(file.fileURL.lastPathComponent)")
        Task { @MainActor in
            do {
                let session = try importUseCase.execute(
                    tempFileURL: file.fileURL,
                    metadata:    file.metadata ?? [:]
                )
                logger.debug("✔ [9] ImportUseCase 성공")
                sessionManager.sendRecordingImportAck(
                    sessionID: session.id,
                    fileName: session.fileName
                )
            } catch {
                logger.error("✗ [9] ImportUseCase 실패 — \(error.localizedDescription)")
            }
        }
    }
}
