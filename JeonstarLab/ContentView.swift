//
//  ContentView.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI

struct ContentView: View {

    @State var viewModel:      RecordingListViewModel
    @State var watchControlVM: WatchControlViewModel

    var body: some View {
        NavigationStack {
            RecordingListView(viewModel: viewModel, watchControlVM: watchControlVM)
        }
    }
}
