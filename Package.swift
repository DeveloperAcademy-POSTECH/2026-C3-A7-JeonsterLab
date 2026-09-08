// swift-tools-version: 6.2
import PackageDescription
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let selectedServices = ["ReceivedRecordingPackageLoader.swift", "RecordingMetadataJSONParser.swift",
                        "SnapAnalysisJSONParser.swift", "ReceiverProjectPackageService.swift"]
func excludingChildren(_ directory: String, keeping: [String]) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(directory).path)) ?? [])
        .filter { !$0.hasPrefix(".") && !keeping.contains($0) }
        .map { directory.isEmpty ? $0 : directory + "/" + $0 }
}
let excluded = excludingChildren("", keeping: ["JeonstarLab Mac", "Tests", "Package.swift", "Package.resolved"])
    + excludingChildren("JeonstarLab Mac", keeping: ["Models", "Services"])
    + excludingChildren("JeonstarLab Mac/Services", keeping: selectedServices)
    + excludingChildren("Tests", keeping: ["ProjectSettingsSmokeTests.swift"])

// Native regression harness. The application links the same pinned package in Xcode.
let package = Package(
    name: "WatchMotionRegression",
    platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .executableTarget(
            name: "ProjectSettingsSmoke",
            dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")],
            path: ".",
            exclude: excluded,
            sources: [
                "JeonstarLab Mac/Models",
                "JeonstarLab Mac/Services/ReceivedRecordingPackageLoader.swift",
                "JeonstarLab Mac/Services/RecordingMetadataJSONParser.swift",
                "JeonstarLab Mac/Services/SnapAnalysisJSONParser.swift",
                "JeonstarLab Mac/Services/ReceiverProjectPackageService.swift",
                "Tests/ProjectSettingsSmokeTests.swift"
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
