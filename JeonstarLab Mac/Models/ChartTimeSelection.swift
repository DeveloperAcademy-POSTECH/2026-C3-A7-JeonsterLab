//
//  ChartTimeSelection.swift
//  JeonstarLab Mac
//

import Foundation

struct ChartTimeSelection: Equatable {
    var startTime: Double
    var endTime: Double

    var normalized: ChartTimeSelection {
        ChartTimeSelection(
            startTime: min(startTime, endTime),
            endTime: max(startTime, endTime)
        )
    }

    var duration: Double {
        normalized.endTime - normalized.startTime
    }

    var isUsable: Bool {
        duration >= 0.02
    }
}
