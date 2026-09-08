import Foundation

@main
struct AutoSegmentSmokeTests {
    static func require(_ condition: Bool, _ message: String = "Check failed") {
        precondition(condition, message)
    }
    static func sample(_ time: Double, acceleration: Double = 0, gyro: Double = 0) -> MotionCSVSample {
        MotionCSVSample(index: 0, timestamp: time, relativeTime: time,
                        attitudeRoll: 0, attitudePitch: 0, attitudeYaw: 0,
                        rotationRateX: 0, rotationRateY: gyro, rotationRateZ: 0,
                        gravityX: 0, gravityY: 0, gravityZ: 1,
                        userAccX: acceleration, userAccY: 0, userAccZ: 0)
    }
    static func signal(rate: Double = 50, _ value: (Double) -> Double) -> [MotionCSVSample] {
        (0..<Int(10 * rate)).map { let t = Double($0) / rate; return sample(t, acceleration: value(t)) }
    }
    static func main() async throws {
        require(try AutoSegmentDetector.analyze([]).pending.isEmpty)
        let quiet = signal { _ in 0.005 }
        require(try AutoSegmentDetector.analyze(quiet).pending.isEmpty)
        let pulse: (Double) -> Double = { t in (2...3).contains(t) || (6...7).contains(t) ? 0.3 : 0.005 }
        let result = try AutoSegmentDetector.analyze(signal(pulse))
        require(result.pending.count == 2)
        require(result.pending[0].startTime < 2.1 && result.pending[0].endTime > 3)
        let otherRate = try AutoSegmentDetector.analyze(signal(rate: 100, pulse))
        require(otherRate.pending.count == 2)
        require(abs(result.pending[0].startTime - otherRate.pending[0].startTime) < 0.1)
        require(try AutoSegmentDetector.analyze(signal { t in (2...2.02).contains(t) ? 0.1 : 0 }).pending.isEmpty)
        require(try AutoSegmentDetector.analyze(signal { t in (2...4).contains(t) && !(3...3.1).contains(t) ? 0.3 : 0 }).pending.count == 1)
        require(try AutoSegmentDetector.analyze(signal { t in (2...4).contains(t) ? 0.12 : 0 }).pending.count == 1)
        let rotation = (0..<500).map { i in let t = Double(i) / 50; return sample(t, gyro: (2...4).contains(t) ? 1 : 0) }
        require(try AutoSegmentDetector.analyze(rotation).pending.count == 1)
        let gap = signal { _ in 0.3 }.filter { !((4...5).contains($0.relativeTime)) }
        require(try AutoSegmentDetector.analyze(gap).pending.count == 2, "Do not bridge missing data")
        do { _ = try AutoSegmentDetector.analyze([sample(1), sample(0)]); fatalError("Reject unordered time") }
        catch AutoSegmentDetector.DetectionError.unorderedTime {}
        require(try AutoSegmentDetector.analyze([sample(0, acceleration: .nan), sample(1)]).pending.isEmpty)
        var review = result
        review.candidates[0].status = .dismissed
        review.candidates[1].status = .confirmed
        review.merge(try AutoSegmentDetector.analyze(signal(pulse)))
        require(review.candidates.count == 2 && review.pending.isEmpty)
        let restored = try JSONDecoder().decode(AutoSegmentReview.self, from: JSONEncoder().encode(review))
        require(restored == review)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try AutoSegmentDetector.analyze(signal(pulse))
        }
        do { _ = try await cancelled.value; fatalError("Canceled analysis must stop") }
        catch is CancellationError {}
        print("PASS: quiet/noise, activity ranges, sample rates, short bursts, merging, slow motion, rotation, gaps, invalid data, stable review decisions")
    }
}
