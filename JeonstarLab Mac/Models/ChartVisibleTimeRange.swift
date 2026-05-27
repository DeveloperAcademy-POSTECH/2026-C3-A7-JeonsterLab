//
//  ChartVisibleTimeRange.swift
//  JeonstarLab Mac
//

import Foundation

struct ChartVisibleTimeRange: Equatable {
    var lowerBound: Double
    var upperBound: Double

    var duration: Double {
        upperBound - lowerBound
    }

    var range: ClosedRange<Double> {
        lowerBound...upperBound
    }

    static func full(_ fullRange: ClosedRange<Double>) -> ChartVisibleTimeRange {
        ChartVisibleTimeRange(
            lowerBound: fullRange.lowerBound,
            upperBound: fullRange.upperBound
        )
    }

    func clamped(
        to fullRange: ClosedRange<Double>,
        minimumDuration: Double
    ) -> ChartVisibleTimeRange {
        let fullDuration = max(0, fullRange.upperBound - fullRange.lowerBound)
        guard fullDuration > 0 else {
            return .full(fullRange)
        }

        let minDuration = min(max(0, minimumDuration), fullDuration)
        let requestedDuration = min(max(duration, minDuration), fullDuration)
        let center = (lowerBound + upperBound) / 2
        var lower = center - requestedDuration / 2
        var upper = center + requestedDuration / 2

        if lower < fullRange.lowerBound {
            lower = fullRange.lowerBound
            upper = lower + requestedDuration
        }

        if upper > fullRange.upperBound {
            upper = fullRange.upperBound
            lower = upper - requestedDuration
        }

        return ChartVisibleTimeRange(lowerBound: lower, upperBound: upper)
    }

    func zoomed(
        scale: Double,
        anchorTime: Double?,
        fullRange: ClosedRange<Double>,
        minimumDuration: Double
    ) -> ChartVisibleTimeRange {
        let fullDuration = max(0, fullRange.upperBound - fullRange.lowerBound)
        guard fullDuration > 0, duration > 0, scale > 0 else {
            return .full(fullRange)
        }

        let minDuration = min(max(0, minimumDuration), fullDuration)
        let nextDuration = min(max(duration / scale, minDuration), fullDuration)
        let anchor = min(max(anchorTime ?? (lowerBound + upperBound) / 2, lowerBound), upperBound)
        let anchorRatio = duration > 0 ? (anchor - lowerBound) / duration : 0.5
        let lower = anchor - nextDuration * anchorRatio
        let upper = lower + nextDuration

        return ChartVisibleTimeRange(
            lowerBound: lower,
            upperBound: upper
        )
        .clamped(to: fullRange, minimumDuration: minDuration)
    }

    func panned(
        by delta: Double,
        fullRange: ClosedRange<Double>,
        minimumDuration: Double
    ) -> ChartVisibleTimeRange {
        ChartVisibleTimeRange(
            lowerBound: lowerBound + delta,
            upperBound: upperBound + delta
        )
        .clamped(to: fullRange, minimumDuration: minimumDuration)
    }
}
