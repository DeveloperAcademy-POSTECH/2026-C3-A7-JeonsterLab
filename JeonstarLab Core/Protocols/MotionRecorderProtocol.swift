//
//  MotionRecorderProtocol.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// Watch 전용: CMDeviceMotion 업데이트 시작/중지 및 샘플 제공.
/// 구현체: MotionTracker (watchOS 타겟)
protocol MotionRecorderProtocol: AnyObject {
    /// CMMotionManager가 업데이트를 활성 전달 중인지 여부.
    var isRecording: Bool { get }

    /// 50Hz CMDeviceMotion 업데이트를 시작.
    /// 각 업데이트는 MainActor에서 onSample을 호출.
    /// 하드웨어를 사용할 수 없는 경우 throw.
    func startRecording(onSample: @escaping @MainActor (MotionSample) -> Void) throws

    /// 업데이트를 중지. 이미 중지된 경우 안전하게 호출 가능.
    func stopRecording()
}
