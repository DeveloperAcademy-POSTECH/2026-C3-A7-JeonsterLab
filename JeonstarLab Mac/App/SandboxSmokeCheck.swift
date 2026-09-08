#if DEBUG
import Foundation

/// Runs only when explicitly requested against disposable files in this app's container.
enum SandboxSmokeCheck {
    static func run() -> Bool {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("sandbox-check-\(UUID())")
            let recordings = root.appendingPathComponent("recordings")
            let fixture = recordings.appendingPathComponent("fixture")
            try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
            try Data("timestamp,userAccX\n1,0".utf8).write(to: fixture.appendingPathComponent("recording.csv"))
            let result = try { () throws -> String in
                let archive = root.appendingPathComponent("test.watchmotion")
                _ = try ReceiverProjectPackageService.exportProject(recordingsRootURL: recordings,
                    foldersRootURL: recordings, workspaceName: "Sandbox Check", folders: [], outputURL: archive)
                let opened = try ReceiverProjectPackageService.openProjectWorkspace(packageURL: archive,
                    projectsRootURL: root.appendingPathComponent("opened"))
                let content = try String(contentsOf: opened.recordingsRootURL.appendingPathComponent("fixture/recording.csv"), encoding: .utf8)
                guard content == "timestamp,userAccX\n1,0" else { throw CocoaError(.fileReadCorruptFile) }
                return root.path
            }()
            print("SANDBOX_SMOKE_PASS \(result)")
            return true
        } catch { print("SANDBOX_SMOKE_FAIL \(error)"); return false }
    }
}
#endif
