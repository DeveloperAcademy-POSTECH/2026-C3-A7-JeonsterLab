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

        WindowGroup("Receiver Project", for: ReceiverProjectWindowRequest.self) { $request in
            if let request {
                MacReceiverProjectWindowView(request: request)
            } else {
                Text("프로젝트 작업공간을 열 수 없습니다.")
                    .frame(minWidth: 680, minHeight: 480)
            }
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
