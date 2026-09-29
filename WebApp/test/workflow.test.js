import test from 'node:test';
import assert from 'node:assert/strict';

// Workflow & Automation rule business logic helpers
function sortStatuses(statuses) {
  return [...statuses].sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
}

function filterStatusesByCategory(statuses, category) {
  return statuses.filter(s => s.category === category);
}

function generateTriggerConfigJson(triggerType, options = {}) {
  if (triggerType === 'task.status_changed' && options.toStatusId) {
    return JSON.stringify({ toStatusId: options.toStatusId });
  }
  return null;
}

function generateActionsJson(actionType, params = {}) {
  switch (actionType) {
    case 'setPriority':
      return JSON.stringify([{ type: 'setPriority', value: params.priority || 'medium' }]);
    case 'setStatusId':
      if (!params.statusId) return null;
      return JSON.stringify([{ type: 'setStatusId', value: params.statusId }]);
    case 'assignUserId':
      if (!params.userId || !params.userId.trim()) return null;
      return JSON.stringify([{ type: 'assignUserId', value: params.userId.trim() }]);
    case 'addLabel':
      if (!params.label || !params.label.trim()) return null;
      return JSON.stringify([{ type: 'addLabel', value: params.label.trim() }]);
    case 'removeLabel':
      if (!params.label || !params.label.trim()) return null;
      return JSON.stringify([{ type: 'removeLabel', value: params.label.trim() }]);
    case 'moveUncompletedToNextSprint':
      return JSON.stringify([{ type: 'moveUncompletedToNextSprint' }]);
    default:
      return null;
  }
}

function detectSelfTriggerLoop(triggerType, actionType, triggerToStatusId, actionStatusId) {
  return (
    triggerType === 'task.status_changed' &&
    actionType === 'setStatusId' &&
    Boolean(triggerToStatusId) &&
    Boolean(actionStatusId) &&
    triggerToStatusId === actionStatusId
  );
}

test('Workflow Statuses: sorts correctly by position', () => {
  const unordered = [
    { id: '3', name: 'Done', position: 3000, category: 'completed' },
    { id: '1', name: 'To Do', position: 1000, category: 'backlog' },
    { id: '2', name: 'In Progress', position: 2000, category: 'active' },
  ];

  const sorted = sortStatuses(unordered);
  assert.equal(sorted[0].name, 'To Do');
  assert.equal(sorted[1].name, 'In Progress');
  assert.equal(sorted[2].name, 'Done');
});

test('Workflow Statuses: filters statuses by category', () => {
  const statuses = [
    { id: '1', name: 'Backlog', category: 'backlog' },
    { id: '2', name: 'Ready', category: 'backlog' },
    { id: '3', name: 'Coding', category: 'active' },
    { id: '4', name: 'In Review', category: 'active' },
    { id: '5', name: 'Shipped', category: 'completed' },
    { id: '6', name: 'Dropped', category: 'cancelled' },
  ];

  assert.equal(filterStatusesByCategory(statuses, 'backlog').length, 2);
  assert.equal(filterStatusesByCategory(statuses, 'active').length, 2);
  assert.equal(filterStatusesByCategory(statuses, 'completed').length, 1);
  assert.equal(filterStatusesByCategory(statuses, 'cancelled').length, 1);
});

test('Automation Rules: triggerConfigJson generation', () => {
  const statusChangedConfig = generateTriggerConfigJson('task.status_changed', { toStatusId: 'status-uuid-123' });
  assert.equal(statusChangedConfig, '{"toStatusId":"status-uuid-123"}');

  const noToStatusConfig = generateTriggerConfigJson('task.status_changed', {});
  assert.equal(noToStatusConfig, null);

  const createdConfig = generateTriggerConfigJson('task.created', { toStatusId: 'status-uuid-123' });
  assert.equal(createdConfig, null);
});

test('Automation Rules: actionJson generation across all 6 action types', () => {
  // 1. setPriority
  const actPriority = generateActionsJson('setPriority', { priority: 'critical' });
  assert.equal(actPriority, '[{"type":"setPriority","value":"critical"}]');

  // 2. setStatusId
  const actStatus = generateActionsJson('setStatusId', { statusId: 'status-done-456' });
  assert.equal(actStatus, '[{"type":"setStatusId","value":"status-done-456"}]');
  assert.equal(generateActionsJson('setStatusId', {}), null);

  // 3. assignUserId
  const actUser = generateActionsJson('assignUserId', { userId: 'user-789' });
  assert.equal(actUser, '[{"type":"assignUserId","value":"user-789"}]');
  assert.equal(generateActionsJson('assignUserId', { userId: '   ' }), null);

  // 4. addLabel
  const actAddLabel = generateActionsJson('addLabel', { label: 'regression' });
  assert.equal(actAddLabel, '[{"type":"addLabel","value":"regression"}]');

  // 5. removeLabel
  const actRemLabel = generateActionsJson('removeLabel', { label: 'needs-triage' });
  assert.equal(actRemLabel, '[{"type":"removeLabel","value":"needs-triage"}]');

  // 6. moveUncompletedToNextSprint
  const actSprint = generateActionsJson('moveUncompletedToNextSprint');
  assert.equal(actSprint, '[{"type":"moveUncompletedToNextSprint"}]');
});

test('Automation Rules: self-trigger loop warning detector', () => {
  // When trigger ToStatus matches target action status -> returns true
  assert.equal(
    detectSelfTriggerLoop('task.status_changed', 'setStatusId', 'uuid-1', 'uuid-1'),
    true
  );

  // When different statuses -> false
  assert.equal(
    detectSelfTriggerLoop('task.status_changed', 'setStatusId', 'uuid-1', 'uuid-2'),
    false
  );

  // When different action type -> false
  assert.equal(
    detectSelfTriggerLoop('task.status_changed', 'setPriority', 'uuid-1', 'uuid-1'),
    false
  );

  // When different trigger -> false
  assert.equal(
    detectSelfTriggerLoop('task.created', 'setStatusId', 'uuid-1', 'uuid-1'),
    false
  );
});
