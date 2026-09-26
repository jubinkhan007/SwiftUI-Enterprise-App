import test from 'node:test';
import assert from 'node:assert/strict';

function calculatePoints(issues, capacity) {
  const assigned = issues.reduce((acc, t) => acc + (t.storyPoints || 0), 0);
  const cap = capacity || 0;
  const isOver = cap > 0 && assigned > cap;
  const progressPercent = cap > 0 ? Math.min(Math.round((assigned / cap) * 100), 100) : 0;
  return { assigned, cap, isOver, progressPercent, count: issues.length };
}

function filterBacklog(tasks) {
  return tasks.filter((t) => !t.sprintId && !t.completedAt && t.status !== 'done' && t.status !== 'cancelled');
}

function assignTask(task, targetSprintId, newVersion) {
  return {
    ...task,
    sprintId: targetSprintId,
    version: newVersion !== undefined ? newVersion : (task.version || 1) + 1,
  };
}

test('calculatePoints: computes assigned story points and capacity percentage correctly', () => {
  const issues = [
    { id: 't-1', storyPoints: 5 },
    { id: 't-2', storyPoints: 8 },
    { id: 't-3', storyPoints: 3 },
  ];
  const stats = calculatePoints(issues, 20);

  assert.equal(stats.assigned, 16);
  assert.equal(stats.cap, 20);
  assert.equal(stats.isOver, false);
  assert.equal(stats.progressPercent, 80);
  assert.equal(stats.count, 3);
});

test('calculatePoints: flags over-capacity sprints', () => {
  const issues = [
    { id: 't-1', storyPoints: 13 },
    { id: 't-2', storyPoints: 8 },
  ];
  const stats = calculatePoints(issues, 20);

  assert.equal(stats.assigned, 21);
  assert.equal(stats.cap, 20);
  assert.equal(stats.isOver, true);
  assert.equal(stats.progressPercent, 100);
});

test('filterBacklog: filters out assigned or completed issues', () => {
  const tasks = [
    { id: 't-1', title: 'Backlog Item', sprintId: null, status: 'todo' },
    { id: 't-2', title: 'Assigned Item', sprintId: 'sprint-1', status: 'in_progress' },
    { id: 't-3', title: 'Done Item', sprintId: null, status: 'done', completedAt: '2026-09-20T00:00:00Z' },
    { id: 't-4', title: 'Cancelled Item', sprintId: null, status: 'cancelled' },
  ];

  const backlog = filterBacklog(tasks);
  assert.equal(backlog.length, 1);
  assert.equal(backlog[0].id, 't-1');
});

test('assignTask: moves task into sprint and increments version for OCC', () => {
  const task = { id: 't-1', title: 'Groomed Story', sprintId: null, version: 2 };
  const updated = assignTask(task, 'sprint-1');

  assert.equal(updated.sprintId, 'sprint-1');
  assert.equal(updated.version, 3);
});

test('assignTask: moves task back to backlog (null sprintId)', () => {
  const task = { id: 't-1', title: 'Unassigned Story', sprintId: 'sprint-1', version: 3 };
  const updated = assignTask(task, null);

  assert.equal(updated.sprintId, null);
  assert.equal(updated.version, 4);
});
