//
//  SnapDetectionMode.swift
//  Wrist Motion
//

import Foundation

enum SnapDetectionMode: String, CaseIterable, Identifiable {
    case none
    case jeonFlip

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .none:
            return "없음"
        case .jeonFlip:
            return "전 부치기"
        }
    }
}
