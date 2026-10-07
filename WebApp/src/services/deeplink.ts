import { NavDestination } from '../types';

export interface DeeplinkRoute {
  destination: NavDestination;
  taskId?: string;
  channelId?: string;
  meetingId?: string;
  callId?: string;
}

export function parseDeeplink(input: string): DeeplinkRoute | null {
  if (!input) return null;
  const trimmed = input.trim();

  // If input is custom URL scheme: taskflow://tasks/{id}, taskflow://billing, etc.
  if (trimmed.startsWith('taskflow://')) {
    const withoutScheme = trimmed.replace('taskflow://', '');
    const parts = withoutScheme.split('/').filter(Boolean);
    const resource = parts[0]?.toLowerCase();
    const id = parts[1];

    switch (resource) {
      case 'tasks':
      case 'task':
        return { destination: 'all_tasks', taskId: id };
      case 'channels':
      case 'channel':
      case 'messages':
      case 'message':
        return { destination: 'messages', channelId: id };
      case 'meetings':
      case 'meeting':
        return { destination: 'meetings', meetingId: id };
      case 'calls':
      case 'call':
        return { destination: 'meetings', callId: id };
      case 'billing':
      case 'subscriptions':
      case 'subscription':
        return { destination: 'billing' };
      case 'inbox':
      case 'notifications':
        return { destination: 'inbox' };
      case 'productivity':
      case 'reminders':
        return { destination: 'productivity' };
      case 'team':
        return { destination: 'team' };
      default:
        return null;
    }
  }

  // Handle standard HTTP URL or pathname: /tasks/:id, /channels/:id, etc.
  let pathname = trimmed;
  try {
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      const url = new URL(trimmed);
      pathname = url.pathname;
    }
  } catch {
    // fallback to original trimmed
  }

  // Also support hash-based routing: #/tasks/:id
  if (pathname.includes('#')) {
    const hash = pathname.split('#')[1];
    if (hash) pathname = hash;
  }

  const parts = pathname.split('/').filter(Boolean);
  const resource = parts[0]?.toLowerCase();
  const id = parts[1];

  switch (resource) {
    case 'tasks':
    case 'task':
      return { destination: 'all_tasks', taskId: id };
    case 'channels':
    case 'channel':
    case 'messages':
    case 'message':
      return { destination: 'messages', channelId: id };
    case 'meetings':
    case 'meeting':
      return { destination: 'meetings', meetingId: id };
    case 'calls':
    case 'call':
      return { destination: 'meetings', callId: id };
    case 'billing':
    case 'subscriptions':
    case 'subscription':
      return { destination: 'billing' };
    case 'inbox':
    case 'notifications':
      return { destination: 'inbox' };
    case 'productivity':
    case 'reminders':
      return { destination: 'productivity' };
    case 'team':
      return { destination: 'team' };
    default:
      return null;
  }
}

export function getCurrentLocationDeeplink(): DeeplinkRoute | null {
  if (typeof window === 'undefined') return null;

  // Check search params first e.g. ?link=taskflow://tasks/123 or ?deeplink=...
  const params = new URLSearchParams(window.location.search);
  const queryLink = params.get('link') || params.get('deeplink') || params.get('url');
  if (queryLink) {
    const parsed = parseDeeplink(queryLink);
    if (parsed) return parsed;
  }

  // Check window.location.hash
  if (window.location.hash && window.location.hash.length > 1) {
    const hashRoute = parseDeeplink(window.location.hash.substring(1));
    if (hashRoute) return hashRoute;
  }

  // Check window.location.pathname
  return parseDeeplink(window.location.pathname);
}

export function syncUrlWithDestination(route: DeeplinkRoute) {
  if (typeof window === 'undefined') return;
  let path = '/';
  switch (route.destination) {
    case 'all_tasks':
    case 'my_tasks':
      path = route.taskId ? `/tasks/${route.taskId}` : '/';
      break;
    case 'messages':
      path = route.channelId ? `/channels/${route.channelId}` : '/channels';
      break;
    case 'meetings':
      path = route.meetingId ? `/meetings/${route.meetingId}` : '/meetings';
      break;
    case 'billing':
      path = '/billing';
      break;
    case 'inbox':
      path = '/inbox';
      break;
    case 'productivity':
      path = '/productivity';
      break;
    case 'team':
      path = '/team';
      break;
    default:
      path = `/${route.destination}`;
  }

  if (window.location.pathname !== path) {
    window.history.pushState(null, '', path);
  }
}
