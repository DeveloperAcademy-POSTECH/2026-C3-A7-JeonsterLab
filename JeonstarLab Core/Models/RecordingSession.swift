//
//  RecordingSession.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// 하나의 녹화 세션에 대한 메타데이터.
/// iOS/watchOS 양쪽에서 공유하는 순수 value type.
struct RecordingSession: Identifiable, Hashable {
    let id:           UUID
    let startedAt:    Date
    let duration:     TimeInterval  // 초 단위
    let sampleCount:  Int
    let fileName:     String        // "WMTF-<uuid>.bin"
    let samplingRate: Int           // 50
    let memo:         String

    init(
        id: UUID,
        startedAt: Date,
        duration: TimeInterval,
        sampleCount: Int,
        fileName: String,
        samplingRate: Int,
        memo: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.sampleCount = sampleCount
        self.fileName = fileName
        self.samplingRate = samplingRate
        self.memo = memo
    }
}
