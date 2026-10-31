# CaseCraft — Flutter legal practice command centre

CaseCraft is an offline-first Flutter app for iOS and Android. It works fully without internet, an account or an API key.

## What is ready

- Material 3 UI with responsive phone/tablet navigation.
- Three kinds of matter:
  - **Court case**: client name and mobile, case type, case number, court, judge, opposite party and advocate, sections, hearing dates.
  - **Income tax**: client name and mobile, PAN (format-checked), income-tax portal password (encrypted, hidden behind fingerprint/face/PIN, never exported), ward/office, officer, dates.
  - **Other matter**.
- **Fees**: fee quoted, every payment with its date and note, received total, and remaining (or extra paid). Payments can be added at any time, or entered as "money received today" while updating a hearing.
- **Court transfer**: moves the case to a new court and judge, keeps a transfer history, and adds the transfer to the case timeline.
- Hearing workflow: reminders the day before (9:00), the morning of (8:00) and the evening of (18:30, to record the outcome), plus update history and next-date capture.
- Disposal: Allowed / Rejected, recorded in the case history.
- Recurring weekly schedule with clash detection and optional 30-minute reminders, plus a quick "Before giving a time" check.
- Search by case, client, mobile, PAN, court, judge, section or opponent, with Active / Disposed / All filters.
- Backup to a JSON file and restore (validated before anything is replaced).

## Security

| What | How |
|---|---|
| Data at rest | Every Hive box is AES-256 encrypted. The key is generated on first launch and kept in the Android Keystore / iOS Keychain (`flutter_secure_storage`), never next to the data. Old unencrypted data is moved into the encrypted store once and then deleted. |
| App lock | Optional (More → App lock). Asks for fingerprint, face or phone PIN at launch and after 30 s in the background. It can only be turned on after a successful check, so nobody locks themselves out. |
| Client passwords | Shown masked. Viewing or copying needs fingerprint, face or PIN. Copied passwords are cleared from the clipboard after 30 s. They are never written to a backup. |
| Network | The release Android build has no `INTERNET` permission, so the app can't send data anywhere. |
| OS backups | `allowBackup="false"` plus data-extraction rules keep the encrypted files out of Google cloud backup and device-to-device transfer. A copy restored there could never be decrypted, because the Keystore key doesn't travel with it. |
| Bad input | Amounts, PAN and phone numbers are validated. Every stored or restored record is parsed defensively, so a corrupt or hostile backup can't crash the app. |
| Startup failure | If secure storage can't open, the app shows a clear message instead of crashing, and leaves the data untouched. |

## Data architecture: on the phone vs. the cloud

```
UI (screens) ──► AppState ──► StorageService ──► encrypted Hive (on phone)   ← source of truth
                     │
                     └──────► NotificationService ──► OS alarm scheduler      ← works offline, survives reboot
                     ┊
                     └┈┈┈┈┈┈► (future) SyncService ──► cloud database         ← copy of the data, not the master
```

- **The local database is the master copy.** Every change is written to the encrypted on-device store before the screen says it's saved, so nothing depends on a network.
- **The cloud is a replica, kept separate.** Nothing is synced today. Records are already built for it: every record has a UUID `id`, and each case carries `updatedAt` so a sync can keep the newer copy. Payments, updates and transfers are lists that only grow, so they merge cleanly.
- **Secrets never go to the cloud.** `LegalCase.toMap(includeSecrets: false)`, already used for backups, leaves out PAN passwords. A cloud sync must use the same call.
- **To add cloud sync:** add one `SyncService` that pushes `toMap(includeSecrets: false)` records changed since the last sync, and pulls remote records, keeping the one with the newer `updatedAt`. The app also needs the `INTERNET` permission and sign-in. Pick the provider first (Firebase, Supabase, or your own API).

## Build

Use Flutter 3.47 stable or later.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

GitHub Actions (`.github/workflows/casecraft.yml`) analyzes, tests and builds a release APK plus an unsigned iOS build on every push to `main`. Download the APK from the run's artifacts.

## Release checklist

- Android: the release build is signed with the debug key, which is fine for installing directly but not for the Play Store. For the Play Store, create an upload key, add a `signingConfig`, and change `applicationId` from `com.example.casecraft` to your own ID before the first upload.
- iOS: building, signing and publishing needs a Mac with Xcode and an Apple Developer account.
- Reminders use inexact alarms, so they can arrive a few minutes late when the phone is in deep sleep. Exact alarms need the user-granted "Alarms & reminders" permission on Android 14+.

## Branding

App name: **CaseCraft**
Tagline: **Your legal command centre.**
Visual system: deep navy + champagne gold + ivory.
Logo: `assets/casecraft_logo.svg`.
