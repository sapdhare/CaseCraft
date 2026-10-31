# CaseCraft product specification

## Brand
Name: CaseCraft
Tagline: Your legal command centre.
Tone: calm, premium, professional.
Palette: deep navy, champagne gold, ivory, slate, restrained green/red status colours.

## Primary navigation
Overview · Cases · Schedule · More

## Case lifecycle
New Case → Active → Hearing → Update Today → Next Date → … → Dispose (Allowed / Rejected)

## Reliability principles
1. Every case mutation persists before the UI reports success.
2. Reminder schedules are rebuilt after case/schedule changes, eliminating stale local notifications.
3. Disposed cases clear future hearings and are retained in history.
4. The recurring schedule detects overlaps across every selected weekday before saving.
5. Backup is user-initiated and includes profile, cases, updates, fees and schedule.
6. No mandatory account/API key means the app is immediately useful offline.
