# Enterprise Analytics: Metrics Definition

To ensure "Enterprise Trust," this document defines how every KPI in the platform is calculated. These definitions are stable and rely on the `StatusCategory` (Backlog, Active, Done, Cancelled) rather than custom status names.

## 1. Velocity (Sum of Story Points)
- **Definition**: The total amount of "Work" (Story Points) completed within a specific timeframe or Sprint.
- **Calculation**: `SUM(task.story_points)` where `task.status_category == .done` and `task.completed_at` falls within the period.
- **Explainability**: Sample size `n` = number of tasks; `points` = total.

## 2. Lead Time (Total Time-to-Value)
- **Definition**: The total time from task creation to completion.
- **Calculation**: `completed_at - created_at`.
- **Explainability**: Return `avg`, `p50` (median), and `p90` (worst-case).
- **Filters**: Typically excludes `Cancelled` tasks unless explicitly requested.

## 3. Cycle Time (Process Time)
- **Definition**: The time a task spends in an "Active" state.
- **Calculation**: `completed_at - first_time_entered_active_category`.
- **Source**: Derived from `TaskActivityModel` history.

## 4. Throughput (Delivery Rate)
- **Definition**: The number of tasks completed per unit of time (Day/Week/Sprint).
- **Calculation**: `COUNT(tasks)` where `status_category == .done`.
- **Usage**: Useful for teams with variable story points or those not using points.

## 5. Burndown (Remaining Work)
- **Definition**: The amount of work remaining versus time.
- **Calculation**: `SUM(story_points)` where `status_category != .done` and `status_category != .cancelled`.
- **Historical Base**: Uses `ProjectDailyStatsModel` for fast lookup.

## 6. Workload / Capacity
- **Definition**: Individual assignment load versus a defined "Capacity" (default 8 pts/week).
- **Calculation**: `SUM(story_points)` assigned to user `U` where `status_category == .active`.

---

## Technical Notes
- **materialized stats**: Aggregated nightly into `ProjectDailyStatsModel` for historical trends.
- **precision**: All durations are calculated in seconds and displayed as Days/Hours in UI.
- **privacy**: Metrics are always scoped by `org_id`.
