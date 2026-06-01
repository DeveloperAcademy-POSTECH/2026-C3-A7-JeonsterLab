//
//  MotionTracker.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import CoreMotion
import os
import WatchKit

private let motionLogger = Logger(subsystem: "com.iseungjun.Wrist-Motion", category: "Motion")

@Observable
final class MotionTracker: NSObject, MotionRecorderProtocol {

    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.iseungjun.Wrist-Motion.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var extendedSession: WKExtendedRuntimeSession?
    private var extendedSessionStarted = false
    private var recordingStartedAt: Date?
    private var deliveredSampleCount = 0
    private var lastSampleTimestamp: TimeInterval?
    private var maxSampleGap: TimeInterval = 0
    private var lastProgressLogTime: TimeInterval = 0

    private(set) var isRecording = false

    /// 백그라운드 세션이 만료되거나 예기치 않게 종료될 때 호출됨.
    /// RecordingViewModel.stopRecording()을 연결해 자동 종료 처리.
    var onExtendedSessionExpired: (() -> Void)?

    func startRecording(onSample: @escaping (MotionSample) -> Void) throws {
        motionLogger.info("startRecording requested. available=\(self.motionManager.isDeviceMotionAvailable), active=\(self.motionManager.isDeviceMotionActive), isRecording=\(self.isRecording)")
        guard motionManager.isDeviceMotionAvailable else {
            throw MotionTrackerError.hardwareUnavailable
        }
        guard !isRecording else { return }

        recordingStartedAt = Date()
        deliveredSampleCount = 0
        lastSampleTimestamp = nil
        maxSampleGap = 0
        lastProgressLogTime = 0

        // CMMotionManager 시작 전에 백그라운드 세션을 먼저 활성화
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0

        // Core Motion delivery is kept off the main queue so UI work cannot delay sampling.
        motionManager.startDeviceMotionUpdates(to: motionQueue) { data, error in
            if let error {
                motionLogger.error("deviceMotion update error: \(error.localizedDescription)")
                return
            }
            guard let data else { return }

            self.recordSampleTiming(timestamp: data.timestamp)

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
            onSample(sample)
        }
        isRecording = true
    }

    func stopRecording() {
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let expectedCount = Int((elapsed * 50.0).rounded())
        motionLogger.info("stopRecording requested. delivered=\(self.deliveredSampleCount), expected≈\(expectedCount), elapsed=\(elapsed, format: .fixed(precision: 2))s, maxGap=\(self.maxSampleGap, format: .fixed(precision: 3))s, active=\(self.motionManager.isDeviceMotionActive)")
        motionManager.stopDeviceMotionUpdates()
        extendedSession?.invalidate()
        extendedSession = nil
        extendedSessionStarted = false
        recordingStartedAt = nil
        isRecording = false
    }

    private func recordSampleTiming(timestamp: TimeInterval) {
        deliveredSampleCount += 1

        if let lastSampleTimestamp {
            let gap = timestamp - lastSampleTimestamp
            if gap > maxSampleGap {
                maxSampleGap = gap
            }
            if gap > 0.1 {
                motionLogger.warning("motion sample gap detected. gap=\(gap, format: .fixed(precision: 3))s, count=\(self.deliveredSampleCount)")
            }
        }

        lastSampleTimestamp = timestamp

        guard let recordingStartedAt else { return }
        let elapsed = Date().timeIntervalSince(recordingStartedAt)
        if elapsed - lastProgressLogTime >= 1.0 {
            lastProgressLogTime = elapsed
            let expectedCount = Int((elapsed * 50.0).rounded())
            motionLogger.info("recording progress. delivered=\(self.deliveredSampleCount), expected≈\(expectedCount), maxGap=\(self.maxSampleGap, format: .fixed(precision: 3))s, active=\(self.motionManager.isDeviceMotionActive)")
        }
    }
}

extension MotionTracker: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        extendedSessionStarted = true
        motionLogger.info("extended runtime session started")
    }

    /// 세션 만료 약 5분 전에 호출됨 — 녹화를 자동 종료
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        motionLogger.warning("extended runtime session will expire")
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
        if let error {
            motionLogger.error("extended runtime session invalidated. reason=\(reason.rawValue), error=\(error.localizedDescription)")
        } else {
            motionLogger.info("extended runtime session invalidated. reason=\(reason.rawValue)")
        }
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
