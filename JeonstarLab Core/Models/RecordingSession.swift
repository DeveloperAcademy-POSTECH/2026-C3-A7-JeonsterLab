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
}
