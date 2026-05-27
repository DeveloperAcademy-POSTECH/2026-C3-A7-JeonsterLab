//
//  JeonstarLabMacApp.swift
//  JeonstarLab Mac
//

import SwiftUI

@main
struct JeonstarLabMacApp: App {
    @State private var viewModel = MacHomeViewModel()

    var body: some Scene {
        WindowGroup {
            MacHomeView(viewModel: viewModel)
        }

        WindowGroup("Recording Detail", for: String.self) { $packagePath in
            if let packagePath {
                MacRecordingDetailWindowView(packagePath: packagePath)
            } else {
                Text("녹화 기록을 열 수 없습니다.")
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
    }
}
