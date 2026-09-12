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
  orgId?: string;
  hoursLogged: number;
  loggedAt: string;
  description?: string;
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

export type NavDestination = 
  | 'all_tasks' 
  | 'my_tasks' 
  | 'inbox' 
  | 'messages' 
  | 'meetings' 
  | 'productivity' 
  | 'sessions';
