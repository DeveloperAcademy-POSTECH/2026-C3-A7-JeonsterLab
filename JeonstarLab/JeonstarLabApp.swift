//
//  Wrist_MotionApp.swift
//  Wrist Motion
//
//  Created by Seungjun Lee on 5/18/26.
//

import SwiftUI
import SwiftData

@MainActor
final class PhoneAppRuntime {

    // MARK: - SwiftData 컨테이너

    let container: ModelContainer
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([RecordingEntity.self])
        var isPreview = false
        #if DEBUG && targetEnvironment(simulator)
        isPreview = PhoneUIPreviewData.isEnabled
        #endif
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isPreview)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - DI 구성

    private let sessionManager:  WatchSessionManager
    private let repository:      RecordingRepository
    private let importUseCase:   ImportRecordingUseCase
    private let fileReceiver:    FileReceiveService

    let listViewModel: RecordingListViewModel
    let watchControlVM: WatchControlViewModel
    var onImportError: ((String) -> Void)?

    @MainActor
    init() throws {
        let container = try Self.makeContainer()
        self.container = container
        let sm        = WatchSessionManager()
        let fileStore: RecordingFileStoreProtocol
        #if DEBUG && targetEnvironment(simulator)
        fileStore = PhoneUIPreviewData.isEnabled ? PhoneUIPreviewFileStore() : RecordingFileStore()
        #else
        fileStore = RecordingFileStore()
        #endif
        let repo      = RecordingRepository(
            modelContext: ModelContext(container),
            fileStore:    fileStore
        )
        let importUC  = ImportRecordingUseCase(repository: repo)
        #if DEBUG && targetEnvironment(simulator)
        if PhoneUIPreviewData.isEnabled {
            do { try PhoneUIPreviewData.seed(repo) }
            catch { assertionFailure("UI fixture failed: \(error)") }
        }
        #endif
        let receiver  = FileReceiveService(importUseCase: importUC, sessionManager: sm)
        let listVM    = RecordingListViewModel(repository: repo)

        // WCSession 파일 수신 → FileReceiveService 연결
        sm.onFileReceived = { file, metadata in
            receiver.handle(file: file, metadata: metadata)
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
        listViewModel = listVM
        watchControlVM = WatchControlViewModel(sessionManager: sm)
        sm.onFileReceiveError = { [weak self] message in self?.onImportError?(message) }
    }

    func retryImports() { fileReceiver.retryPending() }
}

@main
struct Wrist_MotionApp: App {
    var body: some Scene {
        WindowGroup {
            PhoneStartupView()
        }
    }
}

private struct PhoneStartupView: View {
    @State private var runtime: PhoneAppRuntime?
    @State private var startupError: String?
    @State private var importError: String?

    var body: some View {
        Group {
            if let runtime {
                ContentView(viewModel: runtime.listViewModel, watchControlVM: runtime.watchControlVM)
                    .modelContainer(runtime.container)
            } else if let startupError {
                ContentUnavailableView {
                    Label("Unable to Open Recordings", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved files have not been deleted. Free some storage if needed, then retry.\n\(startupError)")
                } actions: {
                    Button("Retry", action: load)
                }
            } else { ProgressView("Opening Recordings") }
        }
        .task { if runtime == nil { load() } }
        .alert("Recording Not Imported", isPresented: Binding(
            get: { importError != nil }, set: { if !$0 { importError = nil } }
        )) {
            Button("Retry") { runtime?.retryImports() }
            Button("Later", role: .cancel) {}
        } message: { Text(importError ?? "") }
    }

    private func load() {
        do {
            let ready = try PhoneAppRuntime()
            ready.onImportError = { importError = $0 }
            runtime = ready
            startupError = nil
            ready.retryImports()
        } catch { startupError = error.localizedDescription }
    }
}
