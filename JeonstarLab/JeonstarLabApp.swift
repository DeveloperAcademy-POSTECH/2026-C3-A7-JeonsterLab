//
//  Wrist_MotionApp.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI
import SwiftData

@main
struct Wrist_MotionApp: App {

    // MARK: - SwiftData 컨테이너

    private let container: ModelContainer = {
        let schema = Schema([RecordingEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    // MARK: - DI 구성

    private let sessionManager:  WatchSessionManager
    private let repository:      RecordingRepository
    private let importUseCase:   ImportRecordingUseCase
    private let fileReceiver:    FileReceiveService

    @State private var listViewModel:    RecordingListViewModel
    @State private var watchControlVM:   WatchControlViewModel

    @MainActor
    init() {
        let sm        = WatchSessionManager()
        let fileStore = RecordingFileStore()
        let repo      = RecordingRepository(
            modelContext: ModelContext(container),
            fileStore:    fileStore
        )
        let importUC  = ImportRecordingUseCase(repository: repo)
        let receiver  = FileReceiveService(importUseCase: importUC, sessionManager: sm)
        let listVM    = RecordingListViewModel(repository: repo)

        // WCSession 파일 수신 → FileReceiveService 연결
        sm.onFileReceived = { file in
            Task { @MainActor in receiver.handle(file: file) }
        }

        // 녹화 저장 완료 → 목록 자동 갱신
        importUC.onRecordingSaved = { [listVM, repo] session in
            Task { @MainActor in listVM.load() }
            Task { @MainActor in
                MacConnectionViewModel.shared.sendRecordingIfAutomaticTransferEnabled(
                    session: session,
                    repository: repo
                )
            }
        }

        sessionManager  = sm
        repository      = repo
        importUseCase   = importUC
        fileReceiver    = receiver
        _listViewModel    = State(wrappedValue: listVM)
        _watchControlVM   = State(wrappedValue: WatchControlViewModel(sessionManager: sm))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: listViewModel, watchControlVM: watchControlVM)
        }
        .modelContainer(container)
    }
}
