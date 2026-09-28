import test from 'node:test';
import assert from 'node:assert/strict';

// Helper functions mirroring Time Tracking business logic
function calculateEstimateHours(storyPoints) {
  const points = Number(storyPoints || 0);
  return points * 8.0;
}

function validateLoggedHours(hours) {
  const num = Number(hours);
  if (isNaN(num) || num <= 0) {
    return { valid: false, error: 'Hours must be greater than 0' };
  }
  if (num > 24) {
    return { valid: false, error: 'Cannot log more than 24 hours in a single entry' };
  }
  return { valid: true, error: null };
}

function calculateTimeProgress(loggedHours, estimatedHours) {
  const logged = Number(loggedHours || 0);
  const estimated = Number(estimatedHours || 0);
  const ratio = estimated > 0 ? Math.min(1.0, logged / estimated) : 0;
  const isOverEstimate = estimated > 0 && logged > estimated;
  const overageHours = isOverEstimate ? logged - estimated : 0;
  return {
    logged,
    estimated,
    progressPercent: Math.round(ratio * 100),
    isOverEstimate,
    overageHours,
  };
}

function aggregateProjectTimeReport(projectId, timeLogs, tasks, users) {
  const totalHours = timeLogs.reduce((acc, log) => acc + Number(log.hoursLogged || 0), 0);

  // Group by user
  const userMap = new Map();
  for (const log of timeLogs) {
    const existing = userMap.get(log.userId) || { userId: log.userId, userName: log.userDisplayName || 'Unknown', totalHours: 0 };
    existing.totalHours += Number(log.hoursLogged || 0);
    userMap.set(log.userId, existing);
  }

  const byUser = Array.from(userMap.values())
    .map(u => ({
      ...u,
      percentage: totalHours > 0 ? Math.round((u.totalHours / totalHours) * 100) : 0,
    }))
    .sort((a, b) => b.totalHours - a.totalHours);

  // Group by task
  const taskMap = new Map();
  for (const log of timeLogs) {
    const task = tasks.find(t => t.id === log.taskId);
    const existing = taskMap.get(log.taskId) || {
      taskId: log.taskId,
      taskTitle: task?.title || 'Unknown Task',
      totalHours: 0,
      estimatedHours: calculateEstimateHours(task?.storyPoints),
    };
    existing.totalHours += Number(log.hoursLogged || 0);
    taskMap.set(log.taskId, existing);
  }

  const byTask = Array.from(taskMap.values())
    .map(t => ({
      ...t,
      isOverEstimate: t.estimatedHours > 0 && t.totalHours > t.estimatedHours,
    }))
    .sort((a, b) => b.totalHours - a.totalHours);

  return {
    projectId,
    totalHours,
    byUser,
    byTask,
  };
}

test('calculateEstimateHours: computes 8 hours per story point', () => {
  assert.equal(calculateEstimateHours(0), 0);
  assert.equal(calculateEstimateHours(1), 8.0);
  assert.equal(calculateEstimateHours(3), 24.0);
  assert.equal(calculateEstimateHours(5), 40.0);
  assert.equal(calculateEstimateHours(null), 0);
  assert.equal(calculateEstimateHours(undefined), 0);
});

test('validateLoggedHours: rejects non-positive or excessive durations', () => {
  assert.equal(validateLoggedHours(0).valid, false);
  assert.equal(validateLoggedHours(-1.5).valid, false);
  assert.equal(validateLoggedHours('abc').valid, false);
  assert.equal(validateLoggedHours(25).valid, false);

  assert.equal(validateLoggedHours(0.5).valid, true);
  assert.equal(validateLoggedHours(4).valid, true);
  assert.equal(validateLoggedHours(24).valid, true);
});

test('calculateTimeProgress: tracks normal and over-budget hours', () => {
  // Normal progress
  const progress1 = calculateTimeProgress(4.0, 8.0);
  assert.equal(progress1.progressPercent, 50);
  assert.equal(progress1.isOverEstimate, false);
  assert.equal(progress1.overageHours, 0);

  // Exact match
  const progress2 = calculateTimeProgress(16.0, 16.0);
  assert.equal(progress2.progressPercent, 100);
  assert.equal(progress2.isOverEstimate, false);

  // Over budget
  const progress3 = calculateTimeProgress(20.0, 16.0);
  assert.equal(progress3.progressPercent, 100);
  assert.equal(progress3.isOverEstimate, true);
  assert.equal(progress3.overageHours, 4.0);

  // Zero estimate
  const progress4 = calculateTimeProgress(5.0, 0);
  assert.equal(progress4.progressPercent, 0);
  assert.equal(progress4.isOverEstimate, false);
});

test('aggregateProjectTimeReport: correctly aggregates hours by user and task', () => {
  const tasks = [
    { id: 'task-1', title: 'Setup auth', storyPoints: 2 }, // 16 hrs est
    { id: 'task-2', title: 'Design database', storyPoints: 1 }, // 8 hrs est
  ];
  const timeLogs = [
    { id: 'l1', taskId: 'task-1', userId: 'u-1', userDisplayName: 'Alice', hoursLogged: 6.0 },
    { id: 'l2', taskId: 'task-1', userId: 'u-2', userDisplayName: 'Bob', hoursLogged: 12.0 },
    { id: 'l3', taskId: 'task-2', userId: 'u-1', userDisplayName: 'Alice', hoursLogged: 4.0 },
  ];

  const report = aggregateProjectTimeReport('proj-1', timeLogs, tasks, []);

  assert.equal(report.totalHours, 22.0);

  // Check user rollup
  assert.equal(report.byUser.length, 2);
  const bob = report.byUser.find(u => u.userId === 'u-2');
  const alice = report.byUser.find(u => u.userId === 'u-1');
  assert.equal(bob.totalHours, 12.0);
  assert.equal(alice.totalHours, 10.0);
  assert.equal(bob.percentage, 55); // 12 / 22 ~ 54.5% -> 55%
  assert.equal(alice.percentage, 45); // 10 / 22 ~ 45.4% -> 45%

  // Check task rollup
  assert.equal(report.byTask.length, 2);
  const task1 = report.byTask.find(t => t.taskId === 'task-1');
  assert.equal(task1.totalHours, 18.0);
  assert.equal(task1.estimatedHours, 16.0);
  assert.equal(task1.isOverEstimate, true); // 18 > 16

  const task2 = report.byTask.find(t => t.taskId === 'task-2');
  assert.equal(task2.totalHours, 4.0);
  assert.equal(task2.estimatedHours, 8.0);
  assert.equal(task2.isOverEstimate, false);
});
