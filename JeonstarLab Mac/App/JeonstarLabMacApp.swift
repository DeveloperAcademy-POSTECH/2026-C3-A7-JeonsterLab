//
//  JeonstarLabMacApp.swift
//  JeonstarLab Mac
//

import SwiftUI

@main
struct JeonstarLabMacApp: App {
    @State private var viewModel = MacHomeViewModel()

    var body: some Scene {
        WindowGroup("WatchMotion Editor") {
            MacHomeView(viewModel: viewModel)
        }

        WindowGroup("WatchMotion Editor — Project", for: ReceiverProjectWindowRequest.self) { $request in
            if let request {
                MacReceiverProjectWindowView(request: request)
            } else {
                Text("Unable to open the project workspace.")
                    .frame(minWidth: 680, minHeight: 480)
            }
        }

        WindowGroup("Recording Detail", for: String.self) { $packagePath in
            if let packagePath {
                MacRecordingDetailWindowView(packagePath: packagePath)
            } else {
                Text("Unable to open this recording.")
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
    }
}
