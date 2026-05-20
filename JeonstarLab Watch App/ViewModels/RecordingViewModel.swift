//
//  RecordingViewModel.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

@Observable
@MainActor
final class RecordingViewModel {

    enum RecordingState {
        case idle
        case recording(startedAt: Date, sessionID: UUID)
        case transferring
        case error(String)
    }

    private(set) var state: RecordingState = .idle

    private let startUseCase: StartRecordingUseCase
    private let stopUseCase: StopRecordingUseCase
    private let hapticManager: WatchHapticManager

    init(
        startUseCase: StartRecordingUseCase,
        stopUseCase: StopRecordingUseCase,
        hapticManager: WatchHapticManager
    ) {
        self.startUseCase = startUseCase
        self.stopUseCase = stopUseCase
        self.hapticManager = hapticManager
    }

    func startRecording() {
        do {
            let id = try startUseCase.execute()
            state = .recording(startedAt: Date(), sessionID: id)

            // Watch 버튼 시작, iPhone 명령 시작 모두 여기로 들어오기 때문에
            // 이 위치에 넣으면 두 경우 모두 Watch에서 햅틱이 울림.
            hapticManager.playRecordingStarted()
        } catch {
            state = .error(error.localizedDescription)
            hapticManager.playError()
        }
    }

    func stopRecording() {
        guard case .recording(let startedAt, let sessionID) = state else { return }

        do {
            try stopUseCase.execute(sessionID: sessionID, startedAt: startedAt)
            state = .transferring

            // Watch 버튼 종료, iPhone 명령 종료 모두 여기로 들어오기 때문에
            // 이 위치에 넣으면 두 경우 모두 Watch에서 햅틱이 울림.
            hapticManager.playRecordingStopped()
        } catch {
            state = .error(error.localizedDescription)
            hapticManager.playError()
        }
    }

    /// 파일 전송 완료 후 idle로 복귀.
    /// 전송 성공/실패 여부에 따라 다른 햅틱을 줄 수 있음.
    func transferDidComplete(error: Error? = nil) {
        if let error {
            state = .error(error.localizedDescription)
            hapticManager.playError()
        } else {
            state = .idle
            hapticManager.playTransferCompleted()
        }
    }
}
