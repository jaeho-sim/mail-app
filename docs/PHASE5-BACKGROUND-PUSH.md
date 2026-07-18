# Deferred: True Background Refresh + Push Notifications

Phase 5 shipped a foreground "keep fresh" timer (`PeriodicSyncManager`) and Gmail
pagination — both work today with no extra setup. This document is the plan for
the parts that need the Apple Developer Program, which isn't active yet.

## Why this is deferred

- **Background App Refresh** (BGTaskScheduler) technically doesn't require a paid
  account, but is only useful in combination with push (below) — on its own,
  iOS decides when/if to actually run it, and it's not worth the added
  complexity (AppDelegate, Info.plist background modes, actor-crossing task
  handlers) until push is also ready to test end-to-end.
- **Push notifications** need the `aps-environment` entitlement, which requires
  an App ID configured for Push Notifications in the paid Developer Program
  portal. Free/personal team accounts can't provision this — adding the
  capability in Xcode now would likely break signing.
- **Live Gmail push** additionally needs a small server component (below),
  which costs money to run (Firebase Blaze plan, pay-as-you-go).

## The plan, once enrolled

### 1. Client (iOS)
- Add `BGTaskSchedulerPermittedIdentifiers` + `UIBackgroundModes` (`fetch`,
  `remote-notification`) to `MailApp-Info.plist`.
- Enable the "Push Notifications" and "Background Modes" capabilities in
  Xcode's Signing & Capabilities tab (this generates the entitlement + updates
  the provisioning profile automatically once on a paid team).
- Add an `AppDelegate` (`UIApplicationDelegate` for iOS, `NSApplicationDelegate`
  for macOS) to capture the APNs device token and handle incoming remote
  notifications by triggering `MailSyncEngine.shared.syncInbox(...)`.
- Register a `BGAppRefreshTaskRequest` (iOS) via SwiftUI's
  `.backgroundTask(.appRefresh(id))` scene modifier as a fallback for when
  push doesn't fire.

### 2. Server (relay Gmail → APNs)
Gmail doesn't push to APNs directly — it publishes to a Google Cloud Pub/Sub
topic via the `users.watch` API call. A small Cloud Function subscribes to
that topic and forwards to APNs. See `server/functions/src/gmailPushRelay.ts`
for a starting point.

Setup once enrolled:
1. Upgrade the Firebase project to the **Blaze (pay-as-you-go)** plan —
   Cloud Functions + Pub/Sub aren't available on the free Spark plan. This
   has real (usually small, but non-zero) cost — your call when you're ready.
2. Create a Pub/Sub topic (e.g. `gmail-inbox-updates`) and grant
   `gmail-api-push@system.gserviceaccount.com` publish rights to it.
3. Call `users.watch` (Gmail API) per connected account, targeting that topic
   — this needs to be renewed every ~7 days, so it should run from a scheduled
   Cloud Function too.
4. Deploy `gmailPushRelay.ts`, which receives the Pub/Sub message, looks up
   the user's stored APNs device token (in Firestore), and sends a silent
   push via APNs (using a `.p8` auth key from the Developer Program portal).
5. The client's `didReceiveRemoteNotification` handler then calls
   `MailSyncEngine.shared.syncInbox(...)` to pull the actual new messages.

Nothing here needs to happen until Phase 6 (Apple Developer Program
enrollment) is done — flagging it now so the shape of the work is clear.
