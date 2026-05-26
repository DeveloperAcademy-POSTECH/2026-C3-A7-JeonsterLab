//
//  MacHomeViewModel.swift
//  JeonstarLab Mac
//

import Foundation

@Observable
final class MacHomeViewModel {
    var receiverStatus: MacReceiverStatus = .ready
    var connectedPeerName: String?
    var receivedItems: [MacReceivedItem] = []

    var statusText: String {
        receiverStatus.displayText
    }

    var connectedPeerText: String {
        connectedPeerName ?? "연결된 iPhone 없음"
    }
}

enum MacReceiverStatus: Equatable {
    case idle
    case ready
    case waiting
    case connected
    case receiving
    case completed
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "대기 중"
        case .ready:
            return "수신 대기 준비"
        case .waiting:
            return "수신 대기 중"
        case .connected:
            return "iPhone 연결됨"
        case .receiving:
            return "수신 중"
        case .completed:
            return "수신 완료"
        case .failed(let message):
            return "수신 실패: \(message)"
        }
    }
}
