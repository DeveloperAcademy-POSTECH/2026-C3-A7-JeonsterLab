//
//  MacReceiverProjectWindowView.swift
//  JeonstarLab Mac
//

import SwiftUI

struct MacReceiverProjectWindowView: View {
    @State private var viewModel: MacHomeViewModel

    init(request: ReceiverProjectWindowRequest) {
        _viewModel = State(initialValue: MacHomeViewModel(workspace: request.makeWorkspace()))
    }

    var body: some View {
        MacHomeView(viewModel: viewModel)
            .navigationTitle(viewModel.workspaceTitle)
    }
}
