# PHIA Mobile Application - API Endpoints & Data Schemas Specification

This document provides a comprehensive technical reference for all backend endpoints called by the **PHIA Flutter Application**, including their host domains, HTTP methods, headers, query parameters, request payload schemas, and response formats.

---

## 1. Architecture & Service Overview

The PHIA application connects to four distinct backend services:

| Service Domain | Base URL | Technology / Role |
|---|---|---|
| **DrGodly IAM** | `https://iam.drgodly.com` | OAuth 2.0 PKCE, session management (Better-Auth), JWT minting, user profile |
| **DrGodly FHIR Gateway** | `https://fhirgql.drgodly.com` | HL7 FHIR R4 clinical repository (Patients, PractitionerRoles, Slots, Appointments, Vitals) |
| **DrGodly Web App Backend** | `https://app.drgodly.com` | REST backend for intake session records and WebRTC consultation rooms |
| **DrGodly AI Agents** | `https://agents.drgodly.com` | Streaming conversational clinical intake agent (SSE) and SOAP assessment generation |

---

## 2. Authentication & Identity Management (`https://iam.drgodly.com`)

### 2.1 Authorize Endpoint
* **Endpoint:** `GET /api/auth/oauth2/authorize`
* **Protocol:** OAuth 2.0 Authorization Code Grant with PKCE (RFC 7636)
* **Code Reference:** [`AuthRepository.signInWithInAppOAuth`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L30-L55)
* **Query Parameters:**
  ```json
  {
    "client_id": "bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT",
    "response_type": "code",
    "redirect_uri": "com.drgodly.app://callback",
    "scope": "openid profile email offline_access",
    "code_challenge": "<BASE64URL_SHA256_HASH>",
    "code_challenge_method": "S256",
    "state": "<CRYPTOGRAPHIC_RANDOM_STATE>"
  }
  ```
* **Response / Callback:**
  Redirects to `com.drgodly.app://callback?code=<AUTH_CODE>&state=<STATE>` and sets session cookies (`better-auth.session_token`).

---

### 2.2 Token Exchange & Refresh Endpoint
* **Endpoint:** `POST /api/auth/oauth2/token`
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Code Reference:** [`AuthRepository.exchangeCodeForToken`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L176-L230)
* **Code Exchange Payload (Grant Type: `authorization_code`):**
  ```x-www-form-urlencoded
  grant_type=authorization_code&client_id=bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT&code=<code>&code_verifier=<verifier>&redirect_uri=com.drgodly.app://callback
  ```
* **Token Refresh Payload (Grant Type: `refresh_token`):**
  ```x-www-form-urlencoded
  grant_type=refresh_token&client_id=bAMaWWtsrhUKBsTdgFmpLkzAWqNzIJwT&refresh_token=<refresh_token>
  ```
* **Response Schema (`200 OK`):**
  ```json
  {
    "access_token": "string",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "string",
    "id_token": "string",
    "scope": "string"
  }
  ```

---

### 2.3 User Info Endpoint
* **Endpoint:** `GET /api/auth/oauth2/userinfo`
* **Headers:** `Authorization: Bearer <access_token>`
* **Code Reference:** [`AuthRepository.getUserInfo`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L298-L328)
* **Response Schema (`200 OK`):**
  ```json
  {
    "sub": "string",
    "email": "user@example.com",
    "name": "First Last",
    "given_name": "First",
    "family_name": "Last",
    "picture": "https://..."
  }
  ```

---

### 2.4 Mint Session JWT for FHIR Gateway
* **Endpoint:** `GET /api/auth/token`
* **Headers:** `Cookie: better-auth.session_token=<session_cookie_string>`
* **Code Reference:** [`AuthRepository.getJwtToken`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L413-L437)
* **Description:** Used to obtain a short-lived signed JWT accepted by the FHIR gateway (`https://fhirgql.drgodly.com`).
* **Response Schema (`200 OK`):**
  ```json
  {
    "token": "eyJhbGciOi..."
  }
  ```

---

### 2.5 Get Session Endpoint
* **Endpoint:** `GET /api/auth/get-session`
* **Headers:** `Cookie: better-auth.session_token=<session_cookie_string>`
* **Code Reference:** [`AuthRepository.getSession`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L387-L410)
* **Response Schema (`200 OK`):**
  ```json
  {
    "user": {
      "id": "string",
      "email": "string",
      "name": "string",
      "image": "string"
    },
    "session": {
      "id": "string",
      "userId": "string",
      "activeOrganizationId": "0fb41e50-82a4-461e-96c7-bd11359d892d",
      "expiresAt": "2026-10-07T..."
    }
  }
  ```

---

### 2.6 Email / Password Sign In & Sign Up
* **Endpoints:**
  * `POST /api/auth/sign-in/email`
  * `POST /api/auth/sign-up/email`
* **Code Reference:** [`AuthRepository.signIn`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L331-L384)
* **Sign In Payload:**
  ```json
  {
    "email": "user@example.com",
    "password": "Password123"
  }
  ```
* **Sign Up Payload:**
  ```json
  {
    "name": "Full Name",
    "email": "user@example.com",
    "password": "Password123"
  }
  ```
* **Response:** Returns `200 OK` with session cookie in `Set-Cookie` header.

---

### 2.7 Revoke Token & Sign Out
* **Endpoints:**
  * `POST /api/auth/oauth2/revoke`
  * `POST /api/auth/sign-out`
* **Code Reference:** [`AuthRepository.revokeToken`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L233-L295)

---

## 3. DrGodly FHIR API Middleware (`https://fhirgql.drgodly.com`)

> **Authentication Required:** All FHIR endpoints require the header:
> `Authorization: Bearer <session_jwt_or_iam_token>`

---

### 3.1 Specialist Directory Search
* **Endpoint:** `GET /api/v1/practitioner-roles/booking`
* **Description:** Returns pre-joined doctor directories including names, credentials, specialties, and weekly availability schedules.
* **Code Reference:** [`BookingRepository.getActivePractitionerRoles`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L11-L72)
* **Query Parameters:**
  ```
  active=true&limit=50&org_id=0fb41e50-82a4-461e-96c7-bd11359d892d
  ```
* **Response Schema (`200 OK`):**
  ```json
  {
    "total": 3,
    "limit": 50,
    "offset": 0,
    "data": [
      {
        "id": 40001,
        "active": true,
        "organization_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
        "practitioner_detail": {
          "id": 10001,
          "name": "Dr. Kalyan Kalwa",
          "photo_url": "https://...",
          "qualifications": [
            {
              "code": "MD",
              "display": "Endocrinology"
            }
          ]
        },
        "available_times": [
          {
            "days_of_week": ["mon", "tue", "wed"],
            "available_start_time": "09:00:00",
            "available_end_time": "17:00:00"
          }
        ]
      }
    ]
  }
  ```

---

### 3.2 Doctor Free Schedule Slots
* **Endpoint:** `GET /api/v1/slots/`
* **Description:** Retrieves open calendar slots for a specific doctor.
* **Code Reference:** [`BookingRepository.getAvailableSlots`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L75-L112)
* **Query Parameters:**
  ```
  practitioner_role_id=40001&date=YYYY-MM-DD&status=free&limit=100&org_id=<org_id>
  ```
* **Response Schema (`200 OK`):**
  ```json
  {
    "data": [
      {
        "id": 7001,
        "status": "free",
        "start": "2026-10-07T10:00:00Z",
        "end": "2026-10-07T10:30:00Z"
      }
    ]
  }
  ```

---

### 3.3 Atomic Appointment Booking
* **Endpoint:** `POST /api/v1/appointments/book`
* **Description:** Atomically locks the calendar slot and creates a confirmed FHIR Appointment.
* **Code Reference:** [`BookingRepository.bookSlotAtomic`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L115-L171)
* **Request Payload:**
  ```json
  {
    "practitioner_id": 10001,
    "slot_id": 7001,
    "patient_id": 12,
    "user_id": "dPawCkYz9PIaZAugzEKprS12RljmLvKE",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "appointment_type_display": "VIDEO_CALL",
    "practitioner_display": "Dr. Kalyan Kalwa",
    "patient_display": "surya saythu",
    "reason_code": "CONSULTATION",
    "comment": "Pre-visit checkup"
  }
  ```
* **Response Schema (`200 OK` / `201 Created`):**
  ```json
  {
    "id": 8501,
    "status": "booked",
    "start": "2026-10-07T10:00:00Z",
    "end": "2026-10-07T10:30:00Z"
  }
  ```

---

### 3.4 Retrieve User Appointments
* **Endpoints:**
  * `GET /api/v1/appointments/me` (Token-scoped)
  * `GET /api/v1/appointments/?patient_id=12&org_id=<org_id>&limit=100` (Direct query fallback)
* **Code Reference:** [`BookingRepository.getUserAppointments`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L219-L304)
* **Response Schema (`200 OK`):**
  ```json
  {
    "data": [
      {
        "id": 8501,
        "status": "booked",
        "start": "2026-10-07T10:00:00Z",
        "end": "2026-10-07T10:30:00Z",
        "appointment_type_display": "VIDEO_CALL",
        "practitioner_display": "Dr. Kalyan Kalwa",
        "patient_display": "surya saythu"
      }
    ]
  }
  ```

---

### 3.5 Reschedule & Cancel Appointment
* **Reschedule:** `POST /api/v1/appointments/{id}/reschedule`
  * **Payload:** `{ "new_slot_id": 7002 }`
* **Cancel:** `PATCH /api/v1/appointments/{id}`
  * **Payload:** `{ "status": "cancelled" }`
* **Code Reference:** [`BookingRepository.rescheduleAppointmentServer`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L195-L216) & [`BookingRepository.cancelAppointmentServer`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L307-L324)

---

### 3.6 Patient Clinical Profile
* **Get My Profile:** `GET /api/v1/patients/me`
* **Create Profile:** `POST /api/v1/patients/full`
* **Update Profile:** `PATCH /api/v1/patients/{id}/full`
* **Code Reference:** [`ProfileRepository`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/profile_repository.dart#L8-L160)
* **Create Profile Payload (`POST /api/v1/patients/full`):**
  ```json
  {
    "user_id": "dPawCkYz9PIaZAugzEKprS12RljmLvKE",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "active": true,
    "gender": "male",
    "birth_date": "1995-04-12",
    "names": [
      {
        "given": ["surya"],
        "family": "saythu"
      }
    ],
    "telecom": [
      { "system": "phone", "value": "+919876543210", "rank": 1 },
      { "system": "email", "value": "saythuk9@gmail.com", "rank": 1 }
    ],
    "addresses": [
      {
        "line": ["123 Health St"],
        "city": "Bangalore"
      }
    ]
  }
  ```
* **Response Schema (`200 OK` / `201 Created`):**
  ```json
  {
    "id": 12,
    "user_id": "dPawCkYz9PIaZAugzEKprS12RljmLvKE",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "active": true,
    "gender": "male",
    "birth_date": "1995-04-12",
    "names": [{ "given": ["surya"], "family": "saythu" }],
    "telecom": [{ "system": "email", "value": "saythuk9@gmail.com" }],
    "addresses": [{ "line": ["123 Health St"], "city": "Bangalore" }]
  }
  ```

---

### 3.7 Vitals Ingestion & History (HL7 FHIR Observation)
* **Ingest Vitals:** `POST /api/v1/vitals/`
* **Fetch Historical Vitals:** `GET /api/v1/vitals/?user_id=<user_id>&org_id=<org_id>&limit=50&offset=0`
* **Code Reference:** [`VitalsRepository`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/vitals_repository.dart#L8-L52)
* **Ingestion Payload:**
  ```json
  {
    "user_id": "dPawCkYz9PIaZAugzEKprS12RljmLvKE",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "heart_rate": 74.0,
    "blood_pressure_systolic": 120.0,
    "blood_pressure_diastolic": 80.0,
    "spo2": 98.0,
    "temperature": 98.6,
    "steps": 147,
    "recorded_at": "2026-10-06T21:30:38Z"
  }
  ```

---

## 4. DrGodly Web / REST Backend (`https://app.drgodly.com`)

### 4.1 Consultation Video Room Provisioning
* **Endpoint:** `POST /api/consultation/create`
* **Code Reference:** [`BookingRepository.provisionConsultationRoom`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L173-L192)
* **Request Payload:**
  ```json
  {
    "fhir_appointment_id": 8501
  }
  ```

---

### 4.2 Pre-Visit Clinical Intake Session Lifecycle
* **Code Reference:** [`IntakeService`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L210-L368)

| Action | Endpoint | Method | Request Payload | Headers |
|---|---|---|---|---|
| **Create Intake** | `/api/intake/create` | `POST` | `{"mode": "TEXT", "patient_fhir_id": 12}` | `Authorization: Bearer <token>`, `x-org-id: <org_id>` |
| **Update / Complete** | `/api/intake/update` | `POST` | `{"id": 302, "conversation": [...], "report": {...}}` | `Authorization: Bearer <token>`, `x-org-id: <org_id>` |
| **Link to Appointment**| `/api/intake/link` | `POST` | `{"id": 302, "fhir_appointment_id": 8501}` | `Authorization: Bearer <token>`, `x-org-id: <org_id>` |
| **Abandon Intake** | `/api/intake/abandon` | `POST` | `{"id": 302}` | `Authorization: Bearer <token>`, `x-org-id: <org_id>` |

---

## 5. DrGodly AI Agents (`https://agents.drgodly.com`)

### 5.1 Streaming Clinical Intake Chat (SSE)
* **Endpoint:** `POST /api/agent/intake`
* **Protocol:** Server-Sent Events (SSE / NDJSON streaming)
* **Headers:**
  * `Authorization: Bearer <token>`
  * `Content-Type: application/json`
  * `Accept: application/json, text/event-stream`
* **Code Reference:** [`IntakeService.streamChatTurn`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L56-L158)
* **Request Payload:**
  ```json
  {
    "message": "I've had a severe headache for 3 days",
    "session_id": "ses_9281a8c0e..."
  }
  ```
* **Event Stream Format:**
  ```
  data: {"type": "text_delta", "data": {"content": "I understand. "}}
  data: {"type": "text_delta", "data": {"content": "Are you experiencing any nausea or light sensitivity?"}}
  data: {"type": "agent_end", "data": {"session_id": "ses_9281a8c0e..."}}
  data: [DONE]
  ```

---

### 5.2 Structured Clinical Assessment Generation (SOAP Summary)
* **Endpoint:** `POST /api/agent/assessment`
* **Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`
* **Code Reference:** [`IntakeService.generateClinicalReport`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L164-L207)
* **Request Payload:**
  ```json
  {
    "conversation": [
      "AI: What brings you in today?",
      "Patient: I have had a severe headache for 3 days",
      "AI: Do you have sensitivity to bright lights?",
      "Patient: Yes, light hurts my eyes"
    ]
  }
  ```
* **Response Schema (`200 OK`):**
  ```json
  {
    "chief_complaint": "Severe headache with photophobia",
    "hpi": "Symptoms persisting for 3 days with notable light sensitivity.",
    "urgency": "ROUTINE",
    "possible_causes": ["Migraine without aura", "Tension headache"],
    "recommended_specialty": "Neurology"
  }
  ```
