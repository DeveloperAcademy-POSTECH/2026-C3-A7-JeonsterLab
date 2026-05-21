//
//  RecordingFileStore.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// 파일 시스템 작업에 대한 추상화. 테스트 시 mock으로 교체 가능.
protocol RecordingFileStoreProtocol: AnyObject {
    func moveToDocuments(from tempURL: URL, fileName: String) throws
    func delete(fileName: String) throws
    func urlForFile(named fileName: String) throws -> URL
}

final class RecordingFileStore: RecordingFileStoreProtocol {

    private let directory: URL

    init() {
        directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func moveToDocuments(from tempURL: URL, fileName: String) throws {
        let dest = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
    }

    func delete(fileName: String) throws {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func urlForFile(named fileName: String) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingRepositoryError.fileNotFound
        }
        return url
    }
}

enum RecordingRepositoryError: LocalizedError {
    case notFound
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .notFound:     return "녹화 세션을 찾을 수 없습니다."
        case .fileNotFound: return "녹화 파일을 찾을 수 없습니다."
        }
    }
}
