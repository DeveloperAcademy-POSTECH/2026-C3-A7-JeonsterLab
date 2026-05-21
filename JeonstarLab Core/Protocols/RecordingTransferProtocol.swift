//
//  RecordingTransferProtocol.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import Foundation

/// Watch 전용: 완성된 녹화 파일을 페어링된 iPhone으로 전송.
/// 구현체: WatchTransferService (watchOS 타겟)
protocol RecordingTransferProtocol: AnyObject {
    /// 파일을 백그라운드 전송 큐에 추가. 즉시 반환.
    /// Watch 앱이 일시 중지된 경우에도 시스템이 파일을 전달.
    func transfer(fileURL: URL, session: RecordingSession)
}
