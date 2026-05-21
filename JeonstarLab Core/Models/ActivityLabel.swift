//
//  ActivityLabel.swift
//  JeonstarLab Core
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation

/// 사용자 정의 Activity 레이블. iOS/watchOS 공유 value type.
struct ActivityLabel: Identifiable, Hashable {
    let id:        UUID
    let name:      String
    let createdAt: Date
}
