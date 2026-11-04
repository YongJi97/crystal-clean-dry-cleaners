# Crystal Clean iOS plan

The app in `ios/` is a SwiftUI client for the existing pickup site. It does not replace the website.

## Screens

A portrait iPhone tab bar:

1. **Services & Prices** — fetch `https://www.crystalcleandrycleaner.com/data/services.json`, cache the response, and use the bundled `services.json` when the phone is offline.
2. **Request Pickup** — name, phone, email, address, address line 2, when, and notes. Name, phone, address, and when are required, matching the website; email, address line 2, and notes are optional. When can be ASAP, which is sent as the word ASAP, or a picked date. Phone validation matches the site (10 digits, or 11 digits starting with 1). The form opens with the saved profile and can suggest addresses from MapKit. After the bridge accepts both the ticket and the shop alert, a confirmation screen shows the bridge `reference_id`. If the ticket was created but the alert failed, the app saves that reference locally and asks the customer to call the shop instead of submitting again.
3. **My Requests** — history stored on the device. Reorder copies that request back into the form.
4. **Profile** — name, phone, email, address, and address line 2.

## Networking

`RequestService` has a live client and a mock.

The live client posts JSON only to `/webhooks/formspree-pickup`, with `X-App-Key` when `APP_API_KEY` is set in the gitignored xcconfig. It does not post to Formspree. The bridge forwards that submission for app callers and returns `square_ok` and `notify_ok`. The confirmation screen is shown only when both are true. The key is not committed.

Debug runs the mock, which reports both channels successful. `-useLocalBridge` points the live client at `http://localhost:3015` and marks the request as a test. `-testMode` uses the production host and also marks the request as a test. Debug also accepts `-startTab services|pickup|requests|profile`, `-seedDemo` (one fake `[TEST] Demo` request dated yesterday, plus a profile, for screenshots), and `-showConfirmation` (opens the confirmation screen on that demo reference). Those launch arguments are ignored in Release. Test requests send `is_test: true`, `X-Test: 1`, and a name prefixed with `[TEST] `. The bridge adds the Formspree `_subject`. Release sends a normal customer request. App references use the `app-pickup-` prefix.

The public price file and the bridge test flag come from the services-and-bridge change. Until that is deployed, prices still load from the bundled file, and a test post to production will not be recognized as a test.

## On this phone

Successful submits append to the local history and schedule a local notification. Status is not read from the server.

## Later

Status tracking and push (a request moving through received, in progress, ready, out for delivery, and completed, with a notification when it changes) can be added once the shop has a place to store that status. This scaffold does not register for push and does not call a status API.
