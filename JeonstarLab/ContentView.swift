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
    @AppStorage("WatchMotionEditor.hasSeenPhoneTutorial.v1") private var hasSeenTutorial = false
    @State private var showsTutorial = false

    var body: some View {
        NavigationStack {
            RecordingListView(viewModel: viewModel, watchControlVM: watchControlVM)
        }
        .mobileEditorStyle()
        .sheet(isPresented: $showsTutorial) {
            GettingStartedGuideView(audience: .phone) { showsTutorial = false }
                .mobileEditorStyle()
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-tutorial") {
                showsTutorial = true
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-preview") { return }
            #endif
            if !hasSeenTutorial {
                hasSeenTutorial = true
                showsTutorial = true
            }
        }
    }
}
