import test from 'node:test';
import assert from 'node:assert/strict';

// Import our deeplink parser logic (compiled or pure function)
function parseDeeplink(input) {
  if (!input) return null;
  const trimmed = input.trim();

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

  let pathname = trimmed;
  try {
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      const url = new URL(trimmed);
      pathname = url.pathname;
    }
  } catch {}

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

test('Universal Deeplinking Engine - Scheme taskflow:// routing', () => {
  const taskRoute = parseDeeplink('taskflow://tasks/11111111-2222-3333-4444-555555555555');
  assert.deepEqual(taskRoute, {
    destination: 'all_tasks',
    taskId: '11111111-2222-3333-4444-555555555555'
  });

  const channelRoute = parseDeeplink('taskflow://channels/22222222-3333-4444-5555-666666666666');
  assert.deepEqual(channelRoute, {
    destination: 'messages',
    channelId: '22222222-3333-4444-5555-666666666666'
  });

  const meetingRoute = parseDeeplink('taskflow://meetings/33333333-4444-5555-6666-777777777777');
  assert.deepEqual(meetingRoute, {
    destination: 'meetings',
    meetingId: '33333333-4444-5555-6666-777777777777'
  });

  const billingRoute = parseDeeplink('taskflow://billing');
  assert.deepEqual(billingRoute, {
    destination: 'billing'
  });

  const inboxRoute = parseDeeplink('taskflow://inbox');
  assert.deepEqual(inboxRoute, {
    destination: 'inbox'
  });

  const productivityRoute = parseDeeplink('taskflow://productivity');
  assert.deepEqual(productivityRoute, {
    destination: 'productivity'
  });
});

test('Universal Deeplinking Engine - Web Pathname & URL routing', () => {
  const taskPath = parseDeeplink('/tasks/task-abc-123');
  assert.deepEqual(taskPath, {
    destination: 'all_tasks',
    taskId: 'task-abc-123'
  });

  const channelPath = parseDeeplink('/channels/channel-xyz-789');
  assert.deepEqual(channelPath, {
    destination: 'messages',
    channelId: 'channel-xyz-789'
  });

  const meetingPath = parseDeeplink('/meetings/meeting-lobby-456');
  assert.deepEqual(meetingPath, {
    destination: 'meetings',
    meetingId: 'meeting-lobby-456'
  });

  const billingPath = parseDeeplink('/billing');
  assert.deepEqual(billingPath, {
    destination: 'billing'
  });

  const appLink = parseDeeplink('https://taskflow.app/tasks/task-999');
  assert.deepEqual(appLink, {
    destination: 'all_tasks',
    taskId: 'task-999'
  });
});
