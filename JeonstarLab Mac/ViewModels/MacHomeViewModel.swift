//
//  MacHomeViewModel.swift
//  JeonstarLab Mac
//

import Foundation

@Observable
final class MacHomeViewModel {
    private let receiver = MacPeerReceiver()

    var receiverStatus: MacReceiverStatus = .idle
    var connectedPeerName: String?
    var receivedItems: [MacReceivedItem] = []
    var errorMessage: String?

    init() {
        receiver.onStatusChanged = { [weak self] status in
            self?.receiverStatus = status
        }
        receiver.onConnectedPeerChanged = { [weak self] peerName in
            self?.connectedPeerName = peerName
        }
        receiver.onReceivedFiles = { [weak self] fileURLs in
            let items = fileURLs.map { url in
                MacReceivedItem(
                    fileName: url.lastPathComponent,
                    receivedAt: Date(),
                    savedFileURL: url
                )
            }
            self?.receivedItems.insert(contentsOf: items, at: 0)
        }
        receiver.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    var statusText: String {
        receiverStatus.displayText
    }

    var connectedPeerText: String {
        connectedPeerName ?? "연결된 iPhone 없음"
    }

    var isAdvertising: Bool {
        receiverStatus == .advertising
        || receiverStatus == .connected
        || receiverStatus == .receiving
        || receiverStatus == .completed
    }

    func startReceiver() {
        errorMessage = nil
        receiver.startAdvertising()
    }

    func stopReceiver() {
        receiver.stopAdvertising()
    }
}

enum MacReceiverStatus: Equatable {
    case idle
    case advertising
    case connected
    case receiving
    case completed
    case failed(String)

    var displayText: String {
        switch self {
        case .idle:
            return "대기 중"
        case .advertising:
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
