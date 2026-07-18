# App Store Connect Metadata — Draft

Copy-paste starting point for the App Store Connect listing. Fill in `[bracketed]` items, adjust the copy to taste, then paste into App Store Connect → your app → App Information / Version Information / App Privacy.

## App Information

- **Name** (30 char max): `MailApp` — or something more distinctive if `MailApp` is taken; App Store names must be unique. Consider e.g. "MailApp — Fast Gmail Client".
- **Subtitle** (30 char max): `Fast, native Gmail client`
- **Primary category**: Productivity
- **Secondary category** (optional): Business
- **Bundle ID**: `com.jaeho.mailapp.MailApp` (already set in the Xcode project)
- **SKU**: `mailapp-001` (any unique internal identifier)

## Description (4000 char max)

```
MailApp is a fast, native email client for Gmail, built entirely in SwiftUI for macOS and iOS.

FEATURES
• Unified inbox across multiple Gmail accounts, or switch to any single account
• Flag messages — synced with Gmail's Starred label, so flags match Apple Mail and Gmail itself
• Full HTML message rendering with inline images
• Image and PDF attachment previews, right in the reading pane
• Swipe actions: archive, delete, flag, mark read/unread
• Search across your mail
• Favorite mailboxes for one-tap access to the folders you use most
• Adjustable sync interval
• Settings (signature, theme, favorites) sync across your Mac and iPhone via your account
• Sign in with Google or Sign in with Apple

MailApp connects to Gmail using Google's official API and never stores your Gmail password. Your mail is cached securely on your own device for speed and offline access.

[Add 2-3 more sentences on what makes this app worth downloading vs. Apple Mail / Gmail app]
```

## Keywords (100 char max, comma-separated, no spaces after commas)

```
email,gmail,mail client,inbox,productivity,swiftui,native mail,unified inbox
```

## URLs

- **Support URL**: `[e.g. https://yourdomain.com/support or a GitHub Issues link]`
- **Marketing URL** (optional): `[your landing page, if you have one]`
- **Privacy Policy URL**: the hosted URL for `docs/PRIVACY_POLICY.md` (see Phase 6 doc for hosting options)

## Age Rating Questionnaire

MailApp doesn't include any of the flagged content categories (violence, gambling, mature themes, etc.) — answer "None" / "No" to all questionnaire items. Expected result: **4+**.

## App Privacy ("Nutrition Label")

Go to App Store Connect → your app → App Privacy → Get Started, and declare data collection matching what the App actually does:

| Data type | Collected? | Linked to identity? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Email Address | Yes | Yes | No | App Functionality (account identity) |
| Name | Yes | Yes | No | App Functionality |
| User ID (Firebase UID) | Yes | Yes | No | App Functionality |
| Other User Content (email messages, cached locally + synced via Gmail API) | Yes | Yes | No | App Functionality |
| Other Usage Data (settings: signature, theme, favorites) | Yes | Yes | No | App Functionality |

Answer "No" to tracking, and "No" to any data used for third-party advertising — this app does neither. Keep this table in sync with `docs/PRIVACY_POLICY.md` if either changes.

## Export Compliance

`ITSAppUsesNonExemptEncryption` is already set to `false` in `MailApp-Info.plist` (the app only uses standard HTTPS/TLS, no custom cryptography), so App Store Connect should skip asking this on each upload. If it still asks: answer "No" to using non-exempt encryption.

## Screenshots

Required sizes as of iOS/macOS App Store submission (verify current requirements in App Store Connect before uploading, Apple updates these periodically):

- **iPhone 6.9" display** (e.g. iPhone 16 Pro Max simulator) — required
- **iPhone 6.5" display** (e.g. iPhone 11 Pro Max / XS Max simulator) — required if you don't provide 6.9" scaled variants automatically
- **iPad 13" display** — only required if you mark the app as supporting iPad
- **Mac** — at least one 1280x800 or larger screenshot if submitting to the Mac App Store; not required for a direct-download DMG

Take these via Xcode Simulator (Cmd+S to save a screenshot) on the required device sizes, showing the unified inbox, an open HTML message, and maybe the sidebar with favorites — whichever best represents the app.

## Version Information (per release)

- **What's New in This Version**: fill in per release once you have a version history worth summarizing.
- **Version number**: bump `MARKETING_VERSION` in Xcode (currently `1.0`) to match what you enter here.
- **Build number**: bump `CURRENT_PROJECT_VERSION` in Xcode (currently `1`) — must increase with every binary you upload, even for the same marketing version.
