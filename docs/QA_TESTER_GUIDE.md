# DrGodly Android App — Comprehensive QA Testing Guide & Test Plan
**Application:** DrGodly Patient Mobile App  
**Package ID:** `com.drgodly.app`  
**Current Test Build:** `DrGodly_v0.0.2_release_v15.apk` (Commit: `388025b`)  
**APK Size:** ~63.2 MB (66,283,028 bytes)  
**Min Android SDK:** Android 8.0 (API 26) · **Target Android SDK:** Android 14/15 (API 34+)  
**Target Environments:** Production/Staging Backends (IAM, FHIR Gateway, AI Agents)

---

## 1. Executive Summary & Build Information

This document serves as the complete manual and automated test guide for QA engineers and manual testers testing the DrGodly Patient Mobile Application.

### 1.1 Where to Obtain the APK
- **Local Workspace Path:** `/home/mi/Desktop/AI_projects/APK_release/DrGodly_v0.0.2_release_v15.apk`
- **Alternative Path:** `/home/mi/Desktop/AI_projects/app-release.apk`
- **Gradle Build Output:** `/home/mi/Desktop/AI_projects/phia_flutter/build/app/outputs/flutter-apk/app-release.apk`

### 1.2 Installation Instructions
Connect the test Android phone via USB with USB Debugging enabled, then run:
```bash
adb install -r /home/mi/Desktop/AI_projects/APK_release/DrGodly_v0.0.2_release_v15.apk
```
*Alternatively, transfer the APK file to the device via Google Drive, WhatsApp, or USB storage and install via the device's Package Installer.*

---

## 2. Test Environment & Credentials

| Component | Endpoint | Description |
|---|---|---|
| **IAM Server** | `https://iam.drgodly.com` | OAuth 2.0 PKCE authentication & user identity |
| **FHIR Gateway** | `https://fhirgql.drgodly.com` | REST `/api/v1/` for Patients, Slots, Appointments, Vitals |
| **Consultation & Intake** | `https://app.drgodly.com` | `/api/intake/*`, `/api/consultation/create` |
| **AI Agents** | `https://agents.drgodly.com` | HTTP SSE Chat Streaming (`/api/agent/intake`), Real-time Voice WebSocket (`wss://agents.drgodly.com/ws/audio`) |

### Recommended Test Credentials
- **Email:** `testuser.gnr@gmail.com`
- **Password:** `12345678`
- *(Or use personal test accounts created via the IAM Web Sign-up)*

---

## 3. High-Priority Regression & Recent Fix Checklist

Testers should specifically verify the following 5 critical fixes incorporated in this release:

1. **Zero White-Screen Flashes on Launch:**
   - On cold start, the app launches with the unified background color (`#F4F8FB`) without any white flicker or unpainted blank views.
2. **Splash Screen Presentation (2.5 Seconds):**
   - The brand logo tile (`#11302B`), "DrGodly" typography, and pulsing ECG heartbeat line remain smoothly visible for 2.5 seconds before transitioning.
3. **Smooth Screen-to-Screen Transitions:**
   - Navigating between Splash, Welcome, Login, Onboarding, and Main screens uses a gentle 350ms cross-fade (no abrupt jumps or flickering).
4. **Doctor Availability Range:**
   - Doctor cards display real working day ranges and working hours (e.g. `Mon–Fri · 9:00 AM–5:00 PM`) derived from `availableTimes`.
5. **Reschedule Alert Local Date & Time:**
   - Clinic-initiated appointment reschedule notifications format dates and times in the patient's local timezone (e.g. `Nov 22, 2026 at 10:30 AM`).

---

## 4. End-to-End Test Modules & Test Cases

---

### Module 1: App Launch & Startup (Splash Screen & Transitions)

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-SPL-01** | Cold Start Splash Display | Kill app completely. Launch app from Android app drawer. | Splash screen displays centered DrGodly logo, brand typography, and pulsing ECG line. Displays for exactly 2.5s. No white flash on startup. | [ ] |
| **TC-SPL-02** | Splash Transition | Observe transition from Splash to Welcome screen (or Home if logged in). | Smooth 350ms fade transition. No visual flickering or layout jumping. | [ ] |
| **TC-SPL-03** | Dark Mode Theme Alignment | Turn on system Dark Theme in Android Settings. Launch app. | Background and system bars respect dark palette without flashing white. | [ ] |
| **TC-SPL-04** | Offline Startup | Turn off Wi-Fi and Mobile Data. Launch app. | App launches without crashing. If logged in, cached dashboard loads; if logged out, Welcome screen opens gracefully. | [ ] |

---

### Module 2: Authentication & Session Management

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-AUTH-01** | OAuth 2.0 PKCE Login Flow | From Welcome screen, tap "Sign In". Webview/Browser opens IAM login page. Enter test credentials and tap Log In. | Browser redirects seamlessly to app (`com.drgodly.app://oauth-callback`). App stores encrypted JWT token and routes to Onboarding/Home. | [ ] |
| **TC-AUTH-02** | Invalid Credentials | Attempt login with invalid password on IAM page. | Proper error message displayed on IAM page ("Invalid email or password"). App does not crash. | [ ] |
| **TC-AUTH-03** | Auto-Login & Session Restore | Log in successfully. Force kill app from Android App Switcher. Reopen app. | Splash screen verifies saved token. User lands directly on Home dashboard without needing to log in again. | [ ] |
| **TC-AUTH-04** | Token Expiration & 401 Interceptor | Simulate expired token or leave app idle past token TTL. Trigger an API action. | Dio interceptor performs single-flight token refresh seamlessly without logging out user or displaying error dialogs. | [ ] |
| **TC-AUTH-05** | Secure Sign-Out | Go to Profile > Account > Sign Out. Confirm logout. | Tokens are wiped from encrypted storage. User is returned to Welcome/Login screen. Pressing Android Back button does not return to authenticated dashboard. | [ ] |

---

### Module 3: Patient Profile Onboarding

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-ONB-01** | First-Time Profile Creation | Log in with a fresh account. Fill in Full Name, Phone, DOB, Gender, and Address. Tap "Save & Continue". | Input validation prevents empty mandatory fields. Profile syncs to `POST /api/v1/patients/full`. | [ ] |
| **TC-ONB-02** | Health Goals Selection | Select 1 or more wellness goals (e.g. Weight Management, Vitals Monitoring). Tap "Next". | Selected goals are highlighted and saved to patient state. | [ ] |
| **TC-ONB-03** | Onboarding Completion | Tap "Get Started" on the completion screen. | Navigates to Home Dashboard. Profile setup flag is marked complete so onboarding does not re-appear on subsequent launches. | [ ] |

---

### Module 4: Home Dashboard & Navigation

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-DASH-01** | Dashboard Header & Greeting | Observe top section of Home screen. | Displays dynamic greeting ("Good Morning/Afternoon/Evening"), patient name, and current date. | [ ] |
| **TC-DASH-02** | Quick Actions Navigation | Tap "Book Appointment", "Start Intake", or "View Vitals" quick buttons. | Each button navigates to the respective feature screen without latency or errors. | [ ] |
| **TC-DASH-03** | Bottom Navigation Bar | Tap between tabs: Home, Appointments, Vitals, Profile. | Active tab icon highlights with brand color. Screen transitions smoothly without state loss. | [ ] |
| **TC-DASH-04** | Pull-to-Refresh | Swipe down on Home screen. | Refresh spinner appears; upcoming appointments and latest vitals reload from FHIR gateway. | [ ] |

---

### Module 5: Doctor Consultation Booking

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-BOK-01** | Doctor Directory Listing | Tap "Book Doctor" from Home or Appointments tab. | Doctor list loads from `/practitioner-roles/booking`. Displays Doctor name, specialty, photo/avatar, and rating. | [ ] |
| **TC-BOK-02** | Doctor Availability Label | Inspect availability badge on doctor card. | Displays formatted working days & hours (e.g., `Mon–Fri · 9:00 AM–5:00 PM`). If no hours configured, displays day range only. | [ ] |
| **TC-BOK-03** | Doctor Search & Filtering | Enter specialty (e.g. "Cardiologist") or doctor name in search bar. | List filters in real-time. If no results found, shows polite `EmptyView`. | [ ] |
| **TC-BOK-04** | Date & Time Slot Selection | Select a doctor > Choose consultation date from horizontal calendar. | Free slots load from `/slots?practitioner_role_id=...&start_date=...`. Selected slot is highlighted. | [ ] |
| **TC-BOK-05** | Booking Review & Mode Selection | Tap "Continue to Review". Choose mode: **Telemedicine (Video)** or **In-Person**. | Review screen shows Doctor name, Date/Time, Consultation Mode, and fee summary. | [ ] |
| **TC-BOK-06** | Atomic Booking Confirmation | Tap "Confirm Booking". | App sends atomic booking request. Confirmed screen appears with Booking ID, date/time, and option to "Add to Calendar" or "Start Pre-visit Intake". | [ ] |
| **TC-BOK-07** | Slot Collision / Conflict | Attempt booking a slot that was already booked by another user. | App displays clear conflict alert ("This slot is no longer available, please select another time"). | [ ] |

---

### Module 6: AI Clinical Health Intake (Chat & Real-Time Voice)

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-INT-01** | Launch Pre-visit Intake | Open confirmed appointment > Tap "Start Clinical Intake". Choose "Chat Intake" or "Voice Intake". | Navigates to corresponding interactive intake screen. | [ ] |
| **TC-INT-02** | Interactive Chat Intake | In Chat Intake, read AI opening question and type a response (e.g. "Mild headache for 2 days"). Send. | AI streams question follow-up via SSE in real-time. Chat bubble auto-scrolls down. | [ ] |
| **TC-INT-03** | Chat Intake Completion | Answer all 4–5 diagnostic questions until AI indicates completion. | AI produces clinical summary. Summary syncs to `/api/intake/link` linked to the appointment ID. | [ ] |
| **TC-INT-04** | Real-Time Voice Intake (Mic Permission) | Launch Voice Intake for the first time. | Android displays system microphone permission dialog. Denying shows informative explanation; granting opens voice call screen. | [ ] |
| **TC-INT-05** | Voice Intake Live WebSocket Call | Speak into microphone during voice session. | Audio stream encodes PCM16, sends over WebSocket (`wss://agents.drgodly.com/ws/audio`). Voice agent responds with synthesized voice output. | [ ] |
| **TC-INT-06** | Speakerphone / Earpiece Toggle | During voice call, tap Speaker Toggle button. | Sound immediately routes between loudspeaker and earpiece (verified on Android 12+ using `AudioManager.setCommunicationDevice`). | [ ] |
| **TC-INT-07** | Mute / Unmute & End Call | Tap Mute button (mic indicator turns red/muted). Tap End Call. | Audio stops recording. App prompts to save clinical assessment and links it to patient record. | [ ] |

---

### Module 7: Appointments Management ("My Care")

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-APT-01** | Appointments Tab Organization | Navigate to Appointments tab. | Appointments grouped under "My care", split into Upcoming and Past visits. | [ ] |
| **TC-APT-02** | Appointment Card Details | Inspect an appointment card. | Shows Doctor name, specialty, formatted local date/time, Mode badge ("Telemedicine" or "In-Person"), and status badge ("Booked", "Pending", etc.). | [ ] |
| **TC-APT-03** | Reschedule Notification Display | Simulate or receive a clinic-initiated reschedule notification. | Notification banner displays rescheduled date and time in local format (e.g., `Nov 22, 2026 at 10:30 AM`). | [ ] |
| **TC-APT-04** | Appointment Cancellation | Open upcoming appointment > Tap "Cancel Appointment" > Confirm dialog. | Sends cancellation to FHIR API. Appointment status updates to "Cancelled" in real-time. | [ ] |

---

### Module 8: Vitals & Wearable Health Connect Integration

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-VIT-01** | Health Connect Permission Request | Go to Vitals screen > Tap "Sync with Health Connect". | Android Health Connect system permission sheet opens requesting Read access (Heart Rate, Steps, Blood Pressure, Sleep, Blood Glucose). | [ ] |
| **TC-VIT-02** | Vitals Aggregation & Display | Grant permissions with existing sample data in Health Connect. | Vitals cards display latest metrics with appropriate units (bpm, steps, mmHg, mg/dL). | [ ] |
| **TC-VIT-03** | Manual Vitals Entry | Tap "+" on Vitals screen. Select Heart Rate or Blood Pressure. Enter value and save. | Vitals point immediately saves to local SQLite and queues for FHIR `/api/v1/vitals/` sync. | [ ] |
| **TC-VIT-04** | BLE Heart Rate Monitor (Optional) | If a Bluetooth heart rate strap (Polar, Garmin, etc.) is available, tap "Scan BLE Device". | BLE scan discovers device; connects and streams real-time heart rate beats. | [ ] |

---

### Module 9: Profile, Settings & Notifications

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-SET-01** | Medication Reminders | Go to Profile > Reminders > Add new reminder (e.g. "Amoxicillin 500mg at 08:00 AM"). | Reminder saves to SQLite. Local notification is scheduled via `flutter_local_notifications`. | [ ] |
| **TC-SET-02** | Reminder Trigger | Set reminder time 2 minutes ahead and wait with app in background. | Android system heads-up notification sounds and displays reminder title and dose. | [ ] |
| **TC-SET-03** | Vital Alert Thresholds | Go to Profile > Alert Limits. Set High Heart Rate threshold to 120 bpm. Save. | Threshold saves successfully. Alert is logged when sync records an exceeding vital. | [ ] |
| **TC-SET-04** | Unit Preferences | Go to Profile > Units. Toggle between Metric (kg, cm) and Imperial (lbs, in). | Dashboard and Vitals screens update labels and values accordingly. | [ ] |

---

### Module 10: Non-Functional, Battery & Accessibility Testing

| Test ID | Test Scenario | Steps to Execute | Expected Result | Pass/Fail |
|---|---|---|---|---|
| **TC-NF-01** | Airplane Mode / Network Drop | Enable Airplane Mode while using app. Navigate screens. | App does not crash. Displays friendly network warning and allows viewing cached offline data. | [ ] |
| **TC-NF-02** | Device Rotation / Foldable Screen | Rotate device to landscape and back to portrait. | UI adapts without overflow errors (`RenderFlex` overflow red bars). | [ ] |
| **TC-NF-03** | System Font Scaling | Set Android Display Font Size to "Largest" (1.3x–1.5x). | All text scales gracefully without clipping critical buttons or modal titles. | [ ] |
| **TC-NF-04** | TalkBack Screen Reader | Enable TalkBack in Android Accessibility. Navigate through Booking and Vitals. | All interactive buttons have semantic accessibility labels (e.g. "Book Dr. Smith, button"). | [ ] |
| **TC-NF-05** | Memory & Battery Profiling | Leave app running in background for 2 hours with WorkManager sync. | No excessive battery drain; WorkManager runs at constrained periodic intervals without persistent CPU wake locks. | [ ] |

---

## 5. Defect Reporting Template & Severity Guidelines

When submitting a defect to Jira, GitHub Issues, or the development team, use the following standardized format:

```markdown
### [Bug Title]: Short, specific summary (e.g., "[Booking] Reschedule alert shows raw UTC string instead of local time")

- **Severity:** Blocker / Critical / Major / Minor / Cosmetic
- **Device & OS:** e.g., Realme RMX3388, Android 13 / Samsung S23, Android 14
- **App Version:** DrGodly v0.0.2 release v15 (Commit: 388025b)
- **Network:** Wi-Fi / 5G / Airplane Mode

#### Preconditions:
User is logged in as testuser.gnr@gmail.com with completed profile.

#### Steps to Reproduce:
1. Navigate to Appointments tab.
2. Select an existing appointment.
3. Tap "Reschedule".
4. Pick new date and confirm.

#### Expected Result:
A confirmation banner appears showing the new local date & time in "MMM d, y · h:mm a" format.

#### Actual Result:
Raw ISO UTC string "2026-11-25T04:30:00.000Z" was displayed.

#### Attachments:
- Screenshot / Screen recording
- ADB logcat log (`adb logcat -d > bug_log.txt`)
```

### Severity Definitions
- **Blocker:** App crashes on launch, data loss, unable to log in, security vulnerability.
- **Critical:** Core feature broken (e.g., unable to book slot, unable to conduct voice intake).
- **Major:** High impact workaround available (e.g., vitals sync fails on one sensor type, reminder notification delayed).
- **Minor / Cosmetic:** Visual misalignment, typos, small spacing inconsistencies.

---
*Document maintained by DrGodly Engineering Team · Updated November 2026*
