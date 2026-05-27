//
//  MotionCSVSample.swift
//  JeonstarLab Mac
//

import Foundation

struct MotionCSVSample: Identifiable, Equatable {
    var id: Int { index }

    let index: Int
    let timestamp: Double
    let relativeTime: Double
    let attitudeRoll: Double
    let attitudePitch: Double
    let attitudeYaw: Double
    let rotationRateX: Double
    let rotationRateY: Double
    let rotationRateZ: Double
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double
    let userAccX: Double
    let userAccY: Double
    let userAccZ: Double
}
