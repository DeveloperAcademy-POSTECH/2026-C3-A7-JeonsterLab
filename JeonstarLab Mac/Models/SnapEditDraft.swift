//
//  SnapEditDraft.swift
//  JeonstarLab Mac
//

import Foundation

struct SnapEditDraft: Equatable {
    let originalEvent: WorkingSnapEvent

    var snapID: String { originalEvent.snapID }
    var originalSelection: ChartTimeSelection? {
        guard let startTime = originalEvent.startTime,
              let endTime = originalEvent.endTime else {
            return nil
        }
        return ChartTimeSelection(startTime: startTime, endTime: endTime).normalized
    }
}
