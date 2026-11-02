# How Gmail surfaces timely information

Research for ConvoMail's timely strip (spec 4.21), November 2, 2026.

**Limit of this research.** I could not run the Gmail app. App behavior below comes from Google's documents and press coverage. Google does not publish how it reads mail without markup or how it finds one-time codes. Screenshots from a real phone are the best check on anything here.

## Summary cards on individual emails

Google shows a card at the top of an email for four kinds of mail, with action buttons. [Google's announcement](https://blog.google/products-and-platforms/products/gmail/new-gmail-summary-cards/):

| Kind | What it offers |
|---|---|
| Purchases | Track package, order details |
| Events | Add to Calendar, invite others, directions |
| Bills | View and pay, remind me, mark as paid, add a due date to Tasks |
| Travel | Manage reservations, check in for flights, hotel check-out times |

Cards combine information from related emails and update as things change. [Smart features](https://support.google.com/mail/answer/15604322?hl=en&co=GENIE.Platform%3DAndroid) must be on: "summary cards above emails (travel, package tracking, and more)" is one of them, and so is showing flight itineraries in Calendar.

## The top of the inbox

- **Happening soon** is a section at the top of the inbox. Google announced it with purchase cards first and more kinds to follow. It appears only when relevant; Google's example is a delivery two days away. Several deliveries stack, and can be expanded, dismissed, or opened ([Google](https://blog.google/products-and-platforms/products/gmail/new-gmail-summary-cards/), [MacRumors](https://www.macrumors.com/2024/10/02/gmail-revamped-summary-cards/)).
- **Packages due within 24 hours** stay at the top of the inbox as of September 2025, each with a tracking button and "More details" ([Droid Life](https://www.droid-life.com/2025/09/11/gmail-adds-new-package-tracking-summary-to-top-of-your-inbox/)).
- **Purchases view** has "Arriving soon" cards in date order, with Track package and More details, above a list of purchase emails. It is for personal accounts ([Gmail Help](https://support.google.com/mail/answer/16624561?hl=en&co=GENIE.Platform%3DDesktop)).
- **Trips at the top of the inbox:** I could not confirm from any source how these appear. Google promised more card kinds in Happening soon. The user has seen this on their phone, so that observation is the reference.

## One-time codes

Reports of the rollout in September 2026 describe a "Copy code" pill on the message row under the subject, in the same area as attachment previews, on Android and iOS. Tapping it copies the code without opening the email ([Android Authority](https://www.androidauthority.com/gmail-copy-2fa-codes-inbox-3713263/)). They describe it on the row, not above the inbox, and none explains how codes are found.

## How Gmail extracts this

- **Markup senders embed.** Mail can carry schema.org data, as JSON-LD or Microdata, anywhere in the HTML ([getting started](https://developers.google.com/gmail/markup/getting-started)).
  - [`ParcelDelivery`](https://developers.google.com/workspace/gmail/markup/reference/parcel-delivery): carrier, item, order, expected arrival, and recommended tracking number and tracking URL.
  - [`FlightReservation`](https://developers.google.com/workspace/gmail/markup/reference/flight-reservation): flight, airports, times, reservation number, check-in URL. Each leg and each passenger is a separate item sharing the reservation number.
  - Outlook [reads the same types](https://devblogs.microsoft.com/microsoft365dev/unlock-your-email-potential-with-schema-org/) for travel and logistics.
- **Automatic processing.** Google says tracking numbers are identified by automatic processing like its spam filtering, and that only the tracking number is shared with carrier partners, for participating US carriers ([Gmail Help](https://support.google.com/mail/answer/13073650?hl=en&co=GENIE.Platform%3DDesktop)). This is where live status comes from.

## What ConvoMail does with this

- **The same markup first,** then rules for mail without it. Everything runs on the device.
- **A strip above the list** on Chats and Feeds, empty unless something is due, with an X on every line. Several items collapse behind "Show more", as Happening soon stacks them. Codes also get Gmail's copy pill on Feeds rows.
- **The emails stay in Feeds,** as Gmail keeps them in Updates. The strip only carries the timely detail.
- **Not possible here:** live carrier status, which needs Gmail's carrier partners or a third-party service. ConvoMail shows dates from the email, updates from later emails, and a link to the carrier's page.
- **No guessing:** a trip or bill whose date cannot be read produces nothing.
