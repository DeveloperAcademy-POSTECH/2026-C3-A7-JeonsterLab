// Created by 이돈혁

import Foundation

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
            return "Idle"
        case .advertising:
            return "Ready to Receive"
        case .connected:
            return "iPhone Connected"
        case .receiving:
            return "Receiving"
        case .completed:
            return "Received"
        case .failed(let message):
            return "Transfer failed: \(message)"
        }
    }
}
