//
//  MacReceivedItem.swift
//  JeonstarLab Mac
//

import Foundation

struct MacReceivedItem: Identifiable, Hashable {
    let id = UUID()
    let fileName: String
    let receivedAt: Date
}
