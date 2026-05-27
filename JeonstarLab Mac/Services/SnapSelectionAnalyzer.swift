//
//  SnapSelectionAnalyzer.swift
//  JeonstarLab Mac
//

import Foundation

enum SnapSelectionAnalyzer {
    static func analyze(
        selection: ChartTimeSelection,
        samples: [MotionCSVSample]
    ) -> ManualSnapDraft? {
        let normalized = selection.normalized
        let selectedSamples = samples.filter {
            $0.relativeTime >= normalized.startTime && $0.relativeTime <= normalized.endTime
        }

        guard !selectedSamples.isEmpty else { return nil }

        let peakSample = selectedSamples.max { lhs, rhs in
            combinedScore(lhs) < combinedScore(rhs)
        } ?? selectedSamples[0]

        let dominantAxis = dominantGyroAxis(in: selectedSamples)

        return ManualSnapDraft(
            selection: normalized,
            sampleCount: selectedSamples.count,
            snapDuration: normalized.duration,
            peakAcceleration: accelerationMagnitude(peakSample),
            peakGyro: gyroMagnitude(peakSample),
            peakTime: peakSample.relativeTime,
            dominantAxis: dominantAxis,
            rollRange: range(selectedSamples.map(\.attitudeRoll)),
            pitchRange: range(selectedSamples.map(\.attitudePitch)),
            yawRange: range(selectedSamples.map(\.attitudeYaw))
        )
    }

    private static func combinedScore(_ sample: MotionCSVSample) -> Double {
        accelerationMagnitude(sample) + gyroMagnitude(sample)
    }

    private static func accelerationMagnitude(_ sample: MotionCSVSample) -> Double {
        sqrt(
            sample.userAccX * sample.userAccX
            + sample.userAccY * sample.userAccY
            + sample.userAccZ * sample.userAccZ
        )
    }

    private static func gyroMagnitude(_ sample: MotionCSVSample) -> Double {
        sqrt(
            sample.rotationRateX * sample.rotationRateX
            + sample.rotationRateY * sample.rotationRateY
            + sample.rotationRateZ * sample.rotationRateZ
        )
    }

    private static func dominantGyroAxis(in samples: [MotionCSVSample]) -> String? {
        guard !samples.isEmpty else { return nil }

        let maxX = samples.map { abs($0.rotationRateX) }.max() ?? 0
        let maxY = samples.map { abs($0.rotationRateY) }.max() ?? 0
        let maxZ = samples.map { abs($0.rotationRateZ) }.max() ?? 0

        if maxX >= maxY && maxX >= maxZ { return "X" }
        if maxY >= maxX && maxY >= maxZ { return "Y" }
        return "Z"
    }

    private static func range(_ values: [Double]) -> Double {
        guard let minValue = values.min(), let maxValue = values.max() else { return 0 }
        return maxValue - minValue
    }
}
