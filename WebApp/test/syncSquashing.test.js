import { test } from 'node:test';
import assert from 'node:assert';

// Standalone function matching squashSyncOperations in syncEngine.ts
function squashSyncOperations(queue, incoming) {
  let existingIdx = -1;
  for (let i = queue.length - 1; i >= 0; i--) {
    const op = queue[i];
    if (
      op.orgId === incoming.orgId &&
      op.entityType === incoming.entityType &&
      op.entityId === incoming.entityId &&
      !op.needsAttention
    ) {
      existingIdx = i;
      break;
    }
  }

  if (existingIdx < 0) {
    queue.push(incoming);
    return false;
  }

  const last = queue[existingIdx];
  const lastOp = last.operation;
  const incOp = incoming.operation;

  // Rule 1: PUT + PUT -> merge fields, preserve earliest expectedVersion
  if (lastOp === 'PUT' && incOp === 'PUT') {
    const older = { ...(last.payload || {}) };
    const newer = { ...(incoming.payload || {}) };

    const earliestVersion =
      older.expectedVersion !== undefined
        ? older.expectedVersion
        : newer.expectedVersion;

    const mergedPayload = { ...older, ...newer };
    if (earliestVersion !== undefined) {
      mergedPayload.expectedVersion = earliestVersion;
    }

    last.payload = mergedPayload;
    last.dirtyFields = Array.from(
      new Set([...(last.dirtyFields || []), ...(incoming.dirtyFields || [])])
    ).sort();
    last.timestamp = Math.max(last.timestamp, incoming.timestamp);
    return true;
  }

  // Rule 2: POST + PUT -> fold updates directly into create POST
  if (lastOp === 'POST' && incOp === 'PUT') {
    const create = { ...(last.payload || {}) };
    const update = { ...(incoming.payload || {}) };
    delete update.expectedVersion;

    last.payload = { ...create, ...update };
    last.timestamp = Math.max(last.timestamp, incoming.timestamp);
    return true;
  }

  // Rule 3: PUT + DELETE -> replace PUT with single DELETE
  if (lastOp === 'PUT' && incOp === 'DELETE') {
    queue.splice(existingIdx, 1, incoming);
    return true;
  }

  // Rule 4: POST + DELETE -> created and deleted offline => cancel both (NO-OP)
  if (lastOp === 'POST' && incOp === 'DELETE') {
    queue.splice(existingIdx, 1);
    return true;
  }

  // Rule 5: DELETE + PUT -> invalid offline sequence
  if (lastOp === 'DELETE' && incOp === 'PUT') {
    last.needsAttention = true;
    last.lastError = 'Invalid offline sequence: DELETE followed by PUT.';
    return true;
  }

  queue.push(incoming);
  return false;
}

test('putPlusPut_mergesPayloads_and_preservesEarliestExpectedVersion', () => {
  const queue = [];
  const orgId = 'org-1';
  const taskId = 'task-1';

  const op1 = {
    id: 'op-1',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Old Title', expectedVersion: 10 },
    dirtyFields: ['title'],
    timestamp: 1000,
  };
  const op2 = {
    id: 'op-2',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { priority: 'high', expectedVersion: 999 },
    dirtyFields: ['priority'],
    timestamp: 2000,
  };

  squashSyncOperations(queue, op1);
  const squashed = squashSyncOperations(queue, op2);

  assert.strictEqual(squashed, true);
  assert.strictEqual(queue.length, 1);
  assert.strictEqual(queue[0].operation, 'PUT');
  assert.strictEqual(queue[0].payload.title, 'Old Title');
  assert.strictEqual(queue[0].payload.priority, 'high');
  assert.strictEqual(queue[0].payload.expectedVersion, 10);
  assert.deepStrictEqual(queue[0].dirtyFields, ['priority', 'title']);
});

test('postPlusPut_foldsIntoCreate', () => {
  const queue = [];
  const orgId = 'org-1';
  const taskId = 'task-1';

  const opPost = {
    id: 'op-post',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'POST',
    payload: { id: taskId, title: 'Initial Title', listId: 'list-1' },
    timestamp: 1000,
  };
  const opPut = {
    id: 'op-put',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Updated Title', description: 'Some details', expectedVersion: 1 },
    dirtyFields: ['title', 'description'],
    timestamp: 2000,
  };

  squashSyncOperations(queue, opPost);
  const squashed = squashSyncOperations(queue, opPut);

  assert.strictEqual(squashed, true);
  assert.strictEqual(queue.length, 1);
  assert.strictEqual(queue[0].operation, 'POST');
  assert.strictEqual(queue[0].payload.title, 'Updated Title');
  assert.strictEqual(queue[0].payload.description, 'Some details');
  assert.strictEqual(queue[0].payload.listId, 'list-1');
  assert.strictEqual(queue[0].payload.expectedVersion, undefined);
});

test('putPlusDelete_replacesWithDelete', () => {
  const queue = [];
  const orgId = 'org-1';
  const taskId = 'task-1';

  const opPut = {
    id: 'op-put',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Updated' },
    timestamp: 1000,
  };
  const opDelete = {
    id: 'op-delete',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'DELETE',
    timestamp: 2000,
  };

  squashSyncOperations(queue, opPut);
  const squashed = squashSyncOperations(queue, opDelete);

  assert.strictEqual(squashed, true);
  assert.strictEqual(queue.length, 1);
  assert.strictEqual(queue[0].operation, 'DELETE');
});

test('postPlusDelete_becomesNoop', () => {
  const queue = [];
  const orgId = 'org-1';
  const taskId = 'task-1';

  const opPost = {
    id: 'op-post',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'POST',
    payload: { title: 'Offline Created' },
    timestamp: 1000,
  };
  const opDelete = {
    id: 'op-delete',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'DELETE',
    timestamp: 2000,
  };

  squashSyncOperations(queue, opPost);
  const squashed = squashSyncOperations(queue, opDelete);

  assert.strictEqual(squashed, true);
  assert.strictEqual(queue.length, 0);
});

test('deletePlusPut_marksNeedsAttention', () => {
  const queue = [];
  const orgId = 'org-1';
  const taskId = 'task-1';

  const opDelete = {
    id: 'op-delete',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'DELETE',
    timestamp: 1000,
  };
  const opPut = {
    id: 'op-put',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Zombie Edit' },
    timestamp: 2000,
  };

  squashSyncOperations(queue, opDelete);
  const squashed = squashSyncOperations(queue, opPut);

  assert.strictEqual(squashed, true);
  assert.strictEqual(queue.length, 1);
  assert.strictEqual(queue[0].needsAttention, true);
  assert.ok(queue[0].lastError.includes('Invalid offline sequence'));
});
