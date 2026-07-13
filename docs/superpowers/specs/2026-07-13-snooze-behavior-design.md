# Snooze Behavior Design

## Goal

Keep an active reminder countdown unchanged when the user closes the main popover before a reminder is due. Apply a 10-minute snooze only after a reminder has fired.

## Behavior

- In idle mode, the popover's `稍后` action closes the popover only.
- In reminding mode, the same action schedules the next reminder for 10 minutes from the action time, then closes the popover.
- The reminder-toast and menu snooze actions remain 10-minute snoozes because they are reminder-context actions.
- Starting and completing an exercise continues to schedule the configured full interval.

## Implementation

`StatusCoordinator.snoozeFromPopover()` will branch on `session.mode`. The idle branch closes the popover; the reminding branch retains the existing 10-minute `session.snooze(minutes: 10)` call and related toast throttling. Tests will cover the session scheduling contract and the coordinator-facing decision where practical.

## Acceptance Criteria

With a 45-minute interval and an active countdown, opening and closing the popover through `稍后` does not change `nextReminderAt`. Once a reminder has fired, choosing `稍后` schedules the next reminder approximately 10 minutes later.
