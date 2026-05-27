//
//  MacReceivedItem.swift
//  JeonstarLab Mac
//

import Foundation

struct MacReceivedItem: Identifiable, Hashable {
    let id = UUID()
    let fileName: String
    let receivedAt: Date
    let savedFileURL: URL

    var folderPath: String {
        savedFileURL.deletingLastPathComponent().path
    }
}
