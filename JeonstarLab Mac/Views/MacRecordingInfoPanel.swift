//
//  MacRecordingInfoPanel.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacRecordingInfoPanel: View {
    let package: ReceivedRecordingPackage

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                Text("Recorded")
                Text(package.recordingDateText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Received")
                Text(package.receivedAtText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Duration")
                Text(package.durationText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Samples")
                Text(package.sampleCountText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Snap Events")
                Text(package.snapEventCountText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Detection Mode")
                Text(package.snapDetectionMode.displayName)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("File Status")
                Text(package.completenessText)
                    .foregroundStyle(package.isComplete ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
            }
        }
        .font(.body)
    }
}
