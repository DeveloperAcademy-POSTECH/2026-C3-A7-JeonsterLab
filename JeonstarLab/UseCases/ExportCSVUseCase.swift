//
//  ExportCSVUseCase.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

enum ExportCSVError: Error {
    case sessionNotFound
}

@MainActor
final class ExportCSVUseCase {
    private let recordingRepo: RecordingRepositoryProtocol
    private let labelRepo:     ActivityLabelRepositoryProtocol

    init(recordingRepo: RecordingRepositoryProtocol, labelRepo: ActivityLabelRepositoryProtocol) {
        self.recordingRepo = recordingRepo
        self.labelRepo     = labelRepo
    }

    /// 단일 세션을 CSV 파일로 내보냄. 임시 디렉토리의 파일 URL 반환.
    func execute(sessionID: UUID) throws -> URL {
        guard let session = recordingRepo.recordings.first(where: { $0.id == sessionID }) else {
            throw ExportCSVError.sessionNotFound
        }
        let samples   = try recordingRepo.loadSamples(for: sessionID)
        let labelName = session.activityLabelID
            .flatMap { labelRepo.label(for: $0)?.name } ?? "unlabeled"
        return try writeCSV(rows: [(session, samples, labelName)])
    }

    // MARK: - Private

    private func writeCSV(rows: [(RecordingSession, [MotionSample], String)]) throws -> URL {
        var lines = ["timestamp,accX,accY,accZ,gyroX,gyroY,gyroZ,gravX,gravY,gravZ,roll,pitch,yaw,label,sessionId"]
        for (session, samples, labelName) in rows {
            let sid = session.id.uuidString
            for s in samples {
                lines.append(
                    "\(d(s.timestamp)),"
                    + "\(d(s.userAccX)),\(d(s.userAccY)),\(d(s.userAccZ)),"
                    + "\(d(s.rotationRateX)),\(d(s.rotationRateY)),\(d(s.rotationRateZ)),"
                    + "\(d(s.gravityX)),\(d(s.gravityY)),\(d(s.gravityZ)),"
                    + "\(d(s.attitudeRoll)),\(d(s.attitudePitch)),\(d(s.attitudeYaw)),"
                    + "\(labelName),\(sid)"
                )
            }
        }
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func d(_ v: Double) -> String { String(format: "%.9f", v) }
}
