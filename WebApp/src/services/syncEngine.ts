import { api } from './api';

export interface LocalSyncOperation {
  id: string;
  entityType: 'task';
  entityId: string;
  orgId: string;
  operation: 'POST' | 'PUT' | 'DELETE';
  payload?: Record<string, any>;
  dirtyFields?: string[];
  baseSnapshot?: Record<string, any>;
  remoteSnapshot?: Record<string, any>;
  needsAttention?: boolean;
  lastError?: string;
  retryCount?: number;
  timestamp: number;
}

const STORAGE_KEY = 'taskflow_offline_sync_ops';

export function squashSyncOperations(
  queue: LocalSyncOperation[],
  incoming: LocalSyncOperation
): boolean {
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

export class SyncEngine {
  private operations: LocalSyncOperation[] = [];
  private syncing = false;
  private listeners: Set<() => void> = new Set();

  constructor() {
    this.loadFromStorage();
  }

  private loadFromStorage() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        this.operations = JSON.parse(raw);
      }
    } catch {
      this.operations = [];
    }
  }

  private saveToStorage() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.operations));
    } catch {
      // Ignore storage quota errors
    }
    this.notify();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify() {
    this.listeners.forEach((cb) => cb());
  }

  getPendingOperations(): LocalSyncOperation[] {
    return this.operations.filter((op) => !op.needsAttention);
  }

  getAttentionOperations(): LocalSyncOperation[] {
    return this.operations.filter((op) => op.needsAttention);
  }

  isSyncing(): boolean {
    return this.syncing;
  }

  enqueue(op: LocalSyncOperation) {
    squashSyncOperations(this.operations, op);
    this.saveToStorage();
  }

  enqueueTaskCreate(id: string, orgId: string, payload: Record<string, any>) {
    this.enqueue({
      id: crypto.randomUUID ? crypto.randomUUID() : 'op-' + Date.now(),
      entityType: 'task',
      entityId: id,
      orgId,
      operation: 'POST',
      payload,
      timestamp: Date.now(),
    });
  }

  enqueueTaskUpdate(
    id: string,
    orgId: string,
    payload: Record<string, any>,
    dirtyFields: string[] = [],
    baseSnapshot?: Record<string, any>
  ) {
    this.enqueue({
      id: crypto.randomUUID ? crypto.randomUUID() : 'op-' + Date.now(),
      entityType: 'task',
      entityId: id,
      orgId,
      operation: 'PUT',
      payload,
      dirtyFields,
      baseSnapshot,
      timestamp: Date.now(),
    });
  }

  enqueueTaskDelete(id: string, orgId: string) {
    this.enqueue({
      id: crypto.randomUUID ? crypto.randomUUID() : 'op-' + Date.now(),
      entityType: 'task',
      entityId: id,
      orgId,
      operation: 'DELETE',
      timestamp: Date.now(),
    });
  }

  async syncNow(onFinished?: () => void) {
    if (this.syncing) return;
    this.syncing = true;
    this.notify();

    try {
      const pending = this.getPendingOperations();
      for (const op of pending) {
        await this.processOperation(op);
      }
    } finally {
      this.syncing = false;
      this.saveToStorage();
      onFinished?.();
    }
  }

  private async processOperation(op: LocalSyncOperation) {
    try {
      if (op.operation === 'POST') {
        await api.createTask(op.payload as any);
        this.operations = this.operations.filter((o) => o.id !== op.id);
      } else if (op.operation === 'PUT') {
        await api.request(`/api/tasks/${op.entityId}`, {
          method: 'PUT',
          body: JSON.stringify(op.payload || {}),
        });
        this.operations = this.operations.filter((o) => o.id !== op.id);
      } else if (op.operation === 'DELETE') {
        await api.deleteTask(op.entityId);
        this.operations = this.operations.filter((o) => o.id !== op.id);
      }
    } catch (err: any) {
      if (err?.status === 409 || err?.message?.includes('409') || err?.response?.status === 409) {
        // Optimistic Concurrency Conflict detected
        const serverSnapshot = err?.data || err?.response?.data?.data || {};
        op.needsAttention = true;
        op.lastError = 'Conflict: server has newer changes for the same task.';
        op.remoteSnapshot = serverSnapshot;
      } else {
        op.retryCount = (op.retryCount || 0) + 1;
        op.lastError = err?.message || 'Sync failed';
      }
    }
  }

  resolveConflictUseTheirs(op: LocalSyncOperation, onApplied?: (serverData: any) => void) {
    if (op.remoteSnapshot && onApplied) {
      onApplied(op.remoteSnapshot);
    }
    this.discard(op);
  }

  resolveConflictKeepMine(op: LocalSyncOperation) {
    const serverVersion = op.remoteSnapshot?.version || 1;
    if (op.payload) {
      op.payload.expectedVersion = serverVersion;
    }
    op.needsAttention = false;
    op.lastError = undefined;
    op.remoteSnapshot = undefined;
    op.retryCount = 0;
    this.saveToStorage();
    this.syncNow();
  }

  retry(op: LocalSyncOperation) {
    op.needsAttention = false;
    op.lastError = undefined;
    op.retryCount = 0;
    this.saveToStorage();
    this.syncNow();
  }

  discard(op: LocalSyncOperation) {
    this.operations = this.operations.filter((o) => o.id !== op.id);
    this.saveToStorage();
  }

  clearAll() {
    this.operations = [];
    this.saveToStorage();
  }
}

export const syncEngine = new SyncEngine();
