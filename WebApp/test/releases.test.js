import test from 'node:test';
import assert from 'node:assert/strict';

// Helper functions mirroring Release Planning business logic
function calculateReleaseProgress(issues) {
  const totalIssues = issues.length;
  const doneIssues = issues.filter(t => t.status === 'done' || t.completedAt).length;
  const remainingIssues = Math.max(totalIssues - doneIssues, 0);

  const totalPoints = issues.reduce((acc, t) => acc + (Number(t.storyPoints) || 0), 0);
  const donePoints = issues.reduce((acc, t) => {
    const isDone = t.status === 'done' || t.completedAt;
    return acc + (isDone ? (Number(t.storyPoints) || 0) : 0);
  }, 0);

  const bugs = issues.filter(t => t.taskType === 'bug');
  const criticalBugs = bugs.filter(t => t.bugSeverity === 'critical' || t.priority === 'critical');

  const issuesProgressRatio = totalIssues > 0 ? doneIssues / totalIssues : 0;
  const pointsProgressRatio = totalPoints > 0 ? donePoints / totalPoints : 0;

  return {
    totalIssues,
    doneIssues,
    remainingIssues,
    totalPoints,
    donePoints,
    bugCount: bugs.length,
    criticalBugCount: criticalBugs.length,
    issuesProgressPercent: Math.round(issuesProgressRatio * 100),
    pointsProgressPercent: Math.round(pointsProgressRatio * 100),
  };
}

function buildReleaseNotesMarkdown(release, progress, issues) {
  const lines = [];

  lines.push(`# Release Notes — ${release.name}`);
  if (release.releaseDate) {
    lines.push('');
    lines.push(`_Planned: ${release.releaseDate}_`);
  }
  if (release.status === 'released' && release.releasedAt) {
    lines.push('');
    lines.push(`_Released: ${release.releasedAt}_`);
  }

  if (progress) {
    lines.push('');
    lines.push('## Summary');
    lines.push(`- Issues: ${progress.doneIssues}/${progress.totalIssues} done`);
    lines.push(`- Points: ${progress.donePoints}/${progress.totalPoints} done`);
    lines.push(`- Bugs: ${progress.bugCount} (critical: ${progress.criticalBugCount})`);
  }

  const done = issues.filter(t => t.status === 'done');
  const remaining = issues.filter(t => t.status !== 'done');

  const bullet = (task) => {
    const key = task.issueKey ? `${task.issueKey} — ` : '';
    return `- ${key}${task.title}`;
  };

  if (done.length > 0) {
    lines.push('');
    lines.push('## Completed');
    for (const t of done) {
      lines.push(bullet(t));
    }
  }

  if (remaining.length > 0) {
    lines.push('');
    lines.push('## In Progress / Remaining');
    for (const t of remaining) {
      lines.push(bullet(t));
    }
  }

  return lines.join('\n');
}

function sortReleases(releases) {
  return [...releases].sort((lhs, rhs) => {
    // Unreleased first
    if (lhs.status !== rhs.status) {
      return lhs.status === 'unreleased' ? -1 : 1;
    }
    const d1 = lhs.releaseDate ? new Date(lhs.releaseDate).getTime() : Infinity;
    const d2 = rhs.releaseDate ? new Date(rhs.releaseDate).getTime() : Infinity;
    return d1 - d2;
  });
}

function filterReleases(releases, statusFilter) {
  if (!statusFilter || statusFilter === 'all') return releases;
  return releases.filter(r => r.status === statusFilter);
}

// Tests
test('calculateReleaseProgress computes issue counts and percentages', () => {
  const issues = [
    { id: '1', title: 'Task 1', status: 'done', storyPoints: 5, taskType: 'task' },
    { id: '2', title: 'Task 2', status: 'done', storyPoints: 3, taskType: 'task' },
    { id: '3', title: 'Bug 1', status: 'in_progress', storyPoints: 2, taskType: 'bug', priority: 'critical' },
    { id: '4', title: 'Task 3', status: 'todo', storyPoints: 5, taskType: 'story' },
  ];

  const p = calculateReleaseProgress(issues);
  assert.equal(p.totalIssues, 4);
  assert.equal(p.doneIssues, 2);
  assert.equal(p.remainingIssues, 2);
  assert.equal(p.totalPoints, 15);
  assert.equal(p.donePoints, 8);
  assert.equal(p.bugCount, 1);
  assert.equal(p.criticalBugCount, 1);
  assert.equal(p.issuesProgressPercent, 50);
  assert.equal(p.pointsProgressPercent, 53); // 8/15 = 53.33%
});

test('calculateReleaseProgress handles empty list safely', () => {
  const p = calculateReleaseProgress([]);
  assert.equal(p.totalIssues, 0);
  assert.equal(p.doneIssues, 0);
  assert.equal(p.remainingIssues, 0);
  assert.equal(p.totalPoints, 0);
  assert.equal(p.donePoints, 0);
  assert.equal(p.bugCount, 0);
  assert.equal(p.criticalBugCount, 0);
  assert.equal(p.issuesProgressPercent, 0);
  assert.equal(p.pointsProgressPercent, 0);
});

test('buildReleaseNotesMarkdown formats header, summary, and completed/in-progress bullets', () => {
  const release = {
    id: 'r1',
    name: 'v2.4.0',
    releaseDate: '2026-10-15',
    status: 'unreleased',
  };
  const issues = [
    { id: 't1', issueKey: 'ENG-101', title: 'Time Tracking Parity', status: 'done' },
    { id: 't2', issueKey: 'ENG-102', title: 'Release Planning Views', status: 'in_progress' },
  ];
  const progress = calculateReleaseProgress(issues);

  const md = buildReleaseNotesMarkdown(release, progress, issues);

  assert.match(md, /# Release Notes — v2\.4\.0/);
  assert.match(md, /_Planned: 2026-10-15_/);
  assert.match(md, /## Summary/);
  assert.match(md, /- Issues: 1\/2 done/);
  assert.match(md, /## Completed/);
  assert.match(md, /- ENG-101 — Time Tracking Parity/);
  assert.match(md, /## In Progress \/ Remaining/);
  assert.match(md, /- ENG-102 — Release Planning Views/);
});

test('buildReleaseNotesMarkdown includes released timestamp when finalized', () => {
  const release = {
    id: 'r2',
    name: 'v2.3.0',
    releaseDate: '2026-09-01',
    releasedAt: '2026-09-02',
    status: 'released',
  };
  const issues = [
    { id: 't1', issueKey: 'ENG-90', title: 'Offline Sync Engine', status: 'done' },
  ];
  const progress = calculateReleaseProgress(issues);

  const md = buildReleaseNotesMarkdown(release, progress, issues);

  assert.match(md, /# Release Notes — v2\.3\.0/);
  assert.match(md, /_Released: 2026-09-02_/);
  assert.doesNotMatch(md, /## In Progress/);
});

test('sortReleases sorts unreleased first, then chronological planned dates', () => {
  const r1 = { id: '1', name: 'R1', status: 'released', releaseDate: '2026-08-01' };
  const r2 = { id: '2', name: 'R2', status: 'unreleased', releaseDate: '2026-11-01' };
  const r3 = { id: '3', name: 'R3', status: 'unreleased', releaseDate: '2026-10-01' };

  const sorted = sortReleases([r1, r2, r3]);
  assert.equal(sorted[0].id, '3'); // unreleased earlier date
  assert.equal(sorted[1].id, '2'); // unreleased later date
  assert.equal(sorted[2].id, '1'); // released
});

test('filterReleases filters by status properly', () => {
  const releases = [
    { id: '1', status: 'unreleased' },
    { id: '2', status: 'released' },
    { id: '3', status: 'archived' },
  ];

  assert.equal(filterReleases(releases, 'all').length, 3);
  assert.equal(filterReleases(releases, 'unreleased').length, 1);
  assert.equal(filterReleases(releases, 'released').length, 1);
  assert.equal(filterReleases(releases, 'archived').length, 1);
});
