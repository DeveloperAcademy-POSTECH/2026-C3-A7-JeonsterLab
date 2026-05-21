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

    init(importUseCase: ImportRecordingUseCase) {
        self.importUseCase = importUseCase
    }

    func handle(file: WCSessionFile) {
        logger.debug("▶︎ [7] FileReceiveService.handle — file: \(file.fileURL.lastPathComponent)")
        Task { @MainActor in
            do {
                try importUseCase.execute(
                    tempFileURL: file.fileURL,
                    metadata:    file.metadata ?? [:]
                )
                logger.debug("✔ [9] ImportUseCase 성공")
            } catch {
                logger.error("✗ [9] ImportUseCase 실패 — \(error.localizedDescription)")
            }
        }
    }
}
