import {
  AuthResponse,
  ConversationDTO,
  HierarchyTreeDTO,
  MeetingDTO,
  MessageDTO,
  NotificationDTO,
  OrgMemberDTO,
  ProjectDTO,
  SpaceDTO,
  TaskItemDTO,
  TaskListDTO,
  TaskStatus,
  ThreadMessageBundleDTO,
  TimeLogDTO,
  UserDTO,
  UserSessionDTO,
  CallTicketDTO
} from '../types';

class ApiService {
  private baseUrl: string = '';
  private token: string | null = localStorage.getItem('taskflow_token');
  private selectedOrgId: string | null = localStorage.getItem('taskflow_org_id');
  public currentUser: UserDTO | null = (() => {
    try {
      const stored = localStorage.getItem('taskflow_user');
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  })();

  setBaseUrl(url: string) {
    this.baseUrl = url.endsWith('/') ? url.slice(0, -1) : url;
  }

  setToken(token: string | null) {
    this.token = token;
    if (token) {
      localStorage.setItem('taskflow_token', token);
    } else {
      localStorage.removeItem('taskflow_token');
    }
  }

  setOrgId(orgId: string | null) {
    this.selectedOrgId = orgId;
    if (orgId) {
      localStorage.setItem('taskflow_org_id', orgId);
    } else {
      localStorage.removeItem('taskflow_org_id');
    }
  }

  setCurrentUser(user: UserDTO | null) {
    this.currentUser = user;
    if (user) {
      localStorage.setItem('taskflow_user', JSON.stringify(user));
    } else {
      localStorage.removeItem('taskflow_user');
    }
  }

  logout() {
    this.setToken(null);
    this.setOrgId(null);
    this.setCurrentUser(null);
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string>),
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    if (this.selectedOrgId) {
      headers['X-Org-Id'] = this.selectedOrgId;
    }

    const endpoint = this.baseUrl ? `${this.baseUrl}${path}` : path;

    try {
      const response = await fetch(endpoint, {
        ...options,
        headers,
      });

      const resText = await response.text();
      let json: any = {};
      try {
        json = JSON.parse(resText);
      } catch {
        json = { reason: resText };
      }

      if (!response.ok || json.success === false || json.error === true) {
        const errorMsg = json.reason || json.error?.message || json.message || `Request failed with HTTP ${response.status}`;
        throw new Error(errorMsg);
      }

      return (json.data !== undefined ? json.data : json) as T;
    } catch (err: any) {
      console.error(`API Error [${path}]:`, err);
      throw err;
    }
  }

  // --- Auth ---
  async login(email: string, password: String): Promise<AuthResponse> {
    const raw = await this.request<any>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });

    const userRaw = raw.user || {};
    const user: UserDTO = {
      id: userRaw.id || '',
      email: userRaw.email || email,
      displayName: userRaw.display_name || userRaw.displayName || userRaw.email || 'User',
      role: userRaw.role || 'member',
      createdAt: userRaw.created_at || userRaw.createdAt,
      updatedAt: userRaw.updated_at || userRaw.updatedAt,
      isSuperAdmin: userRaw.is_super_admin ?? userRaw.isSuperAdmin ?? false,
    };

    this.setToken(raw.token);
    this.setCurrentUser(user);

    // Auto-fetch user organizations to populate X-Org-Id header
    try {
      const orgs = await this.request<any[]>('/api/organizations');
      if (Array.isArray(orgs) && orgs.length > 0) {
        this.setOrgId(orgs[0].id);
      }
    } catch (err) {
      console.warn('Could not auto-fetch user organization:', err);
    }

    return { token: raw.token, user };
  }

  // --- Tasks & Kanban ---
  async getTasks(): Promise<TaskItemDTO[]> {
    const data = await this.request<any>('/api/tasks');
    const items: any[] = Array.isArray(data) ? data : (data?.data || []);
    return items.map((t: any) => ({
      id: t.id,
      orgId: t.org_id || t.orgId,
      listId: t.list_id || t.listId,
      projectId: t.project_id || t.projectId,
      title: t.title || 'Untitled Task',
      description: t.description,
      status: t.status || 'todo',
      priority: t.priority || 'medium',
      taskType: t.task_type || t.taskType || 'task',
      storyPoints: t.story_points ?? t.storyPoints,
      issueKey: t.issue_key || t.issueKey,
      labels: t.labels || [],
      startDate: t.start_date || t.startDate,
      dueDate: t.due_date || t.dueDate,
      completedAt: t.completed_at || t.completedAt,
      assigneeId: t.assignee_id || t.assigneeId,
      position: t.position || 0,
    }));
  }

  async updateTask(taskId: string, updates: Partial<TaskItemDTO>): Promise<TaskItemDTO> {
    const payload: any = {
      title: updates.title,
      description: updates.description,
      status: updates.status,
      priority: updates.priority === 'urgent' ? 'critical' : updates.priority,
      taskType: updates.taskType,
      storyPoints: updates.storyPoints,
      assigneeId: updates.assigneeId,
      labels: updates.labels,
    };

    const t = await this.request<any>(`/api/tasks/${taskId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });

    return {
      id: t.id || taskId,
      orgId: t.org_id || t.orgId || updates.orgId,
      listId: t.list_id || t.listId || updates.listId,
      projectId: t.project_id || t.projectId || updates.projectId,
      title: t.title || updates.title || 'Untitled Task',
      description: t.description || updates.description,
      status: t.status || updates.status || 'todo',
      priority: t.priority || updates.priority || 'medium',
      taskType: t.task_type || t.taskType || updates.taskType || 'task',
      storyPoints: t.story_points ?? t.storyPoints ?? updates.storyPoints,
      issueKey: t.issue_key || t.issueKey || updates.issueKey,
      labels: t.labels || updates.labels || [],
      startDate: t.start_date || t.startDate || updates.startDate,
      dueDate: t.due_date || t.dueDate || updates.dueDate,
      completedAt: t.completed_at || t.completedAt || updates.completedAt,
      assigneeId: t.assignee_id || t.assigneeId || updates.assigneeId,
      position: t.position || updates.position || 0,
    };
  }

  async moveTask(taskId: string, newStatus: TaskStatus, newPosition: number = 0.0): Promise<TaskItemDTO[]> {
    try {
      await this.updateTask(taskId, { status: newStatus });
    } catch (err) {
      console.warn('updateTask status patch warning:', err);
    }

    try {
      await this.request<any>('/api/tasks/move-multiple', {
        method: 'POST',
        body: JSON.stringify({
          targetStatus: newStatus,
          moves: [{ taskId, newPosition }],
        }),
      });
    } catch (err) {
      console.warn('move-multiple warning:', err);
    }

    return this.getTasks();
  }

  // --- Hierarchy Tree ---
  async getHierarchy(): Promise<HierarchyTreeDTO> {
    const raw = await this.request<any>('/api/hierarchy');
    return raw || { spaces: [] };
  }

  async createSpace(name: string, description?: string): Promise<SpaceDTO> {
    const raw = await this.request<any>('/api/spaces', {
      method: 'POST',
      body: JSON.stringify({ name, description }),
    });
    return raw.data || raw;
  }

  async createProject(spaceId: string, name: string): Promise<ProjectDTO> {
    const raw = await this.request<any>(`/api/spaces/${spaceId}/projects`, {
      method: 'POST',
      body: JSON.stringify({ name }),
    });
    return raw.data || raw;
  }

  async createTaskList(projectId: string, name: string): Promise<TaskListDTO> {
    const raw = await this.request<any>(`/api/projects/${projectId}/lists`, {
      method: 'POST',
      body: JSON.stringify({ name }),
    });
    return raw.data || raw;
  }

  // --- Notifications ---
  async getNotifications(): Promise<NotificationDTO[]> {
    const raw = await this.request<any>('/api/notifications');
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    return items.map((n: any) => {
      let payload: any = {};
      const payloadStr = n.payload_json || n.payloadJson;
      if (payloadStr) {
        try {
          payload = typeof payloadStr === 'string' ? JSON.parse(payloadStr) : payloadStr;
        } catch {}
      }

      const callerName = payload.actorName || n.actor_name || n.actorName || 'Team Member';
      let title = n.title;
      let body = n.body;

      if (n.type === 'call.incoming') {
        title = 'Incoming Video Call';
        body = `${callerName} is requesting an instant video call`;
      } else {
        if (!title) title = 'System Notification';
        if (!body) body = typeof payloadStr === 'string' ? payloadStr : 'Activity update';
      }

      return {
        id: n.id,
        title,
        body,
        type: n.type || 'info',
        isRead: n.read_at ? true : (n.is_read ?? n.isRead ?? false),
        createdAt: n.created_at || n.createdAt || new Date().toISOString(),
        actorUserId: n.actor_user_id || n.actorUserId,
        actorName: callerName,
        callSessionId: payload.callSessionId || n.entity_id || n.entityId,
        payloadJson: payloadStr,
      };
    });
  }

  async markNotificationRead(notificationId: string): Promise<void> {
    try {
      await this.request(`/api/notifications/${notificationId}/read`, { method: 'POST' });
    } catch (e) {
      console.warn(`Could not mark notification ${notificationId} read:`, e);
    }
  }

  async markAllNotificationsRead(): Promise<void> {
    const unread = await this.getNotifications();
    for (const item of unread.filter(n => !n.isRead)) {
      await this.markNotificationRead(item.id);
    }
  }

  // --- Messaging & Channels ---
  async getOrgMembers(): Promise<OrgMemberDTO[]> {
    if (!this.selectedOrgId) {
      try {
        const me = await this.request<any>('/api/me');
        const orgs = me.organizations || me.orgs || me.data?.organizations || [];
        if (orgs.length > 0) {
          this.setOrgId(orgs[0].id);
        }
      } catch (err) {
        console.error('Failed to get user me details:', err);
      }
    }
    if (!this.selectedOrgId) return [];

    const raw = await this.request<any>(`/api/organizations/${this.selectedOrgId}/members`);
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    return items.map((m: any) => ({
      id: m.id,
      userId: m.user_id || m.userId,
      orgId: m.org_id || m.orgId || this.selectedOrgId || '',
      role: m.role || 'member',
      displayName: m.display_name || m.displayName || m.user?.displayName || 'Team Member',
      email: m.email || m.user?.email || '',
      joinedAt: m.joined_at || m.joinedAt,
    }));
  }

  async getConversations(): Promise<ConversationDTO[]> {
    const raw = await this.request<any>('/api/conversations');
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    return items.map((c: any) => ({
      id: c.id,
      type: c.type || 'channel',
      name: c.name || (c.last_message ? (c.last_message.sender_name || c.last_message.sender_display_name) : 'Channel'),
      description: c.description,
      topic: c.topic,
      isArchived: c.is_archived ?? c.isArchived ?? false,
      isPrivate: c.is_private ?? c.isPrivate ?? false,
      memberCount: c.member_count ?? c.memberCount,
      messageCount: c.message_count ?? c.messageCount,
      lastMessageAt: c.last_message_at || c.lastMessageAt,
    }));
  }

  async createConversation(payload: {
    type: 'direct' | 'channel' | 'group';
    memberIds: string[];
    name?: string;
    description?: string;
    topic?: string;
  }): Promise<ConversationDTO> {
    const raw = await this.request<any>('/api/conversations', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    const c = raw.data || raw;
    return {
      id: c.id,
      type: c.type || payload.type,
      name: c.name || payload.name,
      description: c.description || payload.description,
      topic: c.topic || payload.topic,
      isArchived: c.is_archived ?? c.isArchived ?? false,
      isPrivate: c.is_private ?? c.isPrivate ?? false,
      memberCount: c.member_count ?? c.memberCount,
      messageCount: c.message_count ?? c.messageCount,
      lastMessageAt: c.last_message_at || c.lastMessageAt,
    };
  }

  async getMessages(conversationId: string): Promise<MessageDTO[]> {
    const raw = await this.request<any>(`/api/conversations/${conversationId}/messages`);
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    const sorted = [...items].sort((a, b) => {
      const tA = new Date(a.created_at || a.createdAt || 0).getTime();
      const tB = new Date(b.created_at || b.createdAt || 0).getTime();
      return tA - tB;
    });
    return sorted.map((m: any) => ({
      id: m.id,
      conversationId: m.conversation_id || m.conversationId || conversationId,
      senderId: m.sender_id || m.senderId || '',
      senderDisplayName: m.sender_name || m.sender_display_name || m.senderDisplayName || 'Team Member',
      body: m.body,
      messageType: m.message_type || m.messageType || 'text',
      parentId: m.parent_id || m.parentId,
      replyCount: m.reply_count ?? m.replyCount ?? 0,
      reactions: (m.reactions || []).map((r: any) => ({
        emoji: r.emoji,
        count: r.count,
        userIds: r.user_ids || r.userIds || [],
        didReact: r.did_react ?? r.didReact ?? false,
      })),
      isPinned: m.is_pinned ?? m.isPinned ?? false,
      isBookmarkedByMe: m.is_bookmarked_by_me ?? m.isBookmarkedByMe ?? false,
      createdAt: m.created_at || m.createdAt,
    }));
  }

  async sendMessage(conversationId: string, body: string, parentId?: string): Promise<MessageDTO> {
    const raw = await this.request<any>(`/api/conversations/${conversationId}/messages`, {
      method: 'POST',
      body: JSON.stringify({ body, messageType: 'text', parentId }),
    });

    return {
      id: raw.id,
      conversationId: raw.conversation_id || raw.conversationId || conversationId,
      senderId: raw.sender_id || raw.senderId || this.currentUser?.id || '',
      senderDisplayName: raw.sender_name || raw.sender_display_name || raw.senderDisplayName || this.currentUser?.displayName || 'You',
      body: raw.body,
      messageType: raw.message_type || raw.messageType || 'text',
      parentId: raw.parent_id || raw.parentId,
      replyCount: raw.reply_count ?? raw.replyCount ?? 0,
      reactions: raw.reactions || [],
      isPinned: raw.is_pinned ?? raw.isPinned ?? false,
      isBookmarkedByMe: raw.is_bookmarked_by_me ?? raw.isBookmarkedByMe ?? false,
      createdAt: raw.created_at || raw.createdAt || new Date().toISOString(),
    };
  }

  async getThread(messageId: string): Promise<ThreadMessageBundleDTO> {
    const raw = await this.request<any>(`/api/messages/${messageId}/thread`);
    const root = raw.root_message || raw.rootMessage || raw;
    const replies = raw.replies || [];

    const mapMsg = (m: any): MessageDTO => ({
      id: m.id,
      conversationId: m.conversation_id || m.conversationId,
      senderId: m.sender_id || m.senderId,
      senderDisplayName: m.sender_name || m.sender_display_name || m.senderDisplayName || 'Team Member',
      body: m.body,
      messageType: m.message_type || m.messageType || 'text',
      parentId: m.parent_id || m.parentId,
      replyCount: m.reply_count ?? m.replyCount ?? 0,
      reactions: m.reactions || [],
      isPinned: m.is_pinned ?? m.isPinned ?? false,
      isBookmarkedByMe: m.is_bookmarked_by_me ?? m.isBookmarkedByMe ?? false,
      createdAt: m.created_at || m.createdAt,
    });

    return {
      rootMessage: mapMsg(root),
      replies: replies.map(mapMsg),
    };
  }

  async addReaction(messageId: string, emoji: string): Promise<MessageDTO> {
    const m = await this.request<any>(`/api/messages/${messageId}/reactions`, {
      method: 'POST',
      body: JSON.stringify({ emoji }),
    });
    return {
      id: m.id,
      conversationId: m.conversation_id || m.conversationId,
      senderId: m.sender_id || m.senderId,
      senderDisplayName: m.sender_name || m.sender_display_name || m.senderDisplayName || 'Team Member',
      body: m.body,
      messageType: m.message_type || m.messageType || 'text',
      parentId: m.parent_id || m.parentId,
      replyCount: m.reply_count ?? m.replyCount ?? 0,
      reactions: m.reactions || [],
      isPinned: m.is_pinned ?? m.isPinned ?? false,
      isBookmarkedByMe: m.is_bookmarked_by_me ?? m.isBookmarkedByMe ?? false,
      createdAt: m.created_at || m.createdAt,
    };
  }

  async pinMessage(messageId: string): Promise<MessageDTO> {
    const m = await this.request<any>(`/api/messages/${messageId}/pin`, {
      method: 'POST',
    });
    return {
      id: m.id,
      conversationId: m.conversation_id || m.conversationId,
      senderId: m.sender_id || m.senderId,
      senderDisplayName: m.sender_name || m.sender_display_name || m.senderDisplayName || 'Team Member',
      body: m.body,
      messageType: m.message_type || m.messageType || 'text',
      parentId: m.parent_id || m.parentId,
      replyCount: m.reply_count ?? m.replyCount ?? 0,
      reactions: m.reactions || [],
      isPinned: m.is_pinned ?? m.isPinned ?? true,
      isBookmarkedByMe: m.is_bookmarked_by_me ?? m.isBookmarkedByMe ?? false,
      createdAt: m.created_at || m.createdAt,
    };
  }

  async bookmarkMessage(messageId: string): Promise<MessageDTO> {
    const m = await this.request<any>(`/api/messages/${messageId}/bookmark`, {
      method: 'POST',
    });
    return {
      id: m.id,
      conversationId: m.conversation_id || m.conversationId,
      senderId: m.sender_id || m.senderId,
      senderDisplayName: m.sender_name || m.sender_display_name || m.senderDisplayName || 'Team Member',
      body: m.body,
      messageType: m.message_type || m.messageType || 'text',
      parentId: m.parent_id || m.parentId,
      replyCount: m.reply_count ?? m.replyCount ?? 0,
      reactions: m.reactions || [],
      isPinned: m.is_pinned ?? m.isPinned ?? false,
      isBookmarkedByMe: m.is_bookmarked_by_me ?? m.isBookmarkedByMe ?? true,
      createdAt: m.created_at || m.createdAt,
    };
  }

  async convertMessageToTask(messageId: string, listId: string, title?: string): Promise<TaskItemDTO> {
    const t = await this.request<any>(`/api/messages/${messageId}/convert-to-task`, {
      method: 'POST',
      body: JSON.stringify({ listId, title }),
    });

    return {
      id: t.id,
      orgId: t.org_id || t.orgId,
      listId: t.list_id || t.listId,
      projectId: t.project_id || t.projectId,
      title: t.title || title || 'New Task',
      description: t.description,
      status: t.status || 'todo',
      priority: t.priority || 'medium',
      taskType: t.task_type || t.taskType || 'task',
      storyPoints: t.story_points ?? t.storyPoints,
      issueKey: t.issue_key || t.issueKey,
      labels: t.labels || [],
      startDate: t.start_date || t.startDate,
      dueDate: t.due_date || t.dueDate,
      completedAt: t.completed_at || t.completedAt,
      assigneeId: t.assignee_id || t.assigneeId,
      position: t.position || 0,
    };
  }

  // --- Meetings & Time Tracking ---
  async getMeetings(): Promise<MeetingDTO[]> {
    const raw = await this.request<any>('/api/meetings');
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    return items.map((m: any) => ({
      id: m.id,
      orgId: m.org_id || m.orgId,
      title: m.title || 'Team Sync',
      description: m.description,
      scheduledAt: m.scheduled_start_at || m.scheduledAt || new Date().toISOString(),
      durationMinutes: m.duration_minutes ?? m.durationMinutes ?? 30,
      meetingUrl: m.meeting_url || m.meetingUrl,
      hostId: m.host_id || m.hostId,
    }));
  }

  async createMeeting(title: string, description?: string, scheduledAt?: string, durationMinutes: number = 30): Promise<MeetingDTO> {
    const start = scheduledAt ? new Date(scheduledAt) : new Date();
    const end = new Date(start.getTime() + durationMinutes * 60000);

    const m = await this.request<any>('/api/meetings', {
      method: 'POST',
      body: JSON.stringify({
        title,
        description,
        scheduledStartAt: start.toISOString(),
        scheduledEndAt: end.toISOString(),
        timezone: 'UTC',
        memberIds: []
      }),
    });

    return {
      id: m.id,
      orgId: m.org_id || m.orgId,
      title: m.title || title,
      description: m.description || description,
      scheduledAt: m.scheduled_start_at || start.toISOString(),
      durationMinutes,
      meetingUrl: m.meeting_url || m.meetingUrl,
      hostId: m.host_id || m.hostId,
    };
  }

  async logTime(taskId?: string, hoursLogged: number = 1.0, description?: string): Promise<TimeLogDTO> {
    let targetTaskId = taskId;
    if (!targetTaskId) {
      const tasks = await this.getTasks();
      targetTaskId = tasks[0]?.id;
    }

    if (!targetTaskId) {
      throw new Error("No task available to log time against.");
    }

    const l = await this.request<any>(`/api/tasks/${targetTaskId}/time-logs`, {
      method: 'POST',
      body: JSON.stringify({
        hoursLogged,
        loggedAt: new Date().toISOString(),
        description
      }),
    });

    return {
      id: l.id,
      taskId: l.task_id || l.taskId || targetTaskId,
      userId: l.user_id || l.userId || this.currentUser?.id || '',
      orgId: l.org_id || l.orgId,
      hoursLogged: l.hours_logged ?? l.hoursLogged ?? hoursLogged,
      loggedAt: l.logged_at || l.loggedAt || new Date().toISOString(),
      description: l.description || description,
    };
  }

  // --- Calls ---
  async initiateCall(conversationId: string, hasVideo: boolean = true): Promise<CallTicketDTO> {
    return await this.request<CallTicketDTO>('/api/calls/initiate', {
      method: 'POST',
      body: JSON.stringify({ conversationId, hasVideo }),
    });
  }

  // --- Sessions & Security ---
  async getSessions(): Promise<UserSessionDTO[]> {
    const raw = await this.request<any>('/api/me/sessions');
    const items: any[] = Array.isArray(raw) ? raw : (raw?.data || []);
    return items.map((s: any) => ({
      id: s.id,
      userId: s.user_id || s.userId,
      deviceType: s.device_type || s.deviceType || 'Web Browser',
      ipAddress: s.ip_address || s.ipAddress || '127.0.0.1',
      userAgent: s.user_agent || s.userAgent || 'Web Client',
      isRevoked: s.is_revoked ?? s.isRevoked ?? false,
      expiresAt: s.expires_at || s.expiresAt,
      createdAt: s.created_at || s.createdAt,
    }));
  }

  async revokeSession(sessionId: string): Promise<void> {
    await this.request(`/api/me/sessions/${sessionId}`, {
      method: 'DELETE',
    });
  }
}

export const api = new ApiService();
