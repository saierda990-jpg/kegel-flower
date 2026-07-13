# Snooze Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve an active countdown when the user closes the popover before the reminder is due, while retaining a 10-minute snooze after an active reminder.

**Architecture:** `StatusCoordinator` owns the popover callback and has access to both its visibility and `KegelSession.mode`. The callback will close the popover in all cases, and call `KegelSession.snooze(minutes: 10)` only when the session is in `.reminding` mode. The session's existing scheduler remains unchanged.

**Tech Stack:** Swift, AppKit, SwiftUI, XCTest.

## Global Constraints

- The configured reminder interval remains the source of truth for normal scheduling.
- A pre-reminder `稍后` action must not modify `KegelSession.nextReminderAt`.
- A reminder-context `稍后` action schedules the next reminder 10 minutes from the action.

---

### Task 1: Separate pre-reminder popover dismissal from reminder snoozing

**Files:**
- Modify: `Sources/KikuKegel/StatusCoordinator.swift:718-724`
- Test: `Tests/KegelSessionTests.swift`

**Interfaces:**
- Consumes: `KegelSession.mode: ReminderMode`, `KegelSession.snooze(minutes: Int)`, `NSPopover.close()`.
- Produces: `snoozeFromPopover()` that preserves the schedule outside `.reminding`.

- [ ] **Step 1: Write the failing test**

Add an XCTest proving that a non-reminding session's schedule is not altered by the decision boundary represented by the new condition. The test will exercise an extracted package-visible helper if one is needed to avoid constructing `StatusCoordinator`.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter KegelSessionTests`

Expected: FAIL because the new decision boundary does not exist.

- [ ] **Step 3: Write the minimal implementation**

Change `snoozeFromPopover()` to close the popover and return unless `session.mode == .reminding`; retain the current timer-throttling assignments and `session.snooze(minutes: 10)` within the reminding branch.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `swift test --filter KegelSessionTests`

Expected: PASS.

- [ ] **Step 5: Run the full test suite and build**

Run: `swift test`

Expected: PASS with exit code 0.
