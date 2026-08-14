# Timebox

Local-only day planner for Android: a proportional timeline you drag by five
minutes, an Inbox of reusable blocks, tasks, habits with streaks, six themes and
five accents. No account, no cloud, no analytics — everything lives on the phone.

Flutter port of the interactive prototype.

## Getting the APK without installing anything

Every push to `main` builds a release APK on GitHub:

1. Open the **Actions** tab of this repository.
2. Pick the newest **Build APK** run.
3. Download `timebox-apk` from **Artifacts** — or grab the APK from the
   **Releases** page, where each build is attached automatically.
4. Copy it to the phone and open it. Android will ask you to allow installing
   from this source once.

The workflow generates the `android/` folder itself (`flutter create`), so no
Gradle binaries are committed. `android_overrides/AndroidManifest.xml` is copied
over the generated one to add the notification, exact-alarm and biometric
permissions.

## Building locally

```bash
flutter create --platforms=android --org com.timebox --project-name timebox .
cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
flutter pub get
flutter run            # or: flutter build apk --release
```

`minSdk` must be 23 or higher for biometrics, and `MainActivity` must extend
`FlutterFragmentActivity` (the workflow does both automatically).

## What lives where

| Area | File |
| --- | --- |
| App shell, onboarding, lock screen, bottom nav | `lib/main.dart` |
| State, persistence, day roll-forward, timeline layout | `lib/store.dart` |
| Data classes and time formatting | `lib/models.dart` |
| Six themes, five accents, block colours | `lib/theme.dart` |
| Shared widgets (panels, switches, segmented, pills) | `lib/ui.dart` |
| Notifications, biometrics, JSON backup | `lib/services.dart` |
| Block / task / habit editors, icon picker, time stepper | `lib/sheets.dart` |
| Proportional timeline, drag, action bar | `lib/screens/timeline.dart` |
| Inbox, tasks, habits + stats, settings | `lib/screens/*.dart` |

## How the timeline works

Empty time takes real height: one minute is a fixed number of pixels, so a
three-hour gap looks like three hours. Long-press a block to pick it up — it
moves in five-minute steps and a badge shows the offset (`+45m → 9:45 AM`);
drop it on the bin to delete. A short tap selects it and opens the action bar
with `−15 / −5 / +5 / +15` for both the start time and the length.

Settings → Timeline switches to a classic evenly-spaced list, and
"Hours on screen" changes the zoom.

## Real Android behaviour

- **Notifications** — block alerts (at start, at end, 15m/30m/1h before), task
  reminders, daily habit nudges and one optional daily summary, all scheduled as
  exact alarms and rebuilt whenever the plan changes.
- **Biometric lock** — optional fingerprint or face unlock on launch.
- **Backup** — export the whole state as one JSON file you keep yourself, and
  restore it from any file.
- **Day roll-forward** — the plan carries to the new day, whether the app was
  closed for a week or left open past midnight.
