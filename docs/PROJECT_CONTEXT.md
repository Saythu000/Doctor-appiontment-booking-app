# DrGodly Patient App — Project Context

**Repository Path:** `/home/mi/Desktop/AI_projects/phia_flutter`  
**Flutter SDK:** 3.44.0 (Dart 3.12.0)  
**Package Name / App ID:** `com.drgodly.app`

---

## 1. What It Is
- Android application built with Flutter. Telehealth + wearable vitals for patients.
- Core user features:
  - Sign in via OAuth 2.0 PKCE (System Browser / Custom Tabs)
  - Book doctor consultations (video or in-person)
  - Pre-visit AI clinical health intake via interactive chat or real-time voice
  - Vitals monitoring aggregated from smartwatches through Android Health Connect
  - Medication & vitals measurement reminders with notifications
- Connected Backends (All HTTPS, Bearer JWT, `org_id` on every request):
  - **IAM** (`iam.drgodly.com`): OAuth 2.0 + PKCE login, tokens, organizations
  - **FHIR Gateway** (`fhirgql.drgodly.com`): `/api/v1/` patients, practitioner-roles, slots, appointments, vitals
  - **DrGodly Web App** (`app.drgodly.com`): `/api/intake/*`, `/api/consultation/create`
  - **AI Agents** (`agents.drgodly.com`): `/api/agent/intake` (streaming), `/api/agent/assessment`, `wss://agents.drgodly.com/ws/audio` (real-time voice)

---

## 2. Architecture & Standards
- **Feature-First Structure**:
  - `lib/app`: `app.dart`, `router.dart`, `app_routes.dart`
  - `lib/core`: `config/`, `network/` (`FhirApiClient` with JWT + 401 single-flight refresh), `data/local/` (SQLite + encrypted secure storage), `theme/`, `widgets/`
  - `lib/features/<feature>/{data, domain, presentation}`
  - Features: `auth`, `onboarding`, `home`, `vitals`, `booking`, `intake`, `profile`, `settings`, `notifications`, `splash`
- **Design System**:
  - `AppColors` (light/dark palette), `AppSpacing`, `AppRadius`, `AppMotion`, `AppTheme`
  - Shared UI: `AppButton`, `AppCard`, `StatusBadge`, `LoadingView`, `EmptyView`, `ErrorView`, `showAppMessage`, `confirmAction`, `FadeSlideIn`
  - Rule: Screens use `context.colors` and `context.text` only (no hardcoded hex colors).
- **Quality & Navigation**:
  - Declarative routing via `go_router`.
  - Package imports only (`package:phia_flutter/...`).
  - Strict lints configured in `analysis_options.yaml`.

---

## 3. Work Completed
- **Phase 7**: Bug & safety fixes (sign-out alarms wipe, booking button states, intake retry).
- **Phase 8**: Feature-first folder restructuring, unified design system, `go_router`, strict lints, English-only standardization.
- **Phase 9**: Full UI redesign in "calm medical" blue/navy across all screens (splash with 4.5s brand intro, welcome, login, onboarding, home, vitals, devices, notifications, booking 5 screens, chat/voice intake, completion, profile, settings). System-following dark mode.
- **Phase 10**: Accessibility (a11y) pass. Layout & accessibility checks (`expectAccessible`) across all screen tests (48dp tap targets, labels, contrast). Form validation auto-scrolls to first invalid field.
- **Phase 11**: Release polish:
  - Local bundled fonts in `assets/google_fonts` (zero runtime network font fetch).
  - Vector adaptive launcher icon with Android 13+ themed icon support.
  - Edge-to-edge system navigation and status bars.
  - CI workflow at `.github/workflows/ci.yml`.
  - Release guide at `docs/release.md`.
  - Restored standard Gradle build directory.
- **Doctor List Reliability (`b465104`)**: Doctor load failures surface clear error state with "Try again" rather than a silent empty list.

---

## 4. Development & Release Rules
1. **Git Workflow**: Commit directly to `main`. No new branches. Never force-push (`--force`).
2. **Secrets & Security**: Never print the git remote URL in logs/prompts (contains token).
3. **Excluded Documentation**: Never commit `mobile-patient-api-guide.md`, `mobile-text-intake-guide.md`, or `mobile-voice-intake-guide.md` (one contains sensitive token references; listed in `.git/info/exclude`).
4. **Backend Contracts**: Follow backend guides strictly. Do not invent endpoints or fields.
5. **Honest Data Presentation**: Never show fake or guessed data. Missing values display `--` or `Not set`.
6. **Screen Requirements**: Every new screen must adhere to `docs/ui_guidelines.md` and include a layout + accessibility test in `test/features/screens/`.
7. **CI Scope**: Pushing `.github/workflows/ci.yml` requires a GitHub token with `workflow` scope.

---

## 5. Open Items for Next Steps
1. **"Enter Room" for Video Consultations**: The backend field holding the video call link is pending specification; button remains disabled/hidden until provided.
2. **Vitals at Booking**: The appointment booking endpoint does not ingest vitals directly. Vitals are synced via `POST /api/v1/vitals/` (`user_id` + `org_id`). Need confirmation on how doctor portal correlates them.
3. **SpO2 Synchronization**: SpO2 is tracked locally via Health Connect; currently omitted from the REST vitals upload schema.
4. **Brand / Logo Palette Decision**: Current logo is dark green (`#11302B`), while app theme is calm blue. Decision pending on whether logo adapts to blue or app incorporates green accents.
5. **Play Store Keystore**: Upload key generation and `android/key.properties` setup needed for official Google Play release builds (testing APK is debug-signed).
6. **Physical Device QA**: Verify dark mode, maximum system font scale, TalkBack screen reader, and adaptive icon on physical devices across Android versions.
