# Privacy Policy for MailApp

**Last updated: [DATE — fill in when you publish this]**

This policy covers MailApp for macOS and iOS ("the App"), published by [YOUR NAME / ENTITY]. Replace every `[bracketed]` placeholder before publishing, then host this page at a public URL — you'll need that URL for both Apple's App Store Connect listing and Google's OAuth verification.

## What data the App accesses

- **Gmail data.** When you connect a Gmail account, the App uses Google's Gmail API to read your messages, labels, and folders, and to perform actions you initiate (archive, delete, flag, send, mark read/unread). This requires the `gmail.modify` scope, which covers everything except permanently deleting mail.
- **Account identity.** Signing in with Google or Sign in with Apple gives the App your name, email address, and profile photo (if available), used only to identify you within the App.
- **App settings.** Your signature, theme preference, sync interval, and favorite mailboxes are stored in our backend (Firebase) so they follow you across your devices.

## How your data is used and stored

- **Local cache.** Message headers, snippets, bodies, and attachment metadata you've opened are cached on-device (via Apple's SwiftData) so the App is fast and works offline. This cache never leaves your device except to be re-synced from Gmail.
- **Firebase.** Your app settings (signature, theme, sync interval, favorite mailboxes) are stored in Firebase Firestore, associated with your account identity. Firebase Authentication stores the minimum identity information needed to sign you in.
- **No ad tracking, no data sale.** The App does not sell your data, does not show ads, and does not share your data with third parties except as required to provide the App's functionality (Google's Gmail API, Firebase).
- **Attachments.** When you download an attachment, it's temporarily written to your device's local storage so it can be previewed or shared; it is not uploaded anywhere else by the App.

## Google API Services User Data Policy

MailApp's use and transfer of information received from Google APIs to any other app will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

Specifically:
- The App only requests the Gmail scopes needed for the features described above.
- Gmail data is used solely to provide those features to you, the signed-in user.
- Gmail data is not used for advertising, is not sold, and is not used to train generalized AI/ML models.
- Humans do not read your Gmail data except: (a) with your explicit consent, (b) to investigate a security incident or comply with law, or (c) for the App's own internal operations, where the data has been aggregated and anonymized.

## Your controls

- You can disconnect a Gmail account at any time from within the App, which deletes its locally cached messages and removes its stored credentials.
- You can revoke the App's access at any time via your [Google Account permissions page](https://myaccount.google.com/permissions).
- You can request deletion of your Firebase-stored settings by contacting us at the address below.

## Data retention

- Locally cached mail is retained on-device until you remove the account or delete the App.
- Firebase-stored settings are retained until you request deletion or delete your account.

## Children's privacy

The App is not directed at children under 13 (or the minimum age required by your country), and we do not knowingly collect data from them.

## Changes to this policy

We may update this policy from time to time; the "Last updated" date above reflects the most recent revision.

## Contact

Questions about this policy or your data: **[YOUR SUPPORT EMAIL]**
