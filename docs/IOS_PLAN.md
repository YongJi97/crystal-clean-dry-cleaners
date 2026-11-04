# Crystal Clean iOS plan

The app in `ios/` is a SwiftUI client for the existing pickup site. It does not replace the website.

## Screens

A portrait iPhone tab bar:

1. **Services & Prices** — fetch `https://www.crystalcleandrycleaner.com/data/services.json`, cache the response, and use the bundled `services.json` when the phone is offline.
2. **Request Pickup** — name, phone, email, address, address line 2, when, and notes. Phone validation matches the site (10 digits, or 11 digits starting with 1). The form opens with the saved profile. After a successful send, a confirmation screen shows the bridge `reference_id`. If only the Formspree call succeeds, that id is a `local-` value generated on the phone.
3. **My Requests** — history stored on the device. Reorder copies that request back into the form.
4. **Profile** — name, phone, email, address, and address line 2.

## Networking

`RequestService` has a live client and a mock.

The live client posts JSON to `/webhooks/formspree-pickup` with `X-App-Key` when `APP_API_KEY` is set in the gitignored xcconfig, and posts the same fields as form data to Formspree with `Accept: application/json`. The request counts as a success if either call succeeds, matching the website. The key is not committed.

Debug runs the mock. `-useLocalBridge` points the live client at `http://localhost:3015` and marks the request as a test. `-testMode` uses the production host and also marks the request as a test. Debug also accepts `-startTab services|pickup|requests|profile`, `-seedDemo` (one fake `[TEST] Demo` request dated yesterday, plus a profile, for screenshots), and `-showConfirmation` (opens the confirmation screen on that demo reference). Those launch arguments are ignored in Release. Test requests send `is_test: true`, `X-Test: 1`, a name prefixed with `[TEST] `, and Formspree `_subject` `[TEST] Pickup request — please ignore`. Release sends a normal customer request.

The public price file and the bridge test flag come from the services-and-bridge change. Until that is deployed, prices still load from the bundled file, and a test post to production will not be recognized as a test.

## On this phone

Successful submits append to the local history and schedule a local notification. Status is not read from the server.

## Later

Status tracking and push (a request moving through received, in progress, ready, out for delivery, and completed, with a notification when it changes) can be added once the shop has a place to store that status. This scaffold does not register for push and does not call a status API.
