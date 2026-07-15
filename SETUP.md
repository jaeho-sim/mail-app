# Phase 0 Setup Checklist

## 1. Install Xcode
- [ ] App Store → search "Xcode" → Install
- [ ] Open Xcode once, accept license, let it install additional components
- [ ] Terminal: `xcode-select --install` (command line tools)

## 2. Apple Developer Program
- [ ] developer.apple.com/programs → Enroll → sign in with Apple ID
- [ ] Choose Individual or Organization
- [ ] Pay $99/year, wait for approval (hours-1 day)
- Note: not required to start coding in the simulator, but required for device testing beyond 7 days and App Store submission

## 3. GitHub repo
- [ ] Create repo (e.g. `mail-app`)
- [ ] Add `.gitignore` (Xcode/Swift template) and `README.md`
- [ ] `git clone` locally, ready for the Xcode project to be added in Phase 1

## 4. Google Cloud + Gmail API
- [ ] console.cloud.google.com → New Project (e.g. "mail-app-dev")
- [ ] APIs & Services → Library → enable "Gmail API"
- [ ] APIs & Services → OAuth consent screen:
  - User type: External
  - App name, support email
  - Scopes: `gmail.readonly` to start (add `gmail.modify` / `gmail.send` later)
  - Add yourself as a test user (keeps you in Testing mode — no Google security review needed yet)
- [ ] APIs & Services → Credentials → Create Credentials → OAuth client ID → type "iOS"
  - Needs your app's Bundle ID (set in Phase 1 when the Xcode project is created)

## 5. Backend project (Firebase or Supabase)
- [ ] Create a free-tier project at firebase.google.com or supabase.com
- Recommendation: Firebase, since Google Sign-In and Firestore integrate natively with the Gmail OAuth flow. Supabase is a fine alternative if you prefer Postgres/SQL.
- No further config needed yet — this happens in Phase 2 (Auth & Sync Foundation)

## Notes
- Google's Gmail API security review (CASA), required before public production release, can take weeks — worth starting once you're near feature-complete on the Gmail scopes you need, not at the last minute.
- Nothing above requires me to have access to your accounts or payment methods — all logins/payments should be done by you directly.
