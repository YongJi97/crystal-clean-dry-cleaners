# App Store Connect listing (draft)

Paste these into App Store Connect for version 1.0. Counts include every character. The copy uses only what the app and the public site actually offer.

`privacy.html` was checked against the app and left unchanged. It already says a request can include name, phone, optional email, address, apartment or suite, a preferred time, and notes. The app keeps a profile and request history on the phone until Clear my data. The request is sent to the shop (email through Formspree, a Square ticket, and the owners list). It says the shop does not sell that information and does not use it to track people across other companies' apps or sites.

## Name

Limit 30.

| Option | Text | Count |
| --- | --- | --- |
| Taken, do not use | Crystal Clean | 13 |
| Use this | Crystal Clean Dry Cleaners | 26 |

## Subtitle

Limit 30.

Upper East Side dry cleaner

Count: 27

## Promotional text

Limit 170. This can be changed later without a new build.

Look up prices, save your details on your iPhone, and request a free pickup from our shop at 400 E 87th Street.

Count: 111

## Description

Limit 4000.

Crystal Clean Dry Cleaners is our shop's app for the Upper East Side.

Browse services and prices for dry cleaning, wash and fold, laundered shirts, and tailoring. The list is the same one we publish on our website, and a copy stays on your phone when you are offline. Wash and fold is $1.00 per pound, with a 10 pound minimum.

Request a free pickup. Enter your name, phone number, and address, then choose ASAP or a date and time. Email, apartment or suite, and notes are optional. We pick up and deliver at no charge in the neighborhood.

A profile saved on this iPhone can fill the form for you. Past requests stay on the phone, and Reorder copies one back into the form. Clear my data removes that profile and history from the phone. It does not delete a request the shop has already received.

Call 646-338-6883, or open the shop in Apple Maps or Google Maps.

We are at 400 E 87th Street, New York, NY 10128, open Monday through Saturday, 7:30 AM to 7:00 PM.

There is no account. A request you send goes to the shop so we can confirm your pickup.

Count: 1054

## Keywords

Limit 100. Comma-separated, with no space after a comma.

dry cleaner,laundry,wash and fold,tailoring,pickup,delivery,nyc,upper east side,prices

Count: 86

## Category

- Primary: Lifestyle
- Secondary: Business

This is a customer app for a neighborhood shop, so Lifestyle is primary. Business is the secondary category.

## URLs

- Support URL: https://www.crystalcleandrycleaner.com/
- Marketing URL: https://www.crystalcleandrycleaner.com/
- Privacy policy URL: https://www.crystalcleandrycleaner.com/privacy.html

That privacy URL is the page in this repo, on the same host the app already uses for prices and pickup requests.

## Age rating

Answer None or No on every question. Expected rating: 4+.

- Cartoon or fantasy violence: None
- Realistic violence: None
- Sexual content or nudity: None
- Profanity or crude humor: None
- Alcohol, tobacco, or drug use: None
- Mature or suggestive themes: None
- Horror or fear themes: None
- Medical or treatment information: None
- Gambling: No
- Contests: No
- Loot boxes: No
- Unrestricted web access: No
- User-generated content that other people can see: No. Notes go only to the shop.
- Messaging and chat: No
- Advertising: No

## App Privacy (nutrition label)

Collected data is linked to the user, because it identifies their pickup. It is not used for tracking. Purpose for every type: App Functionality.

The app does not ask for location, contacts, photos, or a tracking permission. Address suggestions use Apple's MapKit. Only the address the person accepts is kept and sent.

| Data type | Collected | Linked to user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Name | Yes | Yes | No | App Functionality |
| Phone number | Yes | Yes | No | App Functionality |
| Email address | Yes, only if they type one | Yes | No | App Functionality |
| Physical address | Yes, including apartment or suite | Yes | No | App Functionality |
| Other user content | Yes: notes, and the requested time | Yes | No | App Functionality |

## Export compliance

No. The app only uses HTTPS. It does not use non-exempt encryption. `ITSAppUsesNonExemptEncryption` is already false in the Info.plist.

## App Review notes

Limit 4000.

No account or login is required.

Please do not submit a casual pickup. Sending the form creates a real request for the shop at 400 E 87th Street. The owners read those requests. If you need to try Send, put the word TEST in Notes so they can ignore it.

You can review the rest without sending: Services and Prices, the pickup form, Profile, Call, and Open in Maps (Apple Maps or Google Maps). Shop phone: 646-338-6883. Hours: Monday through Saturday, 7:30 AM to 7:00 PM.

Count: 472
