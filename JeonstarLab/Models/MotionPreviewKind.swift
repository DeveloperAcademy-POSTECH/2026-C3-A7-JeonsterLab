import Foundation

enum MotionPreviewKind: String, CaseIterable, Identifiable {
    case acceleration, gyroscope, attitude
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var unit: String {
        switch self {
        case .acceleration: "g"
        case .gyroscope: "rad/s"
        case .attitude: "rad"
        }
    }
    var axes: [(name: String, value: KeyPath<MotionSample, Double>)] {
        switch self {
        case .acceleration: [("X", \.userAccX), ("Y", \.userAccY), ("Z", \.userAccZ)]
        case .gyroscope: [("X", \.rotationRateX), ("Y", \.rotationRateY), ("Z", \.rotationRateZ)]
        case .attitude: [("Roll", \.attitudeRoll), ("Pitch", \.attitudePitch), ("Yaw", \.attitudeYaw)]
        }
    }
}

enum MotionPreviewTimeline {
    /// Sensor timestamps preserve real gaps. Legacy invalid timestamps fall back to the saved rate.
    static func seconds(samples: [MotionSample], samplingRate: Int) -> [Double] {
        guard let first = samples.first else { return [] }
        let valid = samples.allSatisfy { $0.timestamp.isFinite }
            && zip(samples, samples.dropFirst()).allSatisfy { $1.timestamp > $0.timestamp }
        if valid { return samples.map { $0.timestamp - first.timestamp } }
        return samples.indices.map { Double($0) / Double(max(samplingRate, 1)) }
    }
}
