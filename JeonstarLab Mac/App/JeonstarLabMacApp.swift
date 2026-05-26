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
    }
}
