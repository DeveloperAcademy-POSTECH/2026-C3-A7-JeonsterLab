import Foundation

/// Time-based activity segmentation, not activity classification or repetition counting.
/// User acceleration is in g; rotation rate is in rad/s. No recording-wide peak normalization.
nonisolated enum AutoSegmentDetector {
    enum DetectionError: LocalizedError {
        case unorderedTime
        var errorDescription: String? { "Sample times must increase. Check the recording before analyzing it." }
    }
    static func analyze(_ samples: [MotionCSVSample]) throws -> AutoSegmentReview {
        var result = AutoSegmentReview(analyzedAt: Date())
        guard samples.count > 1 else { return result }
        var start: Double?
        var lastActive = 0.0
        var peakTime = 0.0
        var peakScore = 0.0
        var smoothed = 0.0
        var previousTime: Double?
        var runStart = 0.0
        var ranges: [(start: Double, end: Double, peak: Double)] = []

        func finish(at time: Double) {
            if let start, lastActive - start >= 0.25 {
                ranges.append((max(runStart, start - 0.12), min(time, lastActive + 0.12), peakTime))
            }
            start = nil
            peakScore = 0
        }

        for (index, sample) in samples.enumerated() {
            if index % 1024 == 0 { try Task.checkCancellation() }
            let t = sample.relativeTime
            let axes = [sample.userAccX, sample.userAccY, sample.userAccZ,
                        sample.rotationRateX, sample.rotationRateY, sample.rotationRateZ]
            guard t.isFinite, t >= 0, axes.allSatisfy({ $0.isFinite && abs($0) < 1e6 }) else {
                finish(at: previousTime ?? lastActive)
                previousTime = nil
                smoothed = 0
                continue
            }
            if let previousTime, t <= previousTime { throw DetectionError.unorderedTime }
            if let previousTime, t - previousTime > 0.25 {
                finish(at: previousTime)
                smoothed = 0
                runStart = t
            } else if previousTime == nil {
                runStart = t
            }
            let dt = previousTime.map { min(0.25, max(0.001, t - $0)) } ?? 0.02
            previousTime = t
            let acceleration = hypot(hypot(axes[0], axes[1]), axes[2])
            let rotation = hypot(hypot(axes[3], axes[4]), axes[5])
            let score = max(acceleration / 0.08, rotation / 0.6)
            smoothed += (1 - exp(-dt / 0.08)) * (score - smoothed)
            if start == nil, smoothed >= 1 {
                start = t
                lastActive = t
                peakTime = t
                peakScore = smoothed
            }
            if start != nil {
                if smoothed >= 0.5 { lastActive = t }
                if smoothed > peakScore { peakScore = smoothed; peakTime = t }
                if t - lastActive >= 0.4 { finish(at: t) }
            }
            if ranges.count >= 2000 { result.reachedLimit = true; break }
        }
        finish(at: previousTime ?? lastActive)
        result.candidates = ranges.prefix(2000).filter { $0.end > $0.start }.map { range in
            AutoSegmentCandidate(
                id: "motion-v1-\(range.start.bitPattern)-\(range.end.bitPattern)",
                startTime: range.start, endTime: range.end,
                peakTime: min(range.end, max(range.start, range.peak))
            )
        }
        return result
    }
}
