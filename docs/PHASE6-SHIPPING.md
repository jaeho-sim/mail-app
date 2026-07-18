# Phase 6: Shipping — Mac direct download + iOS public App Store

Target: Mac app distributed as a notarized DMG hosted on Firebase Storage (no Mac App Store); iPhone app released publicly on the App Store.

Everything in this doc that's pure code/config is already done (see "Done" below). Everything else needs your Apple Developer / Google Cloud / App Store Connect accounts, which I can't touch directly — this doc is the exact sequence to run through yourself.

## Done (code-side, already in this repo)

- `ENABLE_HARDENED_RUNTIME = YES` added to the macOS build (required for notarization).
- `ITSAppUsesNonExemptEncryption = false` added to `MailApp-Info.plist` (skips the export-compliance prompt on every upload — this app only uses standard HTTPS/TLS).
- `scripts/build_and_notarize_mac.sh` — archives, exports a Developer ID–signed build, notarizes, staples, and packages a DMG.
- `scripts/exportOptions-mac.plist` — export settings for the script above (needs your Team ID filled in — see step 2).
- `scripts/upload_release_to_firebase.py` — uploads the DMG to Firebase Storage and prints a public download link.
- `docs/PRIVACY_POLICY.md` — draft privacy policy, including the Google API Services "Limited Use" disclosure Google requires for Gmail API apps.
- `docs/APP_STORE_METADATA.md` — draft App Store Connect listing copy (description, keywords, App Privacy answers, screenshot requirements).

## 1. Apple Developer Program + Xcode team

- [ ] Finish enrolling at developer.apple.com/programs (you said this is in progress).
- [ ] In Xcode: **MailApp target → Signing & Capabilities → Team** → select your new team, for every configuration (Debug/Release) and every platform.
- [ ] While there, click **+ Capability → Sign in with Apple** now that a paid team is selected — this is what unblocks the Apple Sign-In code that's already written (`AuthManager.swift`) but has been failing with error 1000 until now.

## 2. Mac: notarized DMG on Firebase Storage

**Option A — Xcode GUI (simplest, no scripting):**
1. Product → Archive (with a "My Mac" destination selected).
2. In the Organizer window that opens: **Distribute App → Direct Distribution → Upload**. Xcode signs with your Developer ID certificate, uploads for notarization, and staples the ticket automatically.
3. Once it says "Ready to distribute," click **Export** to get the notarized `.app`.
4. Package it into a DMG yourself: right-click the exported `.app` folder in Finder isn't enough — use Disk Utility ("File → New Image → Image from Folder…") or just run `hdiutil create -volname "MailApp" -srcfolder /path/to/MailApp.app -ov -format UDZO MailApp-1.0.dmg` in Terminal.

**Option B — scripted (repeatable, good once you're shipping updates regularly):**
1. Edit `scripts/exportOptions-mac.plist`, replace `REPLACE_WITH_YOUR_TEAM_ID` with your Team ID (Apple Developer → Membership).
2. One-time: store notarization credentials so the script never touches your password directly:
   ```
   xcrun notarytool store-credentials "AC_NOTARY" \
     --apple-id "your-apple-id@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "an app-specific password from appleid.apple.com"
   ```
3. Run it:
   ```
   cd ~/Workplace/mail-app
   ./scripts/build_and_notarize_mac.sh 1.0
   ```
   Output: `build/MailApp-1.0.dmg`, notarized and stapled.

**Then, upload to Firebase Storage:**
1. Firebase Console → Storage → click "Get Started" once if you've never used Storage on this project before.
2. Firebase Console → Project Settings → Service Accounts → **Generate new private key** → save the JSON file somewhere *outside* this repo, e.g. `~/.secrets/mailapp-firebase-key.json`. This file is already excluded from git via `.gitignore` if you happen to save it inside the repo, but keep it outside to be safe.
3. `pip install --break-system-packages firebase-admin`
4. ```
   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/mailapp-firebase-key.json
   python3 scripts/upload_release_to_firebase.py build/MailApp-1.0.dmg
   ```
5. It prints a public URL like `https://storage.googleapis.com/mail-app-1.appspot.com/releases/MailApp-1.0.dmg` — that's your download link. Put it on your website's download page.

Re-run the upload step (with a new filename per version, e.g. `MailApp-1.1.dmg`) each time you ship an update.

## 3. iPhone: TestFlight → public App Store

1. **App Store Connect → My Apps → +** → create the app record: name, primary language, bundle ID (`com.jaeho.mailapp.MailApp`), SKU. This is where TestFlight and the public listing both live — same app record.
2. **Archive & upload:** Xcode → Product → Archive (destination: "Any iOS Device") → Organizer → **Distribute App → App Store Connect → Upload**.
3. Once processed (an email arrives, usually 15 min–a few hours), it shows up under **TestFlight** in App Store Connect automatically.
4. **TestFlight beta first:** add yourself and a few testers as internal/external testers, verify the build on real devices before going public. This also doubles as your final pre-release check.
5. **Public release:** fill in the App Store listing using `docs/APP_STORE_METADATA.md` as your starting draft (description, keywords, screenshots, App Privacy answers), then submit that build for App Review from the **App Store** tab (not the TestFlight tab) in App Store Connect.
6. Screenshots: run the app in Simulator at the required device sizes (see the doc above) and save screenshots with Cmd+S.

## 4. Privacy Policy — host it somewhere public

Apple and Google both require a live URL, not just a file in this repo. Fill in `docs/PRIVACY_POLICY.md`, then host it via whichever is least friction for you:
- **Firebase Hosting** (fits naturally since you're already on Firebase): `firebase init hosting`, drop the rendered HTML in the `public/` folder, `firebase deploy --only hosting`. Free tier covers this easily.
- **GitHub Pages**, if you'd rather not touch Firebase Hosting.
- Any existing website you control.

Use that URL in both App Store Connect (App Information → Privacy Policy URL) and Google Cloud Console (OAuth consent screen → Privacy Policy link) — see next step.

## 5. Google OAuth verification — the real critical path

This is the part most likely to actually block a *public* release, independent of Apple. Right now the app's Google Cloud OAuth consent screen is almost certainly in **Testing** publishing status, which caps sign-in to 100 manually-added test users — anyone else who downloads the app from the App Store will hit a hard block trying to connect Gmail, not just a warning screen.

To fix that:
1. **Google Cloud Console → APIs & Services → OAuth consent screen.**
2. Add the Privacy Policy URL from step 4, plus a support email and app logo.
3. Click **Publish App** to move from Testing → Production for the non-restricted parts of the flow.
4. Because this app requests `gmail.modify` (a **restricted scope**), Google additionally requires:
   - A **verification review** (they check your app's use of the scope against your privacy policy and requested permissions).
   - A **CASA Tier 2 security assessment** — a third-party security review of your app/backend. Google provides a list of approved assessors and, depending on your case, may cover assessment cost via their program; check the current process at [Google's OAuth API verification FAQ](https://support.google.com/cloud/answer/13463073).
   - You'll likely need to submit a short demo video showing exactly how/why the app uses each requested scope.
5. **Timeline:** this can take **days to several weeks**, and is the main reason to start it now rather than right before you plan to submit to Apple. It does not block TestFlight testing with your existing 100 test users — only a true public release.

## 6. Versioning

- Bump `MARKETING_VERSION` (currently `1.0`) in Xcode for each user-facing release.
- Bump `CURRENT_PROJECT_VERSION` (currently `1`) for **every** binary you upload to App Store Connect, even between the same marketing version.

## Open items / not done here

- **App icon**: `Assets.xcassets/AppIcon.appiconset` exists but needs your actual 1024×1024 artwork dropped in if you haven't already — Apple rejects placeholder/default icons.
- **Screenshots**: not generated — see step 3.6.
- **Actual privacy policy hosting + Google/Apple account setup**: needs your accounts, can't be done from here.
- **Push notifications, Sign in with Apple end-to-end testing**: code is defensive/ready but untested against a real paid-team provisioning profile — worth verifying once your team is selected in Xcode (step 1).
