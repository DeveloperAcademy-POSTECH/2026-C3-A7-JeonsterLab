//
//  RecordingRepositoryProtocol.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// iPhone 전용: RecordingSession 메타데이터와 raw binary 파일을 영구 저장.
/// 구현체: RecordingRepository (iOS 타겟, SwiftData + FileManager)
protocol RecordingRepositoryProtocol: AnyObject {
    /// 모든 녹화 세션 목록. 최신 순 정렬.
    var recordings: [RecordingSession] { get }

    /// 메타데이터를 저장하고 raw 파일을 영구 디렉토리로 이동.
    /// tempFileURL: WCSession이 전달한 임시 파일 URL.
    func save(session: RecordingSession, from tempFileURL: URL) throws

    /// 메타데이터와 관련 binary 파일을 삭제.
    func delete(sessionID: UUID) throws

    /// 주어진 세션의 binary 파일에서 모든 샘플을 읽어 반환.
    func loadSamples(for sessionID: UUID) throws -> [MotionSample]

    /// 세션에 Activity 레이블을 지정. nil 전달 시 레이블 해제.
    func assignLabel(_ labelID: UUID?, to sessionID: UUID) throws
}
