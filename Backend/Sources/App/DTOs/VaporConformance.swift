import SharedModels
import Vapor

// MARK: - Vapor Content Conformance

/// Make SharedModels DTOs usable as Vapor response bodies.
/// Using @retroactive since these types are defined in SharedModels.
extension APIResponse: @retroactive AsyncRequestDecodable where T: Content {}
extension APIResponse: @retroactive AsyncResponseEncodable where T: Content {}
extension APIResponse: @retroactive RequestDecodable where T: Content {}
extension APIResponse: @retroactive ResponseEncodable where T: Content {}
extension APIResponse: @retroactive Content where T: Content {}

extension UserDTO: @retroactive Content {}
extension TaskItemDTO: @retroactive Content {}
extension TaskActivityDTO: @retroactive Content {}
extension AuthResponse: @retroactive Content {}
extension TokenRefreshResponse: @retroactive Content {}
extension CreateTaskRequest: @retroactive Content {}
extension UpdateTaskRequest: @retroactive Content {}
extension RegisterRequest: @retroactive Content {}
extension LoginRequest: @retroactive Content {}

// Organization types
extension SpaceDTO: @retroactive Content {}
extension ProjectDTO: @retroactive Content {}
extension TaskListDTO: @retroactive Content {}
extension HierarchyTreeDTO: @retroactive Content {}
extension HierarchyTreeDTO.SpaceNode: @retroactive Content {}
extension HierarchyTreeDTO.ProjectNode: @retroactive Content {}
extension OrganizationDTO: @retroactive Content {}
extension OrganizationMemberDTO: @retroactive Content {}
extension OrganizationInviteDTO: @retroactive Content {}
extension PendingInviteDTO: @retroactive Content {}
extension MeResponse: @retroactive Content {}
extension CreateOrganizationRequest: @retroactive Content {}
extension CreateInviteRequest: @retroactive Content {}
extension UpdateMemberRoleRequest: @retroactive Content {}
extension AuditLogDTO: @retroactive Content {}

// Phase 8 types
extension TaskRelationDTO: @retroactive Content {}
extension ChecklistItemDTO: @retroactive Content {}
extension CreateRelationRequest: @retroactive Content {}
extension CreateChecklistItemRequest: @retroactive Content {}
extension UpdateChecklistItemRequest: @retroactive Content {}
extension ReorderChecklistRequest: @retroactive Content {}

// View Config types
extension ViewConfigDTO: @retroactive Content {}
extension CreateViewConfigRequest: @retroactive Content {}
extension UpdateViewConfigRequest: @retroactive Content {}

// Calendar / Timeline types
extension TimelineResponseDTO: @retroactive Content {}

// Phase 10: Workflow & Automation
extension WorkflowBundleDTO: @retroactive Content {}
extension WorkflowStatusDTO: @retroactive Content {}
extension CreateWorkflowStatusRequest: @retroactive Content {}
extension UpdateWorkflowStatusRequest: @retroactive Content {}
extension AutomationRuleDTO: @retroactive Content {}
extension CreateAutomationRuleRequest: @retroactive Content {}
extension UpdateAutomationRuleRequest: @retroactive Content {}

// Phase 11: Collaboration
extension CommentDTO: @retroactive Content {}
extension AttachmentDTO: @retroactive Content {}
extension NotificationDTO: @retroactive Content {}
extension CreateCommentRequest: @retroactive Content {}
