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
                Text("녹화 시각")
                Text(package.recordingDateText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("수신 시각")
                Text(package.receivedAtText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("길이")
                Text(package.durationText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("샘플")
                Text(package.sampleCountText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("스냅 이벤트")
                Text(package.snapEventCountText)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("파일 상태")
                Text(package.completenessText)
                    .foregroundStyle(package.isComplete ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
            }
        }
        .font(.body)
    }
}
