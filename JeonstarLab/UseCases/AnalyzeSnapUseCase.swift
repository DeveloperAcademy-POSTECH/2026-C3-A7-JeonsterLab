//
//  AnalyzeSnapUseCase.swift
//  Wrist Motion
//

import Foundation

struct SnapAnalysisResult {
    let events: [SnapEventSummary]

    var hasEvents: Bool {
        !events.isEmpty
    }

    func event(at index: Int) -> SnapEventSummary? {
        guard events.indices.contains(index) else { return events.first }
        return events[index]
    }
}

struct SnapEventSummary: Identifiable {
    let id = UUID()

    let eventIndex: Int

    let startIndex: Int
    let peakIndex: Int
    let endIndex: Int

    let startTime: Double
    let peakTime: Double
    let endTime: Double

    let peakAcceleration: Double
    let peakGyro: Double
    let peakDelay: Double
    let snapDuration: Double

    let dominantAxis: SnapAxis

    let rollRange: Double
    let pitchRange: Double
    let yawRange: Double

    let confidence: SnapConfidence

    var eventTitle: String {
        "\(eventIndex + 1)번째 뒤집기"
    }

    var snapPeakTimeText: String {
        String(format: "%.2f초", peakTime)
    }

    var snapRangeText: String {
        String(format: "%.2fs ~ %.2fs", startTime, endTime)
    }

    var peakAccelerationText: String {
        String(format: "%.2f g", peakAcceleration)
    }

    var peakGyroText: String {
        String(format: "%.2f rad/s", peakGyro)
    }

    var peakDelayText: String {
        String(format: "%.2f s", peakDelay)
    }

    var snapDurationText: String {
        String(format: "%.2f s", snapDuration)
    }

    var dominantAxisText: String {
        dominantAxis.displayName
    }

    var rollRangeText: String {
        String(format: "%.1f°", rollRange.radianToDegree)
    }

    var pitchRangeText: String {
        String(format: "%.1f°", pitchRange.radianToDegree)
    }

    var yawRangeText: String {
        String(format: "%.1f°", yawRange.radianToDegree)
    }

    var confidenceText: String {
        confidence.displayName
    }

    var interpretation: String {
        switch confidence {
        case .high:
            return "가속도와 회전속도가 짧은 구간 안에서 함께 강하게 나타났습니다. 실제 뒤집기 스냅일 가능성이 높은 구간입니다."
        case .medium:
            return "스냅 후보 구간이 감지되었습니다. 실제 뒤집기인지 확인하려면 그래프의 빨간 피크 지점과 동작 영상을 함께 비교하는 것이 좋습니다."
        case .low:
            return "스냅 후보는 감지되었지만 신뢰도는 낮습니다. 천천히 기울인 동작이나 일반 흔들림이 포함되었을 수 있습니다."
        }
    }
}

enum SnapAxis {
    case x
    case y
    case z

    var displayName: String {
        switch self {
        case .x:
            return "X축"
        case .y:
            return "Y축"
        case .z:
            return "Z축"
        }
    }
}

enum SnapConfidence {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high:
            return "높음"
        case .medium:
            return "보통"
        case .low:
            return "낮음"
        }
    }
}

enum AnalyzeSnapUseCase {
    private static let samplingRate: Double = 50.0
    private static let snapThresholdRatio: Double = 0.58

    private static let minimumSnapDuration: Double = 0.08
    private static let maximumSnapDuration: Double = 0.80
    private static let minimumGapBetweenSnaps: Double = 0.35

    static func execute(samples: [MotionSample]) -> SnapAnalysisResult {
        guard samples.count >= 2 else {
            return SnapAnalysisResult(events: [])
        }

        let accelerationMagnitudes = samples.map { sample in
            vectorMagnitude(
                x: sample.userAccX,
                y: sample.userAccY,
                z: sample.userAccZ
            )
        }

        let gyroMagnitudes = samples.map { sample in
            vectorMagnitude(
                x: sample.rotationRateX,
                y: sample.rotationRateY,
                z: sample.rotationRateZ
            )
        }

        let gyroDeltas = calculateDeltas(from: gyroMagnitudes)

        let snapScores = calculateSnapScores(
            accelerationMagnitudes: accelerationMagnitudes,
            gyroMagnitudes: gyroMagnitudes,
            gyroDeltas: gyroDeltas
        )

        let ranges = detectSnapRanges(from: snapScores, samples: samples)

        let events = ranges.enumerated().compactMap { eventIndex, range in
            makeEventSummary(
                eventIndex: eventIndex,
                range: range,
                samples: samples,
                accelerationMagnitudes: accelerationMagnitudes,
                gyroMagnitudes: gyroMagnitudes,
                snapScores: snapScores
            )
        }

        return SnapAnalysisResult(events: events)
    }

    private static func vectorMagnitude(x: Double, y: Double, z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private static func calculateDeltas(from values: [Double]) -> [Double] {
        guard values.count >= 2 else { return values.map { _ in 0 } }

        var result = Array(repeating: 0.0, count: values.count)

        for index in 1..<values.count {
            result[index] = abs(values[index] - values[index - 1])
        }

        return result
    }

    private static func calculateSnapScores(
        accelerationMagnitudes: [Double],
        gyroMagnitudes: [Double],
        gyroDeltas: [Double]
    ) -> [Double] {
        let normalizedAcceleration = normalize(accelerationMagnitudes)
        let normalizedGyro = normalize(gyroMagnitudes)
        let normalizedGyroDelta = normalize(gyroDeltas)

        let count = min(
            normalizedAcceleration.count,
            normalizedGyro.count,
            normalizedGyroDelta.count
        )

        guard count > 0 else { return [] }

        return (0..<count).map { index in
            normalizedAcceleration[index] * 0.35
            + normalizedGyro[index] * 0.45
            + normalizedGyroDelta[index] * 0.20
        }
    }

    private static func normalize(_ values: [Double]) -> [Double] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return values.map { _ in 0 }
        }

        return values.map { $0 / maxValue }
    }

    private static func detectSnapRanges(
        from scores: [Double],
        samples: [MotionSample]
    ) -> [ClosedRange<Int>] {
        guard let maxScore = scores.max(), maxScore > 0 else { return [] }

        let threshold = maxScore * snapThresholdRatio
        let activeIndices = scores.indices.filter { scores[$0] >= threshold }

        guard !activeIndices.isEmpty else { return [] }

        let rawRanges = groupContinuousIndices(activeIndices)

        let filteredRanges = rawRanges.filter { range in
            let duration = duration(of: range, samples: samples)
            return duration >= minimumSnapDuration && duration <= maximumSnapDuration
        }

        return mergeNearbyRanges(filteredRanges, samples: samples)
    }

    private static func groupContinuousIndices(_ indices: [Int]) -> [ClosedRange<Int>] {
        guard let first = indices.first else { return [] }

        var ranges: [ClosedRange<Int>] = []
        var start = first
        var previous = first

        for index in indices.dropFirst() {
            if index == previous + 1 {
                previous = index
            } else {
                ranges.append(start...previous)
                start = index
                previous = index
            }
        }

        ranges.append(start...previous)
        return ranges
    }

    private static func mergeNearbyRanges(
        _ ranges: [ClosedRange<Int>],
        samples: [MotionSample]
    ) -> [ClosedRange<Int>] {
        guard !ranges.isEmpty else { return [] }

        var merged: [ClosedRange<Int>] = []
        var current = ranges[0]

        for next in ranges.dropFirst() {
            let gap = secondsBetween(current.upperBound, next.lowerBound, samples: samples)

            if gap <= minimumGapBetweenSnaps {
                current = current.lowerBound...next.upperBound
            } else {
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }

    private static func makeEventSummary(
        eventIndex: Int,
        range: ClosedRange<Int>,
        samples: [MotionSample],
        accelerationMagnitudes: [Double],
        gyroMagnitudes: [Double],
        snapScores: [Double]
    ) -> SnapEventSummary? {
        guard samples.indices.contains(range.lowerBound),
              samples.indices.contains(range.upperBound) else {
            return nil
        }

        let peakIndex = indexOfMaxValue(in: snapScores, range: range)

        let peakAccelerationIndex = indexOfMaxValue(
            in: accelerationMagnitudes,
            range: range
        )

        let peakGyroIndex = indexOfMaxValue(
            in: gyroMagnitudes,
            range: range
        )

        let peakAcceleration = accelerationMagnitudes[peakAccelerationIndex]
        let peakGyro = gyroMagnitudes[peakGyroIndex]

        let peakDelay = secondsBetween(
            peakAccelerationIndex,
            peakGyroIndex,
            samples: samples
        )

        let snapDuration = duration(of: range, samples: samples)
        let attitudeRange = attitudeRange(in: samples, range: range)
        let dominantAxis = dominantRotationAxis(in: samples, range: range)

        return SnapEventSummary(
            eventIndex: eventIndex,
            startIndex: range.lowerBound,
            peakIndex: peakIndex,
            endIndex: range.upperBound,
            startTime: relativeTime(at: range.lowerBound, samples: samples),
            peakTime: relativeTime(at: peakIndex, samples: samples),
            endTime: relativeTime(at: range.upperBound, samples: samples),
            peakAcceleration: peakAcceleration,
            peakGyro: peakGyro,
            peakDelay: peakDelay,
            snapDuration: snapDuration,
            dominantAxis: dominantAxis,
            rollRange: attitudeRange.roll,
            pitchRange: attitudeRange.pitch,
            yawRange: attitudeRange.yaw,
            confidence: confidence(
                peakDelay: peakDelay,
                snapDuration: snapDuration,
                peakAcceleration: peakAcceleration,
                peakGyro: peakGyro
            )
        )
    }

    private static func indexOfMaxValue(
        in values: [Double],
        range: ClosedRange<Int>
    ) -> Int {
        range
            .filter { values.indices.contains($0) }
            .max(by: { values[$0] < values[$1] }) ?? range.lowerBound
    }

    private static func secondsBetween(
        _ lhs: Int,
        _ rhs: Int,
        samples: [MotionSample]
    ) -> Double {
        guard samples.indices.contains(lhs),
              samples.indices.contains(rhs) else {
            return Double(abs(lhs - rhs)) / samplingRate
        }

        let timestampDelay = abs(samples[lhs].timestamp - samples[rhs].timestamp)

        if timestampDelay.isFinite, timestampDelay > 0 {
            return timestampDelay
        }

        return Double(abs(lhs - rhs)) / samplingRate
    }

    private static func relativeTime(at index: Int, samples: [MotionSample]) -> Double {
        guard let first = samples.first,
              samples.indices.contains(index) else {
            return Double(index) / samplingRate
        }

        let time = samples[index].timestamp - first.timestamp

        if time.isFinite, time >= 0 {
            return time
        }

        return Double(index) / samplingRate
    }

    private static func duration(
        of range: ClosedRange<Int>,
        samples: [MotionSample]
    ) -> Double {
        guard samples.indices.contains(range.lowerBound),
              samples.indices.contains(range.upperBound) else {
            return Double(max(range.count - 1, 0)) / samplingRate
        }

        let timestampDuration = samples[range.upperBound].timestamp - samples[range.lowerBound].timestamp

        if timestampDuration.isFinite, timestampDuration > 0 {
            return timestampDuration
        }

        return Double(max(range.count - 1, 0)) / samplingRate
    }

    private static func attitudeRange(
        in samples: [MotionSample],
        range: ClosedRange<Int>
    ) -> (roll: Double, pitch: Double, yaw: Double) {
        let safeSamples = samples.enumerated()
            .filter { range.contains($0.offset) }
            .map(\.element)

        guard !safeSamples.isEmpty else { return (0, 0, 0) }

        let rolls = safeSamples.map(\.attitudeRoll)
        let pitches = safeSamples.map(\.attitudePitch)
        let yaws = safeSamples.map(\.attitudeYaw)

        return (
            rangeWidth(of: rolls),
            rangeWidth(of: pitches),
            rangeWidth(of: yaws)
        )
    }

    private static func rangeWidth(of values: [Double]) -> Double {
        guard let minValue = values.min(),
              let maxValue = values.max() else {
            return 0
        }

        return maxValue - minValue
    }

    private static func dominantRotationAxis(
        in samples: [MotionSample],
        range: ClosedRange<Int>
    ) -> SnapAxis {
        let safeSamples = samples.enumerated()
            .filter { range.contains($0.offset) }
            .map(\.element)

        guard !safeSamples.isEmpty else { return .x }

        let xAverage = safeSamples.map { abs($0.rotationRateX) }.reduce(0, +) / Double(safeSamples.count)
        let yAverage = safeSamples.map { abs($0.rotationRateY) }.reduce(0, +) / Double(safeSamples.count)
        let zAverage = safeSamples.map { abs($0.rotationRateZ) }.reduce(0, +) / Double(safeSamples.count)

        if xAverage >= yAverage, xAverage >= zAverage {
            return .x
        } else if yAverage >= xAverage, yAverage >= zAverage {
            return .y
        } else {
            return .z
        }
    }

    private static func confidence(
        peakDelay: Double,
        snapDuration: Double,
        peakAcceleration: Double,
        peakGyro: Double
    ) -> SnapConfidence {
        if peakDelay <= 0.08,
           snapDuration <= 0.45,
           peakAcceleration > 0.5,
           peakGyro > 2.0 {
            return .high
        }

        if peakDelay <= 0.18,
           snapDuration <= 0.65 {
            return .medium
        }

        return .low
    }
}

private extension Double {
    var radianToDegree: Double {
        self * 180.0 / .pi
    }
}
