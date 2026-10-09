export type TaskStatus = 'todo' | 'in_progress' | 'in_review' | 'review' | 'done' | 'cancelled' | (string & {});
export type TaskPriority = 'critical' | 'urgent' | 'high' | 'medium' | 'low';
export type TaskType = 'task' | 'bug' | 'story' | 'epic';

export interface UserDTO {
  id: string;
  email: string;
  displayName: string;
  role?: string;
  createdAt?: string;
  updatedAt?: string;
  isSuperAdmin?: boolean;
}

export interface AuthResponse {
  token: string;
  user: UserDTO;
}

export interface TaskItemDTO {
  id: string;
  orgId?: string;
  listId?: string;
  projectId?: string;
  title: string;
  description?: string;
  status: TaskStatus;
  priority: TaskPriority;
  taskType: TaskType;
  storyPoints?: number;
  issueKey?: string;
  labels?: string[];
  startDate?: string;
  dueDate?: string;
  completedAt?: string;
  assigneeId?: string;
  position?: number;
  version?: number;
  sprintId?: string | null;
  sprintPosition?: number;
  backlogPosition?: number;
  affectedVersionId?: string | null;
}

export interface SpaceDTO {
  id: string;
  name: string;
}

export interface ProjectDTO {
  id: string;
  name: string;
  spaceId: string;
}

export interface TaskListDTO {
  id: string;
  name: string;
  projectId: string;
}

export interface ProjectNodeDTO {
  project: ProjectDTO;
  lists: TaskListDTO[];
}

export interface SpaceNodeDTO {
  space: SpaceDTO;
  projects: ProjectNodeDTO[];
}

export interface HierarchyTreeDTO {
  spaces: SpaceNodeDTO[];
}

export interface NotificationDTO {
  id: string;
  title: string;
  body: string;
  type: string;
  isRead: boolean;
  createdAt: string;
  actorUserId?: string;
  actorName?: string;
  callSessionId?: string;
  payloadJson?: string;
}

export interface OrgMemberDTO {
  id: string;
  userId: string;
  orgId: string;
  role: string;
  displayName: string;
  email: string;
  joinedAt?: string;
}

export interface ConversationDTO {
  id: string;
  type: 'direct' | 'channel' | 'group';
  name?: string;
  description?: string;
  topic?: string;
  isArchived?: boolean;
  isPrivate?: boolean;
  isLocked?: boolean;
  memberCount?: number;
  messageCount?: number;
  unreadCount?: number;
  lastMessageAt?: string;
}

export interface MessageReactionGroupDTO {
  emoji: string;
  count: number;
  userIds: string[];
  didReact: boolean;
}

export interface MessageDTO {
  id: string;
  conversationId: string;
  senderId: string;
  senderDisplayName?: string;
  body: string;
  messageType?: string;
  parentId?: string;
  replyCount?: number;
  threadPreviewText?: string;
  lastReplyAt?: string;
  reactions?: MessageReactionGroupDTO[];
  isPinned?: boolean;
  isBookmarkedByMe?: boolean;
  editedAt?: string;
  deletedAt?: string;
  createdAt?: string;
}

export interface ThreadMessageBundleDTO {
  rootMessage: MessageDTO;
  replies: MessageDTO[];
}

export interface MeetingDTO {
  id: string;
  orgId?: string;
  title: string;
  description?: string;
  scheduledAt: string;
  durationMinutes: number;
  meetingUrl?: string;
  hostId?: string;
}

export interface TimeLogDTO {
  id: string;
  taskId?: string;
  userId: string;
  userDisplayName?: string;
  orgId?: string;
  hoursLogged: number;
  loggedAt: string;
  description?: string;
  createdAt?: string;
}

export interface CallSessionDTO {
  id: string;
  conversationId: string;
  status: string;
}

export interface CallTicketDTO {
  token: string;
  roomName: string;
  session: CallSessionDTO;
}

export interface UserSessionDTO {
  id: string;
  userId: string;
  deviceType: string;
  ipAddress: string;
  userAgent: string;
  isRevoked: boolean;
  expiresAt: string;
  createdAt?: string;
}

export interface OrgInviteDTO {
  id: string;
  orgId: string;
  email: string;
  role: string;
  status: 'pending' | 'accepted' | 'revoked' | 'expired';
  expiresAt?: string;
  createdAt?: string;
}

export interface OrgJoinRequestDTO {
  id: string;
  orgId: string;
  userId: string;
  userDisplayName?: string;
  userEmail?: string;
  message?: string;
  status: 'pending' | 'accepted' | 'rejected';
  createdAt?: string;
}

export interface WorkspaceDTO {
  id: string;
  name: string;
  subscriptionTier?: string;
  memberCount?: number;
  currentUserRole?: string;
}

export interface MeetingActionItemDTO {
  id: string;
  text: string;
  dueAt?: string;
  linkedTaskId?: string;
  isCompleted?: boolean;
}

export interface MeetingSummaryDTO {
  meetingId: string;
  source: string;
  summaryText: string;
  recordingUrl?: string;
  actionItems: MeetingActionItemDTO[];
}

export interface CallParticipantDTO {
  id: string;
  userId: string;
  displayName: string;
  role: string;
  isAudioMuted: boolean;
  isVideoMuted: boolean;
  isScreenSharing: boolean;
  isSpeaking?: boolean;
}

export interface SubtaskDTO {
  id: string;
  taskId: string;
  title: string;
  isCompleted: boolean;
  position?: number;
}

export interface TaskDependencyDTO {
  id: string;
  taskId: string;
  relatedTaskId: string;
  relationType: 'blocked_by' | 'blocking';
  relatedTaskTitle?: string;
  relatedTaskStatus?: TaskStatus;
}

export type BillingTier = 'free' | 'pro' | 'enterprise';

export type SprintStatus = 'planned' | 'active' | 'completed' | 'cancelled' | 'closed';

export interface SprintDTO {
  id: string;
  projectId: string;
  name: string;
  startDate: string;
  endDate: string;
  status: SprintStatus;
  capacity?: number;
}

export interface OrganizationDetailsDTO {
  id: string;
  name: string;
  slug?: string;
  description?: string;
  memberCount?: number;
  subscriptionTier?: string;
  subscriptionStatus?: string;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  createdAt?: string;
}

export interface LogTimeRequest {
  hoursLogged: number;
  loggedAt?: string;
  description?: string;
}

export interface UserTimeReport {
  userId: string;
  userDisplayName: string;
  totalHours: number;
}

export interface TaskTimeReport {
  taskId: string;
  taskTitle: string;
  totalHours: number;
}

export interface ProjectTimeReportDTO {
  projectId: string;
  totalHours: number;
  byUser: UserTimeReport[];
  byTask: TaskTimeReport[];
}

export type ReleaseStatus = 'unreleased' | 'released' | 'archived';

export interface ReleaseDTO {
  id: string;
  projectId: string;
  name: string;
  description?: string;
  releaseDate?: string;
  releasedAt?: string;
  status: ReleaseStatus;
  isLocked: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateReleaseRequest {
  name: string;
  description?: string;
  releaseDate?: string;
}

export interface ReleaseProgressDTO {
  releaseId: string;
  totalIssues: number;
  doneIssues: number;
  remainingIssues: number;
  totalPoints: number;
  donePoints: number;
  bugCount: number;
  criticalBugCount: number;
}

export interface FinalizeReleaseRequest {
  lock?: boolean;
}

export type WorkflowStatusCategory = 'backlog' | 'active' | 'completed' | 'cancelled';

export interface WorkflowStatusDTO {
  id: string;
  projectId: string;
  name: string;
  color: string;
  position: number;
  category: WorkflowStatusCategory;
  isDefault: boolean;
  isFinal: boolean;
  isLocked: boolean;
  legacyStatus?: string | null;
}

export interface CreateWorkflowStatusRequest {
  name: string;
  color?: string;
  position?: number;
  category: WorkflowStatusCategory;
  isDefault?: boolean;
  isFinal?: boolean;
}

export interface UpdateWorkflowStatusRequest {
  name?: string;
  color?: string;
  position?: number;
  category?: WorkflowStatusCategory;
  isDefault?: boolean;
  isFinal?: boolean;
}

export interface AutomationRuleDTO {
  id: string;
  projectId: string;
  name: string;
  isEnabled: boolean;
  triggerType: string;
  triggerConfigJson?: string | null;
  conditionsJson?: string | null;
  actionsJson?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateAutomationRuleRequest {
  name: string;
  isEnabled?: boolean;
  triggerType: string;
  triggerConfigJson?: string | null;
  conditionsJson?: string | null;
  actionsJson?: string | null;
}

export interface UpdateAutomationRuleRequest {
  name?: string;
  isEnabled?: boolean;
  triggerType?: string;
  triggerConfigJson?: string | null;
  conditionsJson?: string | null;
  actionsJson?: string | null;
}

export interface WorkflowBundleDTO {
  projectId: string;
  workflowVersion: number;
  statuses: WorkflowStatusDTO[];
  rules: AutomationRuleDTO[];
}

// MARK: - Integrations: API Keys & Webhooks
export type APIKeyScope = 'tasks.read' | 'tasks.write' | 'webhooks.manage' | 'apikeys.manage' | 'admin';

export interface APIKeyDTO {
  id: string;
  orgId: string;
  userId: string;
  name: string;
  keyPrefix: string;
  scopes: APIKeyScope[];
  lastUsedAt?: string | null;
  expiresAt?: string | null;
  isRevoked: boolean;
  createdAt?: string | null;
}

export interface CreateAPIKeyRequest {
  name: string;
  scopes?: APIKeyScope[];
  expiresAt?: string | null;
}

export interface CreateAPIKeyResponse {
  rawKey: string;
  apiKey: APIKeyDTO;
  id?: string;
}

export interface WebhookSubscriptionDTO {
  id: string;
  orgId: string;
  targetUrl: string;
  secret: string;
  events: string[];
  isActive: boolean;
  failureCount: number;
  createdAt?: string | null;
}

export interface CreateWebhookSubscriptionRequest {
  targetUrl: string;
  events: string[];
  secret?: string;
}

export interface UpdateWebhookSubscriptionRequest {
  targetUrl?: string;
  secret?: string;
  events?: string[];
  isActive?: boolean;
}

export interface WebhookTestResponse {
  delivered: boolean;
  statusCode?: number;
}

export type NavDestination = 
  | 'all_tasks' 
  | 'my_tasks' 
  | 'backlog'
  | 'releases'
  | 'settings'
  | 'integrations'
  | 'inbox' 
  | 'messages' 
  | 'meetings' 
  | 'productivity' 
  | 'sessions' 
  | 'team' 
  | 'billing'
  | 'reminders';

// Productivity: Scheduled Messages
export type ScheduledMessageStatus = 'scheduled' | 'sending' | 'sent' | 'failed' | 'cancelled';

export interface ScheduledMessageDTO {
  id: string;
  userId: string;
  orgId: string;
  conversationId: string;
  parentId?: string | null;
  body: string;
  messageType?: string;
  scheduledFor: string;
  status: ScheduledMessageStatus;
  sentMessageId?: string | null;
  error?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

export interface CreateScheduledMessageRequest {
  body: string;
  scheduledFor: string;
  parentId?: string | null;
  messageType?: string;
}

export interface UpdateScheduledMessageRequest {
  body?: string;
  scheduledFor?: string;
}

// Productivity: Reminders
export type ReminderStatus = 'pending' | 'fired' | 'snoozed' | 'dismissed';

export interface ReminderDTO {
  id: string;
  userId: string;
  orgId: string;
  body: string;
  remindAt: string;
  status: ReminderStatus;
  sourceType?: string | null;
  sourceId?: string | null;
  firedAt?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

export interface CreateReminderRequest {
  body: string;
  remindAt: string;
  sourceType?: string;
  sourceId?: string;
}

export interface CreateMessageReminderRequest {
  remindAt: string;
  body?: string;
}

export interface UpdateReminderRequest {
  body?: string;
  remindAt?: string;
}

export interface SnoozeReminderRequest {
  minutes: number;
}

// Presence & Custom Status
export type PresenceState = 'online' | 'away' | 'offline';

export interface UserPresenceDTO {
  userId: string;
  state: PresenceState;
  customStatusEmoji?: string | null;
  customStatusText?: string | null;
  customStatusExpiresAt?: string | null;
  lastHeartbeatAt?: string | null;
}

export interface SetCustomStatusRequest {
  emoji?: string;
  text?: string;
  expiresAt?: string | null;
}

export interface BulkPresenceResponse {
  presences: UserPresenceDTO[];
}

// Reusable Templates
export type TemplateScope = 'user' | 'org';

export interface MessageTemplateDTO {
  id: string;
  orgId: string;
  ownerUserId?: string | null;
  scope: TemplateScope;
  name: string;
  shortcut?: string | null;
  body: string;
  createdAt?: string | null;
  updatedAt?: string | null;
}

export interface CreateTemplateRequest {
  name: string;
  body: string;
  shortcut?: string | null;
  scope: TemplateScope;
}

export interface UpdateTemplateRequest {
  name?: string;
  body?: string;
  shortcut?: string | null;
}

export interface RenderTemplateRequest {
  conversationId?: string | null;
}

export interface RenderedTemplateDTO {
  templateId: string;
  body: string;
}

// Phase 17: Omnibar Search & AI Copilot
export type SearchEntityType = 'task' | 'message' | 'meeting' | 'member' | 'doc';
export type SearchMode = 'hybrid' | 'semantic' | 'keyword';

export interface SearchResultItemDTO {
  id: string;
  entityType: SearchEntityType;
  title: string;
  subtitle: string;
  deepLink: string;
  icon?: string | null;
  badge?: string | null;
  similarityScore?: number | null;
  matchType?: string | null;
  highlightSnippet?: string | null;
  metadata?: Record<string, string> | null;
  updatedAt?: string | null;
}

export interface OmnibarSearchRequest {
  query: string;
  types?: SearchEntityType[];
  limit?: number;
  mode?: SearchMode;
  threshold?: number;
}

export interface OmnibarSearchResponse {
  results: SearchResultItemDTO[];
  totalCount: number;
  query: string;
  mode?: SearchMode;
}

export type AIAssistantAction =
  | 'breakdown_task'
  | 'generate_standup_summary'
  | 'suggest_next_actions'
  | 'summarize_thread';

export interface SuggestedTaskDTO {
  id?: string;
  title: string;
  description?: string | null;
  priority?: string | null;
  estimateHours?: number | null;
}

export interface AIAssistantRequest {
  action: AIAssistantAction;
  contextId?: string | null;
  prompt?: string | null;
  entityPayload?: Record<string, string> | null;
}

export interface AIAssistantResponse {
  action: AIAssistantAction;
  summary: string;
  suggestedTasks?: SuggestedTaskDTO[] | null;
  actionItems?: string[] | null;
}



