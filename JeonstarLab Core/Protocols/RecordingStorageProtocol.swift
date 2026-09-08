//
//  RecordingStorageProtocol.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// Watch 전용: 샘플을 짧게 버퍼링하고 영구 binary 저널에 주기적으로 저장.
/// 구현체: WatchRecordingStorage (watchOS 타겟)
protocol RecordingStorageProtocol: AnyObject {
    func begin(sessionID: UUID, startedAt: Date) throws
    /// 현재 녹화에서 수집한 샘플 수.
    var bufferCount: Int { get }

    /// 샘플을 메모리 버퍼에 추가.
    func append(_ sample: MotionSample)

    /// 남은 샘플을 영구 저장하고 파일을 닫은 뒤 URL과 총 샘플 수 반환.
    /// 수신 확인 전까지 원본 파일을 보존.
    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int)

    /// 파일 쓰기 없이 버퍼를 버림.
    func discard()
}

extension RecordingStorageProtocol {
    func begin(sessionID: UUID, startedAt: Date) throws { discard() }
}
