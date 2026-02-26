import Fluent
import SharedModels
import Vapor

/// Database model for a saved view configuration.
/// Scoped to an organization, but can be applied to smaller scopes (space, project, list).
final class ViewConfigModel: Model, @unchecked Sendable {
    static let schema = "view_configs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "name")
    var name: String

    @Enum(key: "type")
    var type: ViewType

    @OptionalField(key: "filters_json")
    var filtersJson: String?

    @OptionalField(key: "sorts_json")
    var sortsJson: String?

    @Field(key: "schema_version")
    var schemaVersion: Int

    @Enum(key: "applies_to")
    var appliesTo: ViewScope

    @Field(key: "scope_id")
    var scopeId: UUID

    @OptionalField(key: "owner_user_id")
    var ownerUserId: UUID?

    @Field(key: "is_public")
    var isPublic: Bool

    @Field(key: "is_default")
    var isDefault: Bool

    // We store arrays and complex types as JSON strings or raw Data in SQLite/Postgres.
    // For simplicity with Fluent, we use Data/String mapping.
    @OptionalField(key: "visible_columns_json")
    var visibleColumnsJson: String?

    @OptionalField(key: "board_config_json")
    var boardConfigJson: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        name: String,
        type: ViewType,
        filtersJson: String? = nil,
        sortsJson: String? = nil,
        schemaVersion: Int = 1,
        appliesTo: ViewScope,
        scopeId: UUID,
        ownerUserId: UUID? = nil,
        isPublic: Bool = false,
        isDefault: Bool = false,
        visibleColumnsJson: String? = nil,
        boardConfigJson: String? = nil
    ) {
        self.id = id
        self.$organization.id = orgId
        self.name = name
        self.type = type
        self.filtersJson = filtersJson
        self.sortsJson = sortsJson
        self.schemaVersion = schemaVersion
        self.appliesTo = appliesTo
        self.scopeId = scopeId
        self.ownerUserId = ownerUserId
        self.isPublic = isPublic
        self.isDefault = isDefault
        self.visibleColumnsJson = visibleColumnsJson
        self.boardConfigJson = boardConfigJson
    }

    func toDTO() throws -> ViewConfigDTO {
        var visibleColumns: [String]? = nil
        if let json = visibleColumnsJson, let data = json.data(using: .utf8) {
            visibleColumns = try? JSONDecoder().decode([String].self, from: data)
        }

        var boardConfig: BoardColumnConfigDTO? = nil
        if let json = boardConfigJson, let data = json.data(using: .utf8) {
            boardConfig = try? JSONDecoder().decode(BoardColumnConfigDTO.self, from: data)
        }

        return ViewConfigDTO(
            id: try requireID(),
            name: name,
            type: type,
            filtersJson: filtersJson,
            sortsJson: sortsJson,
            schemaVersion: schemaVersion,
            appliesTo: appliesTo,
            scopeId: scopeId,
            ownerUserId: ownerUserId,
            isPublic: isPublic,
            isDefault: isDefault,
            visibleColumns: visibleColumns,
            boardConfig: boardConfig,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
