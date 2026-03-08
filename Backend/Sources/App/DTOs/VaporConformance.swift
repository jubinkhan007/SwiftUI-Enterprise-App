import SharedModels
import Vapor

// MARK: - Vapor Content Conformance

/// Make SharedModels DTOs usable as Vapor response bodies.
extension APIResponse: AsyncRequestDecodable where T: Content {}
extension APIResponse: AsyncResponseEncodable where T: Content {}
extension APIResponse: RequestDecodable where T: Content {}
extension APIResponse: ResponseEncodable where T: Content {}
extension APIResponse: Content where T: Content {}

extension UserDTO: Content {}
extension TaskItemDTO: Content {}
extension TaskActivityDTO: Content {}
extension AuthResponse: Content {}
extension TokenRefreshResponse: Content {}
extension CreateTaskRequest: Content {}
extension UpdateTaskRequest: Content {}
extension RegisterRequest: Content {}
extension LoginRequest: Content {}
extension EmptyResponse: Content {}

// Organization types
extension SpaceDTO: Content {}
extension ProjectDTO: Content {}
extension TaskListDTO: Content {}
extension HierarchyTreeDTO: Content {}
extension HierarchyTreeDTO.SpaceNode: Content {}
extension HierarchyTreeDTO.ProjectNode: Content {}
extension OrganizationDTO: Content {}
extension OrganizationMemberDTO: Content {}
extension OrganizationInviteDTO: Content {}
extension PendingInviteDTO: Content {}
extension MeResponse: Content {}
extension CreateOrganizationRequest: Content {}
extension CreateInviteRequest: Content {}
extension UpdateMemberRoleRequest: Content {}
extension AuditLogDTO: Content {}

// Phase 8 types
extension TaskRelationDTO: Content {}
extension ChecklistItemDTO: Content {}
extension CreateRelationRequest: Content {}
extension CreateChecklistItemRequest: Content {}
extension UpdateChecklistItemRequest: Content {}
extension ReorderChecklistRequest: Content {}

// View Config types
extension ViewConfigDTO: Content {}
extension CreateViewConfigRequest: Content {}
extension UpdateViewConfigRequest: Content {}

// Calendar / Timeline types
extension TimelineResponseDTO: Content {}

// Phase 10: Workflow & Automation
extension WorkflowBundleDTO: Content {}
extension WorkflowStatusDTO: Content {}
extension CreateWorkflowStatusRequest: Content {}
extension UpdateWorkflowStatusRequest: Content {}
extension AutomationRuleDTO: Content {}
extension CreateAutomationRuleRequest: Content {}
extension UpdateAutomationRuleRequest: Content {}

// Phase 11: Collaboration
extension CommentDTO: Content {}
extension AttachmentDTO: Content {}
extension NotificationDTO: Content {}
extension CreateCommentRequest: Content {}

// Phase 12: Analytics
extension SprintDTO: Content {}
extension CreateSprintRequest: Content {}
extension ProjectDailyStatsDTO: Content {}
extension WeeklyThroughputPointDTO: Content {}
extension SprintVelocityPointDTO: Content {}
extension AnalyticsReportPayloadDTO: Content {}
extension AnalyticsResponseDTO: AsyncRequestDecodable where T: Content {}
extension AnalyticsResponseDTO: AsyncResponseEncodable where T: Content {}
extension AnalyticsResponseDTO: RequestDecodable where T: Content {}
extension AnalyticsResponseDTO: ResponseEncodable where T: Content {}
extension AnalyticsResponseDTO: Content where T: Content {}

// Phase 13: Releases
extension ReleaseDTO: Content {}
extension CreateReleaseRequest: Content {}
extension ReleaseProgressDTO: Content {}
extension FinalizeReleaseRequest: Content {}

// Phase 16: Integrations
extension APIKeyDTO: Content {}
extension CreateAPIKeyRequest: Content {}
extension CreateAPIKeyResponse: Content {}
extension WebhookSubscriptionDTO: Content {}
extension CreateWebhookSubscriptionRequest: Content {}
extension WebhookTestResponse: Content {}
