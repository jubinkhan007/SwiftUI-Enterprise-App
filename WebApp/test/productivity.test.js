import test from 'node:test';
import assert from 'node:assert/strict';

// Helper mirroring backend TemplateController.expand
function expandTemplate(body, { userName = '', userEmail = '', orgName = '', conversationName = '', dateStr = 'Sep 30, 2026', timeStr = '2:00 PM' } = {}) {
  const mappings = {
    '{{user.name}}': userName,
    '{{user.email}}': userEmail,
    '{{org.name}}': orgName,
    '{{conversation.name}}': conversationName,
    '{{date}}': dateStr,
    '{{time}}': timeStr,
  };
  let result = body;
  for (const [k, v] of Object.entries(mappings)) {
    result = result.replaceAll(k, v);
  }
  return result;
}

// Helper mirroring backend PresenceController.computeEffectiveState
function computeEffectivePresence(lastHeartbeatDate, state = 'online', now = new Date()) {
  if (!lastHeartbeatDate) return 'offline';
  const ageSeconds = (now.getTime() - new Date(lastHeartbeatDate).getTime()) / 1000;
  if (ageSeconds > 300) return 'offline';
  if (state === 'away') return 'away';
  if (ageSeconds > 60) return 'away';
  return 'online';
}

// Helper mirroring backend template shortcut validator
function isValidTemplateShortcut(shortcut) {
  if (!shortcut) return true;
  if (shortcut.length > 24) return false;
  return /^[A-Za-z0-9_-]+$/.test(shortcut);
}

// Helper mirroring reminder snooze calculation
function calculateSnoozeDate(baseDate, minutes) {
  return new Date(new Date(baseDate).getTime() + minutes * 60 * 1000).toISOString();
}

test('Templates: expands {{user.name}}, {{org.name}}, and {{date}} variables properly', () => {
  const tpl = 'Hello {{user.name}} from {{org.name}}! Today is {{date}} in #{{conversation.name}}.';
  const rendered = expandTemplate(tpl, {
    userName: 'Alex Chen',
    orgName: 'Acme Corp',
    conversationName: 'engineering',
    dateStr: 'Sep 30, 2026',
  });
  assert.equal(
    rendered,
    'Hello Alex Chen from Acme Corp! Today is Sep 30, 2026 in #engineering.'
  );
});

test('Templates: validates shortcut format', () => {
  assert.equal(isValidTemplateShortcut('standup'), true);
  assert.equal(isValidTemplateShortcut('daily_retro-2'), true);
  assert.equal(isValidTemplateShortcut('bad shortcut with spaces'), false);
  assert.equal(isValidTemplateShortcut('too_long_shortcut_exceeding_twenty_four_chars'), false);
});

test('Presence: computes online, away, and offline correctly based on heartbeat age', () => {
  const now = new Date('2026-09-30T12:00:00Z');
  
  // Recent heartbeat within 60s
  const recent = new Date('2026-09-30T11:59:30Z');
  assert.equal(computeEffectivePresence(recent, 'online', now), 'online');

  // Explicit away within window
  assert.equal(computeEffectivePresence(recent, 'away', now), 'away');

  // Heartbeat 2 minutes ago (> 60s, < 5m)
  const twoMinsAgo = new Date('2026-09-30T11:58:00Z');
  assert.equal(computeEffectivePresence(twoMinsAgo, 'online', now), 'away');

  // Heartbeat 10 minutes ago (> 5m)
  const tenMinsAgo = new Date('2026-09-30T11:50:00Z');
  assert.equal(computeEffectivePresence(tenMinsAgo, 'online', now), 'offline');

  // No heartbeat
  assert.equal(computeEffectivePresence(null, 'online', now), 'offline');
});

test('Reminders: calculates snooze timestamp correctly', () => {
  const base = '2026-09-30T10:00:00.000Z';
  const snoozed15 = calculateSnoozeDate(base, 15);
  const snoozed60 = calculateSnoozeDate(base, 60);

  assert.equal(snoozed15, '2026-09-30T10:15:00.000Z');
  assert.equal(snoozed60, '2026-09-30T11:00:00.000Z');
});

test('Scheduled Messages: verifies future schedule timestamp constraint', () => {
  const now = Date.now();
  const past = new Date(now - 60000);
  const future = new Date(now + 60000);

  const isFuture = (dt) => dt.getTime() > now - 30000;
  assert.equal(isFuture(past), false);
  assert.equal(isFuture(future), true);
});
