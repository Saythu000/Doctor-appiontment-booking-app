# Backend request: let the mobile app get the API token without a WebView

**From:** mobile team (DrGodly patient app, Flutter, Android)
**To:** IAM / backend team
**Status:** waiting for the backend team's answer (see also §6 JWT size and §7 store rules)

---

## 1. Summary

The patient app signs in with **OAuth 2.0 + PKCE**. After sign-in, it needs the
**Better Auth JWT** (`GET /api/auth/token`), because that is the only token the
FHIR API and the AI agents accept.

`/api/auth/token` only works with the IAM **session cookie**. The recommended
mobile login (Chrome Custom Tabs, as the patient API guide §1 says) keeps that
cookie inside Chrome, where the app cannot read it.

So today the app has to run the IAM login page inside an **in-app WebView** and
read the session cookie from it (Option A, now implemented). That works, but it
goes against the guide and RFC 8252 (native apps should use the system browser).

**We ask the backend to provide a way to get an accepted API token from the
OAuth tokens alone (Option B), so the app can return to Custom Tabs.**

---

## 2. What we tested (2026-11-11, real Android phone)

| Call | Credential sent | Result |
|---|---|---|
| `POST /api/auth/oauth2/token` (code + PKCE verifier) | — | 200: `access_token`, `refresh_token`, `id_token` |
| `GET /api/auth/oauth2/userinfo` | `Bearer <access_token>` | 200: user data |
| `GET /api/auth/token` | `Bearer <access_token>` | **401** `{"message":"Unauthorized","code":"UNAUTHORIZED"}` |
| `GET fhirgql.drgodly.com/api/v1/patients/me` | `Bearer <id_token>` | **401** |
| `GET fhirgql.drgodly.com/api/v1/...` | no token | 401 `{"detail":"Missing authentication token"}` |
| `GET fhirgql.drgodly.com/api/v1/...` | invalid token | 401 `{"detail":"Invalid token"}` |
| `POST agents.drgodly.com/api/agent/intake` | no token | 401 `{"detail":"Missing authentication token"}` |
| `GET /api/auth/token` | `Cookie: __Secure-better-auth.session_token=…` | 200: Better Auth JWT (from the earlier WebView build; this is what Option A uses) |

From our earlier implementation notes, the two tokens differ:

| | OAuth `id_token` | Better Auth JWT (`/api/auth/token`) |
|---|---|---|
| `aud` | the mobile OAuth client id | `https://iam.drgodly.com` |
| `permissions` | missing | present (`patient:read`, `vitals:create`, …) |
| `activeOrganizationId` | missing | present |
| Accepted by FHIR / agents | no | yes |

---

## 3. What we need (any one of these is enough)

### Option B1: `/api/auth/token` accepts the OAuth access token
Let `GET /api/auth/token` accept `Authorization: Bearer <OAuth access_token>`
from the mobile client and return the same Better Auth JWT (with
`permissions` and `activeOrganizationId`) that the cookie returns today.

*App change afterwards:* the smallest. One line in `mintBetterAuthJwt`, and
login moves back to Custom Tabs.

### Option B2: a token-exchange endpoint
Add an endpoint (for example RFC 8693 Token Exchange) that takes the OAuth
`access_token` and returns the Better Auth JWT.

*App change afterwards:* small (call the new endpoint instead of `/api/auth/token`).

### Option B3: FHIR and the agents accept the OAuth tokens
Have the OAuth server issue a JWT access token (or `id_token`) that carries
`permissions` and `activeOrganizationId`, and configure the FHIR gateway and
`agents.drgodly.com` (REST and the `/ws/audio` WebSocket) to accept it,
including its audience and signing key.

*App change afterwards:* small (send the OAuth token directly).

---

## 4. Questions for the backend team

1. Which of B1, B2 or B3 do you prefer, or is there another supported way for a
   native app that signs in through the system browser?
2. Will the token the app receives carry `activeOrganizationId` for patient
   accounts? The app sends it as `org_id` on every list and create call (guide §2).
3. How long is the resulting token valid, and how should the app renew it: with
   the OAuth `refresh_token` and then the same exchange again?
4. Is `offline_access` (refresh tokens) enabled for the mobile OAuth client?
5. Do `/api/intake/*` on `app.drgodly.com` and the voice WebSocket
   (`wss://agents.drgodly.com/ws/audio?token=…`) accept the same token?
6. Can sign-out end everything (`/api/auth/oauth2/revoke`, and end-session if it
   gets enabled for the mobile client)?

---

## 5. What the app does today (Option A, temporary)

- Login page: an in-app WebView (`lib/features/auth/presentation/oauth_webview_screen.dart`).
  The cookie store is emptied before every sign-in, only `https` pages may load,
  and the app adds no JavaScript to the page.
- After the OAuth redirect, native code (`MainActivity.kt`, channel
  `com.drgodly.app/iam_session`) returns **only** the IAM session cookie, not the
  rest of the cookie jar.
- The cookie is kept in encrypted storage (Android Keystore) and used only for
  `GET /api/auth/token`, to mint a fresh JWT whenever the old one expires.
- Sign-out deletes the cookie, empties the WebView cookie store, calls
  `POST /api/auth/sign-out` with the cookie, and revokes the OAuth refresh token.

### Why we want to move away from it
- RFC 8252 and the patient API guide recommend the system browser, not a WebView.
- In a WebView the app could technically see the login page (we don't, but the
  user cannot verify that). Google sign-in, if added later, is blocked in WebViews.
- The app has to store a long-lived session cookie, which is a stronger
  credential than an OAuth refresh token.

### Switching back once the backend is ready
1. `AuthRepository.signInWithPKCE`: open the authorize URL with `FlutterWebAuth2`
   (Custom Tabs) again; the package is still a dependency.
2. Mint or receive the API token in the way the backend chose (B1, B2 or B3).
3. Remove `OAuthWebViewScreen`, the `com.drgodly.app/iam_session` channel in
   `MainActivity.kt`, the stored session cookie and the `webview_flutter` package.

---

## 6. JWT size: second backend request

**Found on 2026-11-11 (real phone).** After Option A fixed the 401 errors, every
API call failed with `400 Request Header Or Cookie Too Large` (nginx/1.24.0).

| Measurement | Value |
|---|---|
| Better Auth JWT from `GET /api/auth/token` | **9,321 chars** |
| Largest claim: `apps` | 4,366 chars |
| Next: `permissions` | 88 items, 2,030 chars |
| nginx limit for one HTTP/1.1 header line (fhirgql, agents, app.drgodly.com) | about 8 KB (an 8,100-char token passes, 9,300 fails) |
| Same 9,300-char header over HTTP/2 (curl) | accepted |

The token's contents are set by IAM, not by the app. The app only calls
`GET /api/auth/token`.

**App workaround (commit `d532a2a`):** REST calls (FHIR, intake, auth) now go
through `NativeHttpAdapter` (OkHttp on Android, HTTP/2 with header compression).

**Still at risk:** the voice WebSocket (`wss://agents.drgodly.com/ws/audio?token=<jwt>`)
uses `WebSocketChannel`, not the OkHttp bridge. The token is in the URL and the
WebSocket upgrade is HTTP/1.1, so voice can still hit the 8 KB limit. Any other
client (web, iOS, scripts) on HTTP/1.1 will hit it too.

**Please do one of these (both is best):**
1. nginx on `fhirgql`, `agents` and `app.drgodly.com`:
   `large_client_header_buffers 4 32k;` then reload. Check with
   `curl --http1.1` and a 9.3 KB `Authorization` header.
2. Make the JWT smaller: remove the `apps` claim (and anything else the APIs
   don't read) from the IAM JWT payload.

---

## 7. Store and policy rules

### 7.1 Why we still ask for Option B
Google Play has **no rule against** a WebView login page for our own server, so
Option A will not get the app rejected on its own. We prefer Option B because:

1. **RFC 8252 (OAuth 2.0 for Native Apps)** says native apps must not run the
   login page in an embedded WebView. They should use the system browser.
2. **The patient API guide §1** says the same: use Custom Tabs.
3. **Google Sign-In:** Google's OAuth policy blocks Google sign-in inside
   WebViews (`disallowed_useragent`). If "Continue with Google" is added to the
   IAM page, it only works with Custom Tabs, which needs Option B.
4. **Security:** Option A stores the long-lived IAM session cookie on the phone,
   a stronger credential than an OAuth refresh token.

### 7.2 Rules while Option A is in use
- WebView loads only `https` pages. *Today any `https` site is allowed; limiting
  it to `iam.drgodly.com` would be tighter.*
- No JavaScript bridge (`addJavascriptInterface`) and no file access in the
  WebView. Play's security scan flags unsafe WebViews.
- Never log tokens or cookies, not even in debug builds. Log lengths or claim
  names only.

### 7.3 Google Play policies that apply to this app
Checked against the code and `AndroidManifest.xml` on 2026-11-12.

| Rule | What it means for DrGodly | Status |
|---|---|---|
| Health Connect permissions | The app reads 14 Health Connect data types, including `READ_HEALTH_DATA_IN_BACKGROUND`. Fill in the Health Connect declaration in Play Console and justify each type; Google reviews it. Request only the types the app uses. | Manifest and rationale screen present; **declaration to do** |
| Health apps declaration | Required in Play Console (App content) for health and telehealth apps. | **To do** (Console) |
| Health Content and Services policy | A telehealth app with AI intake must not present itself as a diagnosis tool; show clear disclaimers. | **Review wording** |
| Privacy policy | A link is required in the store listing and inside the app (health data, audio, camera). | **Missing in the app** |
| Account deletion | If users can create an account, they must be able to delete it inside the app and through a web link. | **Missing in the app** (backend support needed) |
| Data safety form | Declare all data collected: health data, personal info, voice audio, camera images. State encryption in transit and how deletion works. | **To do** (Console) |
| Sensitive permissions | Ask for `RECORD_AUDIO` and `CAMERA` only when needed, with a clear reason. Justify `SCHEDULE_EXACT_ALARM` (for example, appointment reminders) or remove it. | **Check each** |
| App access | The app is behind a login, so give Google reviewers a working test account. | **At submission** |
| Target API level | Play raises the minimum target SDK every August. The app uses `flutter.targetSdkVersion`; confirm it meets the current requirement. | **Check at release** |
| New personal developer accounts | A closed test with at least 12 testers for 14 days is needed before production. Organisation accounts are exempt. | Depends on account type |

**Most likely to block release:** account deletion and the privacy-policy link.

### 7.4 Questions for the backend team (in addition to §4)
7. Can you raise the nginx header limit or remove `apps` from the JWT (§6)?
8. Is there an API to delete a patient account (IAM user and FHIR data), and a
   web page for deletion requests that we can link in the Play listing?
9. What is the privacy-policy URL we should link in the app and the listing?
