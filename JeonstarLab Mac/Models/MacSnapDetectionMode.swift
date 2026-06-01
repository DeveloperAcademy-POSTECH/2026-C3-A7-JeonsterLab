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
            return "없음"
        case .jeonFlip:
            return "전 부치기"
        }
    }
}
