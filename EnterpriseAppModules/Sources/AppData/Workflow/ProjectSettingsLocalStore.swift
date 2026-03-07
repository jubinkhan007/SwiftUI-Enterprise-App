import Foundation
import SharedModels
import AppNetwork

public protocol ProjectSettingsLocalStoreProtocol: Sendable {
    func getWorkflowBundle(orgId: UUID, projectId: UUID) async -> WorkflowBundleDTO?
    func saveWorkflowBundle(orgId: UUID, projectId: UUID, bundle: WorkflowBundleDTO) async
    func invalidateWorkflowBundle(orgId: UUID, projectId: UUID) async
}

public actor ProjectSettingsLocalStore: ProjectSettingsLocalStoreProtocol {
    private let defaults: UserDefaults
    private let keyPrefix = "com.enterprise.workflow.bundle"

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    public func getWorkflowBundle(orgId: UUID, projectId: UUID) async -> WorkflowBundleDTO? {
        guard let data = defaults.data(forKey: key(orgId: orgId, projectId: projectId)) else { return nil }
        return try? JSONCoding.decoder.decode(WorkflowBundleDTO.self, from: data)
    }

    public func saveWorkflowBundle(orgId: UUID, projectId: UUID, bundle: WorkflowBundleDTO) async {
        guard let data = try? JSONCoding.encoder.encode(bundle) else { return }
        defaults.set(data, forKey: key(orgId: orgId, projectId: projectId))
    }

    public func invalidateWorkflowBundle(orgId: UUID, projectId: UUID) async {
        defaults.removeObject(forKey: key(orgId: orgId, projectId: projectId))
    }

    private func key(orgId: UUID, projectId: UUID) -> String {
        "\(keyPrefix).\(orgId.uuidString).\(projectId.uuidString)"
    }
}
