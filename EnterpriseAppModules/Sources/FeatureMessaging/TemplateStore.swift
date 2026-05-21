import Foundation
import Combine
import Domain
import SharedModels

@MainActor
public final class TemplateStore: ObservableObject {
    public static let shared = TemplateStore()

    @Published public private(set) var templates: [MessageTemplateDTO] = []
    @Published public var lastError: Error?
    @Published public var isLoading: Bool = false

    private var repository: ProductivityRepositoryProtocol?
    private var currentUserName: String = ""
    private var currentUserEmail: String = ""
    private var currentOrgName: String = ""

    private init() {}

    public func configure(
        repository: ProductivityRepositoryProtocol,
        currentUserName: String,
        currentUserEmail: String,
        currentOrgName: String
    ) {
        self.repository = repository
        self.currentUserName = currentUserName
        self.currentUserEmail = currentUserEmail
        self.currentOrgName = currentOrgName
    }

    public func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repository.listTemplates(scope: "all")
            templates = response.data ?? []
        } catch { lastError = error }
    }

    public func create(scope: TemplateScope, name: String, shortcut: String?, body: String) async -> MessageTemplateDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.createTemplate(CreateTemplateRequest(scope: scope, name: name, shortcut: shortcut, body: body))
            if let dto = response.data {
                templates.append(dto)
                templates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return dto
            }
        } catch { lastError = error }
        return nil
    }

    public func update(id: UUID, name: String?, shortcut: String?, body: String?) async -> MessageTemplateDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.updateTemplate(id: id, request: UpdateTemplateRequest(name: name, shortcut: shortcut, body: body))
            if let dto = response.data {
                if let idx = templates.firstIndex(where: { $0.id == id }) {
                    templates[idx] = dto
                }
                return dto
            }
        } catch { lastError = error }
        return nil
    }

    public func delete(_ id: UUID) async {
        guard let repository else { return }
        let prev = templates
        templates.removeAll { $0.id == id }
        do { _ = try await repository.deleteTemplate(id: id) }
        catch {
            templates = prev
            lastError = error
        }
    }

    /// Server-authoritative render — preferred when online.
    public func render(_ template: MessageTemplateDTO, conversationId: UUID? = nil) async -> String {
        guard let repository else { return template.body }
        do {
            let response = try await repository.renderTemplate(id: template.id, request: RenderTemplateRequest(conversationId: conversationId))
            return response.data?.body ?? template.body
        } catch {
            return renderLocal(template)
        }
    }

    /// Best-effort client-side substitution, used as a fallback when offline.
    public func renderLocal(_ template: MessageTemplateDTO) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        let tf = DateFormatter(); tf.dateStyle = .none; tf.timeStyle = .short
        let now = Date()
        var out = template.body
        let mappings: [String: String] = [
            "{{user.name}}": currentUserName,
            "{{user.email}}": currentUserEmail,
            "{{org.name}}": currentOrgName,
            "{{date}}": df.string(from: now),
            "{{time}}": tf.string(from: now)
        ]
        for (k, v) in mappings { out = out.replacingOccurrences(of: k, with: v) }
        return out
    }

    public func findByShortcut(_ shortcut: String) -> MessageTemplateDTO? {
        let target = shortcut.lowercased()
        return templates.first { ($0.shortcut?.lowercased() ?? "") == target }
    }
}
