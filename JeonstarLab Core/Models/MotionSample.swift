//
//  MotionSample.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// CMDeviceMotion의 단일 스냅샷.
/// 13개의 Double(IEEE-754)이 연속으로 배치되어 104바이트의 고정 크기를 가짐.
/// 배열을 raw bytes로 직접 읽고 쓸 수 있어 binary 직렬화 시 별도 인코딩 불필요.
struct MotionSample {
    // CMDeviceMotion.timestamp (기기 부팅 이후 경과 초)
    var timestamp: Double

    // CMAttitude — 라디안 단위
    var attitudeRoll:  Double
    var attitudePitch: Double
    var attitudeYaw:   Double

    // CMRotationRate — rad/s
    var rotationRateX: Double
    var rotationRateY: Double
    var rotationRateZ: Double

    // CMAcceleration (중력) — g 단위
    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double

    // CMAcceleration (사용자 가속도) — g 단위
    var userAccX: Double
    var userAccY: Double
    var userAccZ: Double
}

// MARK: - MotionSampleSerializer

/// binary 파일 포맷: [4바이트 magic "WMTF"] [4바이트 version UInt32] [MotionSample × N]
enum MotionSampleSerializer {
    static let magic: UInt32   = 0x574D5446  // "WMTF"
    static let version: UInt32 = 1
    static let headerSize      = 8  // magic(4) + version(4)

    static func read(from url: URL) throws -> [MotionSample] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= headerSize else { throw SerializerError.invalidHeader }

        let readMagic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard readMagic == magic else { throw SerializerError.invalidHeader }

        let payload = data.dropFirst(headerSize)
        let sampleSize = MemoryLayout<MotionSample>.stride
        guard payload.count % sampleSize == 0 else { throw SerializerError.truncated }

        let count = payload.count / sampleSize
        return payload.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: MotionSample.self).prefix(count))
        }
    }

    enum SerializerError: Error {
        case invalidHeader
        case truncated
    }
}
