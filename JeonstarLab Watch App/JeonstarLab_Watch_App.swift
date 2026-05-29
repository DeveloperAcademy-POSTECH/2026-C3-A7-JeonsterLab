//
//  Wrist_Motion_WatchApp.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//


import SwiftUI

@main
struct Wrist_Motion_Watch_Watch_AppApp: App {

    // MARK: - DI 구성

    private let sessionManager   = WatchSessionManager()
    private let motionTracker    = MotionTracker()
    private let recordingStorage = WatchRecordingStorage()
    private let hapticManager    = WatchHapticManager()

    private let transferService: WatchTransferService
    private let startUseCase:    StartRecordingUseCase
    private let stopUseCase:     StopRecordingUseCase

    @State private var recordingViewModel: RecordingViewModel

    init() {
        let transfer = WatchTransferService(sessionManager: sessionManager)

        let start = StartRecordingUseCase(
            recorder: motionTracker,
            storage: recordingStorage
        )

        let stop = StopRecordingUseCase(
            recorder: motionTracker,
            storage: recordingStorage,
            transfer: transfer
        )

        let vm = RecordingViewModel(
            startUseCase: start,
            stopUseCase: stop,
            hapticManager: hapticManager
        )

        // 파일 전송 완료 → ViewModel 상태 변경 + 성공/실패 햅틱
        sessionManager.onTransferDidFinish = { [vm] error in
            Task { @MainActor in
                vm.transferDidComplete(error: error)
            }
        }

        // 백그라운드 세션 만료 시 녹화 자동 종료
        motionTracker.onExtendedSessionExpired = { [vm] in
            vm.stopRecording()
        }

        // iPhone으로부터 녹화 명령 수신
        // 여기서 vm.startRecording(), vm.stopRecording()을 호출하기 때문에
        // iPhone에서 시작/종료해도 Watch 햅틱이 정상적으로 울림.
        sessionManager.onCommandReceived = { [vm] command in
            Task { @MainActor in
                switch command {
                case .start:
                    vm.startRecording()
                case .stop:
                    vm.stopRecording()
                }
            }
        }

        transferService = transfer
        startUseCase = start
        stopUseCase = stop
        _recordingViewModel = State(wrappedValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: recordingViewModel,
                storage: recordingStorage
            )
        }
    }
}
