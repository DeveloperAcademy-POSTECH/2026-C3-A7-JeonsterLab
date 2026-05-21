//
//  ActivityLabelEntity.swift
//  JeonstarLab
//
//  Created by Seungjun Lee on 5/21/26.
//

import Foundation
import SwiftData

@Model
final class ActivityLabelEntity {
    @Attribute(.unique) var id: UUID
    var name:      String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id        = id
        self.name      = name
        self.createdAt = createdAt
    }

    var asActivityLabel: ActivityLabel {
        ActivityLabel(id: id, name: name, createdAt: createdAt)
    }
}
