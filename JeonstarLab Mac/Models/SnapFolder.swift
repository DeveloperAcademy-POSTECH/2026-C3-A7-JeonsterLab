//
//  SnapFolder.swift
//  JeonstarLab Mac
//

import Foundation

struct SnapFolder: Identifiable, Codable, Equatable {
    let folderID: UUID
    var id: UUID { folderID }

    var name: String
    let createdAt: Date
    var updatedAt: Date
    var items: [SnapFolderItem]

    init(
        folderID: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [SnapFolderItem] = []
    ) {
        self.folderID = folderID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }
}
