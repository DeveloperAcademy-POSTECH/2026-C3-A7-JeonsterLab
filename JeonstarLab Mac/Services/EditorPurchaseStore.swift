import Foundation
import StoreKit
import Security
import SwiftUI

@MainActor @Observable
final class EditorPurchaseStore {
    static let shared = EditorPurchaseStore()
    static let productID = "com.Jeonster.WatchMotionEditor.mac.full-unlock"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isChecking = true
    private(set) var isBusy = false
    private(set) var trial = EditorTrial()
    private(set) var storageAvailable = true
    var message: String?
    var reason = String(localized: "Try one workspace, three recordings and one dataset export for free.")
    private var updates: Task<Void, Never>?
    private var exportInProgress = false
    private let service = "com.Jeonster.WatchMotionEditor.mac.trial.v1"

    init() {
        do {
            if let data = try readTrial() { trial = try JSONDecoder().decode(EditorTrial.self, from: data) }
        } catch {
            storageAvailable = false
            message = String(localized: "Trial history could not be read. Unlock or restore your purchase to continue editing.")
        }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                await self.refreshEntitlements()
                await transaction.finish()
            }
        }
        Task { await refreshEntitlements(); await loadProduct() }
    }

    func refreshEntitlements() async {
        var entitled = false
        // StoreKit supplies verified, locally cached transactions while offline.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil, !transaction.isUpgraded {
                entitled = true
            }
        }
        isUnlocked = entitled
        isChecking = false
    }

    func loadProduct() async {
        message = nil
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil { message = String(localized: "Purchases are currently unavailable. Please try again later.") }
        } catch { message = String(localized: "Unable to load the price. Check your connection and try again.") }
    }

    func purchase() async {
        guard !isBusy, let product else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = String(localized: "The purchase could not be verified. Please restore purchases or try again.")
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
            case .pending:
                message = String(localized: "Purchase awaiting approval. Access will unlock once approved.")
            case .userCancelled: break
            @unknown default:
                message = String(localized: "Purchase not completed. Please try again.")
            }
        } catch { message = String(localized: "Purchase failed. You can try again or restore a previous purchase.") }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isUnlocked ? String(localized: "Purchase restored.") : String(localized: "No Full Unlock purchase was found for this Apple Account.")
        } catch { message = String(localized: "Unable to restore purchases. Please try again.") }
    }

    func present(_ reason: String) {
        self.reason = reason
        NotificationCenter.default.post(name: .showEditorPurchase, object: nil)
    }

    func admit(workspace: String, recordings: Set<String>) -> Bool {
        if isUnlocked { return true }
        guard !isChecking, storageAvailable else {
            present(String(localized: "Unlock or restore your purchase to continue.")); return false
        }
        guard trial.permits(workspace: workspace, recordings: recordings) else {
            present(trial.workspaceID != nil && trial.workspaceID != workspace
                ? String(localized: "Your free trial includes one workspace. Unlock to edit another project.")
                : String(localized: "Your free trial includes three recordings. Unlock to edit more."))
            return false
        }
        var next = trial
        next.admit(workspace: workspace, recordings: recordings)
        return persist(next)
    }

    func canEdit(workspace: String, recording: String) -> Bool {
        isUnlocked || (storageAvailable && trial.workspaceID == workspace && trial.recordingIDs.contains(recording))
    }

    func beginExport(workspace: String, recordings: Set<String>) -> Bool {
        guard !exportInProgress else { return false }
        guard isUnlocked || trial.canExport else {
            present(String(localized: "Your free export is complete. Unlock to export another dataset.")); return false
        }
        guard admit(workspace: workspace, recordings: recordings) else { return false }
        exportInProgress = true
        return true
    }

    func endExport(succeeded: Bool) {
        guard exportInProgress else { return }
        exportInProgress = false
        if succeeded && !isUnlocked {
            var next = trial
            next.finishExport(succeeded: true)
            _ = persist(next)
        }
    }

    private func persist(_ next: EditorTrial) -> Bool {
        do {
            let data = try JSONEncoder().encode(next)
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: "usage"]
            var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = data
                item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                status = SecItemAdd(item as CFDictionary, nil)
            }
            guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
            trial = next
            return true
        } catch {
            trial = next // Do not grant another export in this session if persistence failed.
            storageAvailable = false
            message = String(localized: "Trial history could not be saved. Your recordings are safe. Restore or unlock to continue.")
            present(String(localized: "Trial storage is unavailable."))
            return false
        }
    }

    private func readTrial() throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "usage",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return result as? Data
    }

    static func workspaceID(recordingsRoot: URL) -> String {
        let manifestURL = recordingsRoot.deletingLastPathComponent().appendingPathComponent("project_manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return EditorTrial.localWorkspaceID }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ReceiverProjectManifest.self, from: data))?.packageID.uuidString
            ?? recordingsRoot.standardizedFileURL.path
    }
}

extension Notification.Name {
    static let showEditorPurchase = Notification.Name("WatchMotionEditor.showPurchase")
}

extension ReceivedRecordingPackage {
    var trialRecordingID: String {
        (metadata?.recordingID ?? snapAnalysis?.recordingID)?.uuidString ?? folderURL.lastPathComponent
    }
}

private struct TrialWorkspaceKey: EnvironmentKey { static let defaultValue = "00000000-0000-0000-0000-000000000001" }
extension EnvironmentValues {
    var trialWorkspaceID: String {
        get { self[TrialWorkspaceKey.self] }
        set { self[TrialWorkspaceKey.self] = newValue }
    }
}
