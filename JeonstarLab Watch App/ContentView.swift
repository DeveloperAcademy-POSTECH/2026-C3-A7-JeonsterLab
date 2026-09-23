//
//  ContentView.swift
//  Wrist Motion Watch Watch App
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct ContentView: View {

    @State var viewModel: RecordingViewModel
    var storage: WatchRecordingStorage

    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if WatchUIPreview.isEnabled {
            WatchUIPreview()
        } else {
            RecordingView(viewModel: viewModel, storage: storage)
        }
        #else
        RecordingView(viewModel: viewModel, storage: storage)
        #endif
    }
}
