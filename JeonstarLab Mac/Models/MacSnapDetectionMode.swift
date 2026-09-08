//
//  MacSnapDetectionMode.swift
//  JeonstarLab Mac
//

import Foundation

enum MacSnapDetectionMode: String, Decodable, Equatable {
    case none
    case jeonFlip

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .jeonFlip:
            return "Jeon Flipping"
        }
    }
}
