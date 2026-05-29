//
//  MotionTracker.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import CoreMotion
import WatchKit

@Observable
final class MotionTracker: NSObject, MotionRecorderProtocol {

    private let motionManager = CMMotionManager()
    private var extendedSession: WKExtendedRuntimeSession?
    private var extendedSessionStarted = false

    private(set) var isRecording = false

    /// 백그라운드 세션이 만료되거나 예기치 않게 종료될 때 호출됨.
    /// RecordingViewModel.stopRecording()을 연결해 자동 종료 처리.
    var onExtendedSessionExpired: (() -> Void)?

    func startRecording(onSample: @escaping @MainActor (MotionSample) -> Void) throws {
        guard motionManager.isDeviceMotionAvailable else {
            throw MotionTrackerError.hardwareUnavailable
        }
        guard !isRecording else { return }

        // CMMotionManager 시작 전에 백그라운드 세션을 먼저 활성화
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0

        // OperationQueue.main 사용 → MainActor와 호환
        motionManager.startDeviceMotionUpdates(to: .main) { data, error in
            guard let data, error == nil else { return }
            let sample = MotionSample(
                timestamp:      data.timestamp,
                attitudeRoll:   data.attitude.roll,
                attitudePitch:  data.attitude.pitch,
                attitudeYaw:    data.attitude.yaw,
                rotationRateX:  data.rotationRate.x,
                rotationRateY:  data.rotationRate.y,
                rotationRateZ:  data.rotationRate.z,
                gravityX:       data.gravity.x,
                gravityY:       data.gravity.y,
                gravityZ:       data.gravity.z,
                userAccX:       data.userAcceleration.x,
                userAccY:       data.userAcceleration.y,
                userAccZ:       data.userAcceleration.z
            )
            Task { @MainActor in onSample(sample) }
        }
        isRecording = true
    }

    func stopRecording() {
        motionManager.stopDeviceMotionUpdates()
        extendedSession?.invalidate()
        extendedSession = nil
        extendedSessionStarted = false
        isRecording = false
    }
}

extension MotionTracker: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        extendedSessionStarted = true
    }

    /// 세션 만료 약 5분 전에 호출됨 — 녹화를 자동 종료
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in onExtendedSessionExpired?() }
    }

    /// 세션 종료 — 정상 시작 이후 종료된 경우에만 녹화 자동 종료.
    /// 세션이 시작조차 못하고 실패한 경우(설정 문제 등)에는 녹화를 유지
    /// (포그라운드에서는 CMMotionManager가 계속 동작하므로 데이터 수집 가능).
    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        guard isRecording, extendedSessionStarted else {
            extendedSessionStarted = false
            return
        }
        extendedSessionStarted = false
        Task { @MainActor in onExtendedSessionExpired?() }
    }
}

enum MotionTrackerError: LocalizedError {
    case hardwareUnavailable

    var errorDescription: String? {
        switch self {
        case .hardwareUnavailable:
            return "이 기기에서 모션 센서를 사용할 수 없습니다."
        }
    }
}
