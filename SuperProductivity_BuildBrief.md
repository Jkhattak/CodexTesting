# Super Productivity — Build Brief

## 0. Project Meta
- **App name:** Super Productivity
- **Primary platform:** iOS 17+ (iPhone first)
- **Secondary platform:** iPadOS (Stage 2 follow-up)
- **Technology stack:** Swift 5.10, SwiftUI, Combine, Core Data with CloudKit sync, WidgetKit, ActivityKit, App Intents, EventKit/Reminders integrations
- **Privacy stance:** Local-first data model with iCloud sync via private CloudKit database and no third-party analytics by default

## 1. Value Proposition
A unified daily timeline that merges calendar events, tasks, habits, focus sessions, and notes—planned and executed in one place.

## 2. MVP Scope (Must Ship)
- **Unified Day View:** Timeline for today's events, scheduled tasks, and habit slots, featuring a Now/Next/Later rail.
- **Tasks:** Create/edit with priority, due date, tags, subtasks, estimated duration, and timeboxing.
- **Auto-Plan:** Fill unscheduled tasks into free calendar gaps while respecting working hours.
- **Habits:** Daily/weekly cadence with streak tracking and reminders.
- **Focus Sessions:** Pomodoro or custom timers with Live Activity support.
- **Quick Add:** Natural-language capture supporting durations, due dates, priorities, projects, and tags.
- **Insights:** Weekly summaries covering completed tasks, focus minutes, and habit streaks.
- **Sync & Integrations:** iCloud sync (Core Data <-> CloudKit) and optional import/read from Apple Calendar & Reminders.
- **Widgets:** Today summary, next task, and start focus widgets.
- **Search:** Global search across tasks, events, habits, and notes.

### Out of Scope for MVP
Shared timelines/collaboration, advanced note attachments, iPad split view, and any non-iOS platforms (web/Android).

## 3. Information Architecture
Primary navigation via `TabView`:
1. **Today:** Unified timeline with contextual rails.
2. **Plan:** Backlog, calendar grid, Auto-Plan actions.
3. **Focus:** Timers and session history.
4. **Inbox:** Unsorted captures for quick triage.
5. **Insights:** Weekly and monthly summaries.
6. **Settings:** Accounts, working hours, notifications, data/export.

Modal & sheet flows:
- QuickAddSheet
- AutoPlanPreview
- TaskDetail
- HabitDetail

Deep links:
- `superprod://task/<id>`
- `superprod://focus/start?minutes=25`

## 4. Core User Stories & Acceptance Criteria
### 4.1 Create & Timebox a Task
- Quick Add accepts title (required) plus optional duration, due date, priority, project, and tags.
- Natural language parsing examples:
  - `"Write report tmrw 3pm 45m high #work"`
  - `"Pay bills due fri 20m low"`
- Result: task appears in Unscheduled or as a timeblock if date and time are provided; drag-and-drop schedules it on the timeline.

### 4.2 Auto-Plan Unscheduled Tasks
- Input: unscheduled tasks with durations.
- Action: Auto-Plan fills gaps between calendar events within configured work hours.
- Priority order: deadline > priority > effort.
- Acceptance: No overlap with events, respects do-not-schedule windows, and presents a preview diff before confirmation.

### 4.3 Habits
- Create habit with cadence (daily/weekday/custom), target (count/minutes), and reminder time.
- Acceptance: Habit chips appear on Today view; completing increments streak, missing breaks the streak.

### 4.4 Focus Session
- Start Pomodoro (25/5) or custom-length timers.
- Acceptance: Live Activity updates Lock Screen/Dynamic Island, logs minutes to Insights, optional auto-start of next task.

### 4.5 Calendar & Reminders
- Connect to Apple Calendar and Reminders (optional write-back to Reminders).
- Acceptance: Calendar events render read-only; tasks can export to Reminders when enabled.

### 4.6 Search
- Global search returns mixed results (tasks/events/habits/notes).
- Acceptance: Opening a result navigates to the correct detail view within 150 ms on median hardware.

## 5. Data Model (Core Data + CloudKit)
### Entities
- **Task**
  - Fields: id(UUID), title(String), notes(String?), status(todo/doing/done), priority(low/med/high), estimateMinutes(Int16), scheduledStart(Date?), scheduledEnd(Date?), dueDate(Date?), project(String?), tags([String]), createdAt(Date), updatedAt(Date), parentTaskID(UUID?), checklist([ChecklistItem])
- **Habit**
  - Fields: id(UUID), title(String), cadence(daily/weekly/custom), targetType(count/minutes), targetValue(Int16), reminderTime(DateComponents?), streak(Int16), lastCompleted(Date?)
- **FocusSession**
  - Fields: id(UUID), taskID(UUID?), start(Date), end(Date?), plannedMinutes(Int16), actualMinutes(Int16), type(pomodoro/custom), notes(String?)
- **Note**
  - Fields: id(UUID), title(String), body(Text), links([LinkRef]), pinned(Bool), createdAt(Date), updatedAt(Date)
- **Settings**
  - Fields: workHoursStart/End(DateComponents), schedulingDays([Weekday]), defaultDuration(Int16), calendarIntegration(Bool), remindersWrite(Bool), theme(Enum), notificationsAllowed(Bool)

### Relationships
- Task has optional parent/child hierarchy, links to notes, and optional associations with focus sessions.
- Habits may relate to focus sessions (for logging).

## 6. Scheduling / Auto-Plan Logic
- **Inputs:** Busy intervals from calendars, work hours window, unscheduled tasks (duration, priority, due date, project).
- **Ordering:** Sort by due date proximity ascending, then priority descending, then estimate descending.
- **Placement:** Apply first-fit decreasing into free slots. Split tasks that exceed a slot if ≥25 minutes remain; otherwise defer to next slot.
- **Constraints:** Keep inside work hours, avoid overlaps, respect user-blocked times.
- **Output:** Tentative placements with start/end times; user confirms via diff sheet before persisting `scheduledStart`/`scheduledEnd`.

## 7. Natural-Language Parsing (Quick Add)
- Duration tokens: `(\d+)(m|min|h|hr)` converted to minutes.
- Date/time keywords: `today`, `tmrw`, weekday names, `3pm`, `14:30`.
- Priority tokens: `low|med|high|p1|p2|p3`.
- Tags: `#tag`.
- Project: `@project`.
- Due date cues: `due fri`, `due 10/21`.
- If only date provided, task lands in Plan tab under Unscheduled.

## 8. iOS Feature Implementations
- **WidgetKit:** Today Overview (small/medium/large), Next Task, Start Focus button.
- **ActivityKit:** Live Activity for focus sessions with remaining time and pause/stop actions.
- **App Intents (Shortcuts):** `AddTask`, `StartFocus`, `CompleteHabit`.
- **Focus Filters:** Ability to mute in-app badges during focus.
- **Spotlight:** Index Task and Habit titles for system search.

## 9. Non-Functional Requirements
- Cold start < 400 ms on A15+ devices.
- Timeline scroll maintains 60 fps with 200+ items.
- Background save after each mutation with periodic JSON auto-export for data loss prevention.
- Full accessibility coverage: Dynamic Type, VoiceOver labels, high-contrast modes, and meaningful haptics.

## 10. Release Considerations & Next Steps
1. **MVP Completion:** Deliver core timeline, task/habit/focus functionality, search, and integrations.
2. **Stabilization:** Harden CloudKit sync, EventKit permissions UX, and performance metrics.
3. **Stage 2 Exploration:** iPadOS layout (Stage 2), richer notes, and collaboration once MVP analytics justify expansion.
4. **Operational Readiness:** Ensure privacy disclosures, onboarding for integrations, and App Intents documentation for Shortcuts users.

