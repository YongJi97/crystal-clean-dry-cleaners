# Crystal Clean iOS

SwiftUI app for services, pickup requests, local request history, and a saved profile. Bundle id `com.yongji97.crystalclean`, iPhone only, portrait, iOS 17.

This machine cannot build iOS. Generate the Xcode project, then build on a Mac.

## Generate and test

```bash
cd ios
xcodegen generate
xcodebuild -project CrystalClean.xcodeproj -scheme CrystalClean -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`xcodegen generate` reads `project.yml` and writes `CrystalClean.xcodeproj` (one shared scheme, `CrystalClean`, plus the `CrystalCleanTests` unit-test target). The project file is not committed from this environment because XcodeGen is not available here.

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
| *(none)* | Debug: mock submit. Release: live production bridge and Formspree. |
| `-useLocalBridge` | Debug only. Posts to `http://localhost:3015` with `is_test: true` and `X-Test: 1`. |
| `-testMode` | Live client against `https://www.crystalcleandrycleaner.com`, still marked as a test. |
| `-startTab services` \| `pickup` \| `requests` \| `profile` | Debug only. Opens that tab. Ignored in Release. |
| `-seedDemo` | Debug only. Shows one fake past request named `[TEST] Demo` and a fake profile for this launch. Nothing is written to disk. |

Both `-useLocalBridge` and `-testMode` send `is_test: true`, prefix the name with `[TEST] `, and set the Formspree `_subject` to `[TEST] Pickup request — please ignore` so the email and Discord alert are labeled. They still post to Formspree. A test bridge call does not create a Square order once the server build that understands `is_test` is deployed.

Release with no launch argument sends the seven real fields and does not set `is_test`.

The scheme lists `-useLocalBridge` and `-testMode` unchecked. Enable one in the scheme editor, or pass it to `xcodebuild`:

```bash
xcodebuild -project CrystalClean.xcodeproj -scheme CrystalClean \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Run arguments are for the Run action, not the unit tests. The unit tests do not post anywhere.

## What the app does

- **Services & Prices** loads `https://www.crystalcleandrycleaner.com/data/services.json`, caches it on disk, and falls back to the bundled copy.
- **Request Pickup** is the same seven fields as the website, with the same phone rule (10 digits, or 11 starting with 1). It starts from the saved profile. The confirmation reference comes from the bridge. If only Formspree accepts the request, the app shows a `local-` reference so the history row still has an id.
- **My Requests** is local history only. Reorder copies a past request into the form.
- **Profile** stores name, phone, email, address, and address line 2 on the phone.
- A successful submit schedules a local notification. There is no push registration.
