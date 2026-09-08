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
    private var recordingStartedAt: Date?
    private var deliveredSampleCount = 0
    private var lastSampleTimestamp: TimeInterval?
    private var maxSampleGap: TimeInterval = 0
    private var lastProgressLogTime: TimeInterval = 0

    private(set) var isRecording = false

    /// 백그라운드 세션이 만료되거나 예기치 않게 종료될 때 호출됨.
    /// RecordingViewModel.stopRecording()을 연결해 자동 종료 처리.
    var onRecordingFailure: ((String) -> Void)?

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

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0

        // Core Motion delivery is kept off the main queue so UI work cannot delay sampling.
        motionManager.startDeviceMotionUpdates(to: motionQueue) { data, error in
            if let error {
                motionLogger.error("deviceMotion update error: \(error.localizedDescription)")
                Task { @MainActor in self.onRecordingFailure?("Motion recording stopped. Check Motion & Fitness permissions. \(error.localizedDescription)") }
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

enum MotionTrackerError: LocalizedError {
    case hardwareUnavailable

    var errorDescription: String? {
        switch self {
        case .hardwareUnavailable:
            return "Motion sensors are not available on this device."
        }
    }
}
