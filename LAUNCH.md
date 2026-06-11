# Simastry — Launch Checklist

Everything between this build and the App Store, in execution order. The core
app is buildable and test-covered; release still requires configuration,
device QA, App Store setup, and backend hardening — all captured below.
Check items off as you go.

---

## 1. Keys (required before the app works at all)

All keys go into `ios/Simastry/SimastryApp/Config.swift` **at build time —
never commit real values**.

| Key | Where to get it | What breaks without it |
| --- | --- | --- |
| `EXPO_PUBLIC_SUPABASE_URL` | Supabase dashboard → Project Settings → API → Project URL | **Sign-in/sign-up fail entirely** — no user can get past auth |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | Same page → `anon` `public` key | Same as above |
| `EXPO_PUBLIC_REVENUECAT_API_KEY` | RevenueCat dashboard → Project → API keys → Apple App Store key | Purchases SDK never configures — Plus/Pro upgrades dead |
| `EXPO_PUBLIC_TEAM_ID` | Apple Developer → Membership → Team ID | Needed for the AASA file below |

- [ ] Supabase URL + anon key filled
- [ ] RevenueCat key filled
- [ ] RevenueCat products + entitlements created (Plus, Pro) and attached to
      the App Store Connect in-app purchases
- [ ] Sign in with Apple enabled on the Supabase Auth providers page
      (needs the Services ID + key from Apple Developer)

## 2. Deploy the AI channel (10 minutes)

The `companion-reply` edge function proxies Claude so the Anthropic key never
ships in the binary. Code lives at `ios/supabase/functions/companion-reply/`.

```bash
supabase login                       # once
supabase link --project-ref <ref>   # once, from the project's dashboard URL
supabase functions deploy companion-reply
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

Then in `Config.swift`:

```swift
static let EXPO_PUBLIC_LLM_CHAT_ENABLED = "true"
```

This single flag upgrades **Predict, panel chat, 1:1 guide chats, playbook
scripts, and Moments comments** to live Claude generation (model
`claude-sonnet-4-6`), with the template engine as permanent fallback on any
error or timeout. Guides never claim to see photos — the no-vision rule is
baked into the prompts and locked by unit tests.

- [ ] Function deployed, secret set
- [ ] Flag flipped
- [ ] Smoke test on device: one Predict run + one panel message return
      non-template replies (templates rotate from fixed lists — a novel,
      context-specific reply means the channel is live)

## 3. Domain requirements (simastry.com)

- [ ] **Privacy policy** live at `https://simastry.com/privacy` — full,
      reviewable text (the in-app sheet is a summary that links out)
- [ ] **Terms of service** live at `https://simastry.com/terms`
- [ ] **AASA file** served at
      `https://simastry.com/.well-known/apple-app-site-association`
      (content-type `application/json`, no redirect, HTTPS). Without it,
      invite/compatibility universal links open the website instead of the
      app. Ready to paste (replace `TEAMID`):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.app.rork.simastry",
        "paths": ["/share/*"]
      }
    ]
  }
}
```

- [ ] Same file mirrored on `www.simastry.com` (both hosts are in the
      entitlement)
- [ ] After deploy, test: send `https://simastry.com/share/invite/MAYA2626`
      to yourself in Messages and tap it on a device with the app installed —
      it should open the app and grant the welcome predictions

## 4. App Store Connect

- [ ] Create the listing (bundle id `app.rork.simastry`, version 1.0.0 —
      note: bundle id is permanent; "rork" namespace vs "Simastry" branding
      is fine but document it)
- [ ] Update `AppConfig.appStoreURL` once the listing URL exists
      (`ios/Simastry/SimastryApp/AppConfig.swift` — marked with a comment)
- [ ] Screenshots: the debug harness generates every marketing surface —
      `xcrun simctl launch booted app.rork.simastry -SimastryPreviewSeeded
      -SimastryPreviewScreen <screen>` with screens: *(default home)*,
      `astrologists`, `panelChat`, `playbook`, `teamRead`, `moments`,
      `predict`, `recap`, plus the unauthenticated landing
- [ ] App Privacy questionnaire — answer to match
      `PrivacyInfo.xcprivacy`: collects email, user ID, purchase history,
      coarse location; all app-functionality; **no tracking**
- [ ] Age rating: the app includes relationship/astrology entertainment
      content; readings are labeled for entertainment in the in-app terms
- [ ] TestFlight build → internal testing first

## 5. Real-device pass (before submission)

- [ ] Sign in with Apple end-to-end (fresh account)
- [ ] Full onboarding: name → birth chart (real geocoding) → reveal → panel
- [ ] Sandbox purchase of Plus and Pro; restore purchases
- [ ] Universal link tap from Messages (after AASA)
- [ ] Notification permission flow + the 10:30 panel starter and 22h
      prediction follow-up arriving
- [ ] OCR import with a real conversation screenshot
- [ ] Panel chat: 1–3 staggered replies; Moments: comments dripping in
- [ ] Dynamic Type XXXL spot-check on device

## 6. Deferred by design (not forgotten)

| Item | Why deferred | Trigger to revisit |
| --- | --- | --- |
| `aps-environment` entitlement + APNs | All notifications are local | When server-sent push ships |
| Human members in panel threads | Needs group schema + realtime | Backend phase |
| Inviter-side invite rewards | Unverifiable client-side | Backend phase (server-verified redemption) |
| Public Discovery flag | Built, off; needs moderation readiness | When comfortable with UGC exposure |
| Natal-degree storage | Transits are whole-sign today | Onboarding change for orb-precise aspects |
| Team Read share cards | View structured for `ImageRenderer` | Growth pass |
