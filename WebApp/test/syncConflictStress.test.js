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

// Mock SyncEngine implementation matching WebApp/src/services/syncEngine.ts for isolated testing
class TestSyncEngine {
  constructor() {
    this.operations = [];
    this.syncing = false;
  }

  enqueue(op) {
    squashSyncOperations(this.operations, op);
  }

  getPendingOperations() {
    return this.operations.filter((op) => !op.needsAttention);
  }

  getAttentionOperations() {
    return this.operations.filter((op) => op.needsAttention);
  }

  async processOperation(op, mockApi) {
    try {
      if (op.operation === 'POST') {
        await mockApi.createTask(op.payload);
        this.operations = this.operations.filter((o) => o.id !== op.id);
      } else if (op.operation === 'PUT') {
        await mockApi.updateTask(op.entityId, op.payload);
        this.operations = this.operations.filter((o) => o.id !== op.id);
      } else if (op.operation === 'DELETE') {
        await mockApi.deleteTask(op.entityId);
        this.operations = this.operations.filter((o) => o.id !== op.id);
      }
    } catch (err) {
      if (err?.status === 409 || err?.response?.status === 409) {
        const serverSnapshot = err?.data || err?.response?.data || {};
        op.needsAttention = true;
        op.lastError = 'Conflict: server has newer changes for the same task.';
        op.remoteSnapshot = serverSnapshot;
      } else {
        op.retryCount = (op.retryCount || 0) + 1;
        op.lastError = err?.message || 'Sync failed';
      }
    }
  }

  resolveConflictUseTheirs(op, onApplied) {
    if (op.remoteSnapshot && onApplied) {
      onApplied(op.remoteSnapshot);
    }
    this.discard(op);
  }

  resolveConflictKeepMine(op) {
    const serverVersion = op.remoteSnapshot?.version || 1;
    if (op.payload) {
      op.payload.expectedVersion = serverVersion;
    }
    op.needsAttention = false;
    op.lastError = undefined;
    op.remoteSnapshot = undefined;
    op.retryCount = 0;
  }

  discard(op) {
    this.operations = this.operations.filter((o) => o.id !== op.id);
  }
}

test('Offline Sync Stress: 120 interleaved operations across 4 tasks and 2 orgs', () => {
  const queue = [];
  const orgs = ['org-alpha', 'org-beta'];
  const tasks = ['task-101', 'task-102', 'task-103', 'task-104'];

  let ts = 1000;
  // Enqueue 120 rapid interleaved operations
  for (let round = 0; round < 30; round++) {
    for (let t = 0; t < tasks.length; t++) {
      const taskId = tasks[t];
      const orgId = orgs[t % 2];

      const op = {
        id: `op-${round}-${t}`,
        entityType: 'task',
        entityId: taskId,
        orgId,
        operation: 'PUT',
        payload: {
          round,
          [`field_${round}`]: `val_${round}`,
          expectedVersion: round === 0 ? 1 : 10 + round,
        },
        dirtyFields: [`field_${round}`],
        timestamp: ts++,
      };
      squashSyncOperations(queue, op);
    }
  }

  // Exactly 4 squashed operations should remain (1 per task)
  assert.strictEqual(queue.length, 4);

  // Each task should retain the earliest expectedVersion = 1 from round 0
  for (const op of queue) {
    assert.strictEqual(op.operation, 'PUT');
    assert.strictEqual(op.payload.expectedVersion, 1);
    assert.strictEqual(op.payload.round, 29); // Latest round field values preserved
    assert.strictEqual(op.dirtyFields.length, 30); // All 30 unique dirty fields accumulated
  }
});

test('OCC Conflict Resolution Simulation: 409 Conflict flags needsAttention with remoteSnapshot', async () => {
  const engine = new TestSyncEngine();
  const taskId = 'task-conflict-1';
  const orgId = 'org-alpha';

  const op = {
    id: 'op-put-1',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Local Offline Edit', expectedVersion: 1 },
    dirtyFields: ['title'],
    timestamp: 1000,
  };
  engine.enqueue(op);

  assert.strictEqual(engine.getPendingOperations().length, 1);
  assert.strictEqual(engine.getAttentionOperations().length, 0);

  // Mock API returning 409 Conflict with remote server state (version: 2)
  const mockApi = {
    updateTask: async () => {
      const err = new Error('Conflict');
      err.status = 409;
      err.data = {
        id: taskId,
        title: 'Remote Online Edit',
        priority: 'high',
        version: 2,
      };
      throw err;
    },
  };

  await engine.processOperation(engine.getPendingOperations()[0], mockApi);

  // Operation should now be moved to needsAttention list
  assert.strictEqual(engine.getPendingOperations().length, 0);
  assert.strictEqual(engine.getAttentionOperations().length, 1);

  const conflictedOp = engine.getAttentionOperations()[0];
  assert.strictEqual(conflictedOp.needsAttention, true);
  assert.ok(conflictedOp.lastError.includes('Conflict'));
  assert.strictEqual(conflictedOp.remoteSnapshot.version, 2);
  assert.strictEqual(conflictedOp.remoteSnapshot.title, 'Remote Online Edit');
});

test('OCC Conflict Resolution: "Use Theirs" discards local mutation and accepts server snapshot', async () => {
  const engine = new TestSyncEngine();
  const taskId = 'task-conflict-2';
  const orgId = 'org-alpha';

  const op = {
    id: 'op-put-2',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'Local Overwrite Attempt', expectedVersion: 1 },
    dirtyFields: ['title'],
    needsAttention: true,
    remoteSnapshot: { id: taskId, title: 'Server Authoritative Title', version: 3 },
    timestamp: 1000,
  };
  engine.operations.push(op);

  let appliedServerData = null;
  engine.resolveConflictUseTheirs(op, (serverData) => {
    appliedServerData = serverData;
  });

  // Local queue should now be empty (operation cleanly discarded)
  assert.strictEqual(engine.operations.length, 0);
  assert.strictEqual(appliedServerData.title, 'Server Authoritative Title');
  assert.strictEqual(appliedServerData.version, 3);
});

test('OCC Conflict Resolution: "Keep Mine" adopts latest server version and clears attention state', async () => {
  const engine = new TestSyncEngine();
  const taskId = 'task-conflict-3';
  const orgId = 'org-alpha';

  const op = {
    id: 'op-put-3',
    entityType: 'task',
    entityId: taskId,
    orgId,
    operation: 'PUT',
    payload: { title: 'My Essential Offline Change', expectedVersion: 1 },
    dirtyFields: ['title'],
    needsAttention: true,
    lastError: 'Conflict: server has newer changes',
    remoteSnapshot: { id: taskId, title: 'Remote Intervening Change', version: 5 },
    timestamp: 1000,
  };
  engine.operations.push(op);

  engine.resolveConflictKeepMine(op);

  // Operation should be updated with expectedVersion: 5 and restored to pending
  assert.strictEqual(engine.getPendingOperations().length, 1);
  assert.strictEqual(engine.getAttentionOperations().length, 0);
  assert.strictEqual(op.payload.expectedVersion, 5);
  assert.strictEqual(op.needsAttention, false);
  assert.strictEqual(op.lastError, undefined);
  assert.strictEqual(op.remoteSnapshot, undefined);

  // Next sync should succeed now that expectedVersion matches server
  let updatedPayload = null;
  const mockApi = {
    updateTask: async (id, payload) => {
      updatedPayload = payload;
      return { success: true };
    },
  };

  await engine.processOperation(engine.getPendingOperations()[0], mockApi);
  assert.strictEqual(engine.operations.length, 0);
  assert.strictEqual(updatedPayload.expectedVersion, 5);
  assert.strictEqual(updatedPayload.title, 'My Essential Offline Change');
});

test('Network Resiliency: transient 503 errors increment retryCount without marking attention', async () => {
  const engine = new TestSyncEngine();
  const op = {
    id: 'op-transient-1',
    entityType: 'task',
    entityId: 'task-temp',
    orgId: 'org-1',
    operation: 'PUT',
    payload: { title: 'Retry Test', expectedVersion: 2 },
    timestamp: 1000,
  };
  engine.enqueue(op);

  const mockApi = {
    updateTask: async () => {
      const err = new Error('Service Unavailable (503)');
      err.status = 503;
      throw err;
    },
  };

  await engine.processOperation(engine.getPendingOperations()[0], mockApi);

  // Should NOT be marked as conflict/attention; remains pending with retryCount = 1
  assert.strictEqual(engine.getPendingOperations().length, 1);
  assert.strictEqual(engine.getAttentionOperations().length, 0);
  assert.strictEqual(op.retryCount, 1);
  assert.strictEqual(Boolean(op.needsAttention), false);
  assert.ok(op.lastError.includes('Service Unavailable'));
});
