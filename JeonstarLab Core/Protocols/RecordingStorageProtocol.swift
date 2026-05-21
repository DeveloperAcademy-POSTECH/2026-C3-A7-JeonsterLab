//
//  RecordingStorageProtocol.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// Watch 전용: 샘플을 메모리에 버퍼링하고 binary 파일로 flush.
/// 구현체: WatchRecordingStorage (watchOS 타겟)
protocol RecordingStorageProtocol: AnyObject {
    /// 현재 버퍼에 있는 샘플 수.
    var bufferCount: Int { get }

    /// 샘플을 메모리 버퍼에 추가.
    func append(_ sample: MotionSample)

    /// 버퍼의 모든 샘플을 새 binary 파일로 flush.
    /// Watch의 임시 디렉토리에 파일 생성 후 URL과 샘플 수 반환.
    /// 버퍼는 비워짐.
    func flush(sessionID: UUID, startedAt: Date) throws -> (url: URL, sampleCount: Int)

    /// 파일 쓰기 없이 버퍼를 버림.
    func discard()
}
