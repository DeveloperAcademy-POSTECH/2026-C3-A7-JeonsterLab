//
//  WatchHapticManager.swift
//  Wrist Motion
//
//  Created by woo sangyoung on 5/20/26.
//


import WatchKit

/// Apple Watch 햅틱 피드백을 한 곳에서 관리하는 객체.
/// Watch 버튼으로 시작/종료하든, iPhone 명령으로 시작/종료하든
/// RecordingViewModel을 거치기 때문에 여기서 공통 처리할 수 있음.
final class WatchHapticManager {

    func playRecordingStarted() {
        WKInterfaceDevice.current().play(.start)
    }

    func playRecordingStopped() {
        WKInterfaceDevice.current().play(.stop)
    }

    func playTransferCompleted() {
        WKInterfaceDevice.current().play(.success)
    }

    func playError() {
        WKInterfaceDevice.current().play(.failure)
    }
}
