import test from 'node:test';
import assert from 'node:assert/strict';

// Integrations helper functions for API Keys & Webhooks business logic

function validateApiKeyRequest(payload) {
  if (!payload || !payload.name || !payload.name.trim()) {
    return { valid: false, error: 'Key name is required' };
  }
  const validScopes = ['tasks.read', 'tasks.write', 'webhooks.manage', 'apikeys.manage', 'admin'];
  const scopes = payload.scopes || [];
  for (const s of scopes) {
    if (!validScopes.includes(s)) {
      return { valid: false, error: `Invalid scope: ${s}` };
    }
  }
  return { valid: true };
}

function formatKeyPrefix(rawKey, prefix) {
  if (prefix) return `tf_${prefix}...`;
  if (rawKey && rawKey.startsWith('eap_')) {
    const parts = rawKey.split('.');
    if (parts.length > 1) {
      return `tf_${parts[1].substring(0, 8)}...`;
    }
  }
  return 'tf_••••••••';
}

function validateWebhookRequest(payload) {
  if (!payload || !payload.targetUrl || !payload.targetUrl.trim()) {
    return { valid: false, error: 'Target URL is required' };
  }
  const url = payload.targetUrl.trim();
  if (!url.startsWith('https://') && !url.startsWith('http://')) {
    return { valid: false, error: 'Target URL must start with http:// or https://' };
  }
  if (!payload.events || !Array.isArray(payload.events) || payload.events.length === 0) {
    return { valid: false, error: 'At least one event subscription is required' };
  }
  const allowedEvents = ['task.created', 'task.updated', 'task.deleted', 'comment.created', 'sprint.closed'];
  for (const e of payload.events) {
    if (!allowedEvents.includes(e)) {
      return { valid: false, error: `Unsupported event: ${e}` };
    }
  }
  return { valid: true };
}

function filterActiveWebhooks(webhooks) {
  return webhooks.filter(w => w.isActive);
}

function computeWebhookHealth(webhook) {
  const isFailing = (webhook.failureCount || 0) > 0;
  return {
    status: isFailing ? 'warning' : 'healthy',
    failureCount: webhook.failureCount || 0,
    canDeliver: webhook.isActive && (webhook.failureCount || 0) < 10,
  };
}

test('API Key validation: requires non-empty name', () => {
  const invalid = validateApiKeyRequest({ name: '   ', scopes: ['tasks.read'] });
  assert.equal(invalid.valid, false);
  assert.equal(invalid.error, 'Key name is required');

  const valid = validateApiKeyRequest({ name: 'Zapier Webhook Bot', scopes: ['tasks.read', 'tasks.write'] });
  assert.equal(valid.valid, true);
});

test('API Key validation: checks allowed scopes', () => {
  const invalid = validateApiKeyRequest({ name: 'Bot', scopes: ['tasks.read', 'billing.nuke'] });
  assert.equal(invalid.valid, false);
  assert.match(invalid.error, /Invalid scope/);

  const adminScope = validateApiKeyRequest({ name: 'Admin Key', scopes: ['admin'] });
  assert.equal(adminScope.valid, true);
});

test('Key Prefix formatting: formats rawKey and prefix cleanly', () => {
  const formattedFromPrefix = formatKeyPrefix(null, '8a9fbc12');
  assert.equal(formattedFromPrefix, 'tf_8a9fbc12...');

  const formattedFromRaw = formatKeyPrefix('eap_12345678-1234-1234-1234-123456789abc.abcdef0123456789', null);
  assert.equal(formattedFromRaw, 'tf_abcdef01...');

  const fallback = formatKeyPrefix(null, null);
  assert.equal(fallback, 'tf_••••••••');
});

test('Webhook validation: verifies valid URL protocol and events', () => {
  const invalidUrl = validateWebhookRequest({ targetUrl: 'ftp://api.internal/hook', events: ['task.created'] });
  assert.equal(invalidUrl.valid, false);
  assert.match(invalidUrl.error, /must start with http/);

  const noEvents = validateWebhookRequest({ targetUrl: 'https://example.com/hook', events: [] });
  assert.equal(noEvents.valid, false);
  assert.equal(noEvents.error, 'At least one event subscription is required');

  const invalidEvent = validateWebhookRequest({ targetUrl: 'https://example.com/hook', events: ['user.login'] });
  assert.equal(invalidEvent.valid, false);
  assert.match(invalidEvent.error, /Unsupported event/);

  const valid = validateWebhookRequest({
    targetUrl: 'https://api.zapier.com/hooks/catch/123/abc/',
    events: ['task.created', 'task.updated', 'sprint.closed']
  });
  assert.equal(valid.valid, true);
});

test('Webhook filtering and health calculation', () => {
  const hooks = [
    { id: '1', targetUrl: 'https://a.com', isActive: true, failureCount: 0 },
    { id: '2', targetUrl: 'https://b.com', isActive: false, failureCount: 0 },
    { id: '3', targetUrl: 'https://c.com', isActive: true, failureCount: 3 },
  ];

  const active = filterActiveWebhooks(hooks);
  assert.equal(active.length, 2);

  const healthClean = computeWebhookHealth(hooks[0]);
  assert.equal(healthClean.status, 'healthy');
  assert.equal(healthClean.canDeliver, true);

  const healthWarn = computeWebhookHealth(hooks[2]);
  assert.equal(healthWarn.status, 'warning');
  assert.equal(healthWarn.failureCount, 3);
  assert.equal(healthWarn.canDeliver, true);
});
