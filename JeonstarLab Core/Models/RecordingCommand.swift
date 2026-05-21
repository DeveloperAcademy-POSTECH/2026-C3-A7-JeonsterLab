//
//  RecordingCommand.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// iPhone ↔ Watch 사이에서 주고받는 녹화 제어 명령.
enum RecordingCommand: String {
    case start = "startRecording"
    case stop  = "stopRecording"

    static let messageKey = "command"
}
