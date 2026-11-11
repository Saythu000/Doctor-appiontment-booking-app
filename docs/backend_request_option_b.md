# Backend request: let the mobile app get the API token without a WebView

**From:** mobile team (DrGodly patient app, Flutter, Android)
**To:** IAM / backend team
**Status:** waiting for the backend team's answer

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
