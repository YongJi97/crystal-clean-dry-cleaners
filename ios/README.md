# Crystal Clean iOS

SwiftUI app for services, pickup requests, local request history, and a saved profile. Bundle id `com.yongji97.crystalclean`, iPhone only, portrait, iOS 17.

This machine cannot build iOS. Generate the Xcode project, then build on a Mac.

## Generate and test

```bash
cd ios
xcodegen generate
xcodebuild -project CrystalClean.xcodeproj -scheme CrystalClean -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`xcodegen generate` reads `project.yml` and writes `CrystalClean.xcodeproj` (one shared scheme, `CrystalClean`, plus the `CrystalCleanTests` unit-test target). That project is gitignored; generate it locally.

If the simulator name differs, list destinations with `xcrun simctl list devices available`.

Copy the API key before a Live or test-mode run:

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Set APP_API_KEY to the same value as the server. The file is gitignored.
```

## Launch arguments

Debug uses the mock service and does not touch the network.

| Argument | What it does |
| --- | --- |
| *(none)* | Debug: mock submit. Release: live production bridge only. |
| `-useLocalBridge` | Debug only. Posts to `http://localhost:3015` with `is_test: true` and `X-Test: 1`. |
| `-testMode` | Debug only. Live client against `https://www.crystalcleandrycleaner.com`, still marked as a test. Ignored in Release. |
| `-startTab services` \| `pickup` \| `requests` \| `profile` | Debug only. Opens that tab. Ignored in Release. |
| `-seedDemo` | Debug only. Shows one fake request named `[TEST] Demo` created yesterday, with address line 2 `Apt 2B` and a preferred time of tomorrow at 10:00 stored as a formatted date. Nothing is written to disk. |
| `-showConfirmation` | Debug only. Opens Request Pickup on the confirmation screen with reference `test-demo`. |

Both `-useLocalBridge` and `-testMode` send `is_test: true` and prefix the name with `[TEST] `. The app posts only to the bridge. The bridge forwards that request to Formspree for app callers, adds `_subject` `[TEST] Pickup request — please ignore`, and does not create a Square order.

Release ignores `-useLocalBridge`, `-testMode`, `-seedDemo`, `-showConfirmation`, and `-startTab` even if they are passed. A Release build sends the seven real fields and does not set `is_test`. The home-screen icon and the shop card use the square crystal mark.

The scheme lists `-useLocalBridge` and `-testMode` unchecked. Enable one in the scheme editor, or pass it to `xcodebuild`:

```bash
xcodebuild -project CrystalClean.xcodeproj -scheme CrystalClean \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Run arguments are for the Run action, not the unit tests. The unit tests do not post anywhere.

## What the app does

- **Services & Prices** loads `https://www.crystalcleandrycleaner.com/data/services.json`, caches it on disk, and falls back to the bundled copy.
- **Request Pickup** is the same seven fields as the website. Name, phone, address, and time are required (marked with *). Time is either ASAP, sent as the word ASAP, or a picked date. Email, apartment, and notes are optional. Phone validation matches the site: 10 digits, or 11 starting with 1. Send stays off until those required fields are valid. iOS contact AutoFill is enabled on the form and profile. Address suggestions come from MapKit, biased around the shop, and a tap fills the full address. The form posts only to the bridge. **Request received** is shown only when the bridge reports both `square_ok` and `notify_ok`. If the ticket was saved but the shop alert failed, the app keeps the reference in history and asks you to call 646-338-6883 instead of sending the form again.
- **My Requests** is local history only. Reorder copies a past request into the form.
- **Profile** stores name, phone, email, address, and address line 2 on the phone.
- A fully successful submit schedules a local notification. A ticket whose shop alert failed does not. There is no push registration.
