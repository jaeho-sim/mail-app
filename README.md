# Mail App

A native, fast email client for macOS and iOS, built with SwiftUI.

## Overview

- **Platforms:** macOS + iOS (shared SwiftUI codebase)
- **Accounts:** Gmail (Gmail API) at launch; Microsoft/Outlook (Graph API) planned
- **Sync:** Sign in with Google links your account to a backend (Firebase/Supabase) so settings, signatures, and preferences sync across devices
- **UI:** Inspired by Apple Mail's 3-pane layout, with a refined visual layer

## Architecture (planned)

```
MailApp/
  App/              # App entry points (macOS + iOS targets)
  Features/
    Auth/           # Sign in with Google, account linking
    MailEngine/      # Gmail API client, local cache, sync engine
    Sync/           # Backend config sync (Firebase/Supabase)
    Inbox/          # 3-pane UI: sidebar, message list, reading pane
    Compose/        # Compose/reply/forward
  Shared/
    Models/         # Message, Mailbox, Account, UserConfig
    DesignSystem/   # Colors, typography, shared components
  Resources/
```

## Setup

See `SETUP.md` for the full Phase 0 checklist (Xcode, Apple Developer Program, Google Cloud/Gmail API, backend project).

## Status

- [ ] Phase 0: Environment & accounts
- [ ] Phase 1: Architecture & data layer
- [ ] Phase 2: Auth & sync foundation
- [ ] Phase 3: Core mail engine (Gmail)
- [ ] Phase 4: UI
- [ ] Phase 5: Performance & reliability
- [~] Phase 6: Shipping — Mac notarized DMG (Firebase Storage) + iOS public App Store (see `docs/PHASE6-SHIPPING.md`)
- [ ] Phase 7: Post-launch (Microsoft/Outlook support)
