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
        RecordingView(viewModel: viewModel, storage: storage)
    }
}
