import Foundation

/// Suggestions are separate from saved snaps: they must never enter an export implicitly.
nonisolated struct AutoSegmentCandidate: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case pending, confirmed, dismissed }
    let id: String
    let startTime: Double
    let endTime: Double
    let peakTime: Double
    var status: Status = .pending
    var confirmedSnapID: String?

    func overlaps(start: Double, end: Double) -> Bool {
        startTime < end && endTime > start
    }
}

nonisolated struct AutoSegmentReview: Codable, Equatable, Sendable {
    var algorithmVersion = 1
    var candidates: [AutoSegmentCandidate] = []
    var analyzedAt: Date?
    var reachedLimit = false

    var pending: [AutoSegmentCandidate] { candidates.filter { $0.status == .pending } }

    /// Keep decisions (including dismissals) and stable IDs across repeated analysis.
    mutating func merge(_ result: AutoSegmentReview) {
        for candidate in result.candidates where !candidates.contains(where: {
            $0.id == candidate.id || $0.overlaps(start: candidate.startTime, end: candidate.endTime)
        }) {
            candidates.append(candidate)
        }
        candidates.sort { $0.startTime < $1.startTime }
        analyzedAt = result.analyzedAt
        reachedLimit = result.reachedLimit
    }
}
