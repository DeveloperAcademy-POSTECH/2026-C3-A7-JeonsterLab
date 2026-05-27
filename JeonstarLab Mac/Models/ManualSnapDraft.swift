//
//  ManualSnapDraft.swift
//  JeonstarLab Mac
//

import Foundation

struct ManualSnapDraft: Equatable {
    let selection: ChartTimeSelection
    let sampleCount: Int
    let snapDuration: Double
    let peakAcceleration: Double
    let peakGyro: Double
    let peakTime: Double
    let dominantAxis: String?
    let rollRange: Double
    let pitchRange: Double
    let yawRange: Double

    var canSave: Bool {
        selection.isUsable && sampleCount > 0
    }
}
