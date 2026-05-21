//
//  MotionTracker.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import CoreMotion

@Observable
final class MotionTracker: MotionRecorderProtocol {

    private let motionManager = CMMotionManager()

    private(set) var isRecording = false

    func startRecording(onSample: @escaping @MainActor (MotionSample) -> Void) throws {
        guard motionManager.isDeviceMotionAvailable else {
            throw MotionTrackerError.hardwareUnavailable
        }
        guard !isRecording else { return }

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
        isRecording = false
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
