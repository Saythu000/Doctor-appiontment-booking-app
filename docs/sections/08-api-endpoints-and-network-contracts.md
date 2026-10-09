# 08. Complete API Endpoints Catalog & Network Contracts

## Plain-Language Summary
This section documents every HTTP REST and streaming network endpoint integrated into the PHIA mobile application. The endpoints are organized by functional module: **Authentication (DrGodly IAM)**, **Clinical & Appointments (DrGodly FHIR Middleware)**, **AI Clinical Intake (Python Agents)**, and **Consultation Services (DrGodly Web App)**. For each endpoint, this document provides the exact URL, HTTP method, header contracts, query/path parameters, request and response JSON schemas, failure handling, timeout policies, and code file references.

---

## 1. Network Infrastructure, Base URLs & Interceptors

### A. Environment Base URLs
As declared in [`lib/core/constants/api_constants.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/core/constants/api_constants.dart):
- **DrGodly IAM (Auth & Sessions)**: `https://iam.drgodly.com`
- **DrGodly FHIR Middleware (HL7 FHIR R4 API)**: `https://fhirgql.drgodly.com`
- **DrGodly AI Agent Service (Python Intake Stream)**: `https://agents.drgodly.com`
- **DrGodly Web App API (Consultation & Relational DB)**: `https://app.drgodly.com`
- **Open-Wearables Cloud API (Aggregator)**: `https://api.openwearables.io`

### B. Network Interceptors & Offline Mock Handling
Implemented in [`lib/data/service/fhir_api_client.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/fhir_api_client.dart#L21-L60):
- **Mock Interceptor**: Intercepts requests when `_isLiveMode == false`. Resolves local fallback data for `/health`, `/practitioner-roles`, and `/appointments`.
- **Token Injection**: Automatically injects `Authorization: Bearer <EdDSA_JWT>` on outgoing requests when authenticated.
- **Token Refresh Handler**: Configured via `setTokenRefresher()` in `main.dart` to intercept 401 Unauthorized responses and trigger transparent token refresh.
- **Timeouts**: Default 30-second connection timeout, 30-second receive timeout across all Dio instances.

---

## 2. Module 1: Authentication & Identity Management (DrGodly IAM)

### 2.1 Direct Email & Password Sign-In
- **Name**: Email Sign-In
- **Method**: `POST`
- **URL**: `https://iam.drgodly.com/api/auth/sign-in/email`
- **Purpose**: Authenticates a patient with email and password, establishing an HTTP session.
- **Headers**:
  - `Content-Type`: `application/json`
  - `Origin`: `https://iam.drgodly.com`
  - `Referer`: `https://iam.drgodly.com/`
- **Request Body**:
  ```json
  {
    "email": "patient@example.com",     // String, required
    "password": "********"               // String, required
  }
  ```
- **Success Response (200 OK)**:
  - Headers: `Set-Cookie: __Secure-better-auth.session_token=<SESSION_COOKIE>; Path=/; HttpOnly; Secure`
  - Body:
    ```json
    {
      "token": "<SESSION_COOKIE>",
      "user": {
        "id": "usr_99812",
        "email": "patient@example.com",
        "name": "Saythu"
      }
    }
    ```
- **Error Codes & Handling**:
  - `401 Unauthorized`: "Invalid email or password" displayed in UI banner.
  - `429 Too Many Requests`: "Too many login attempts. Please wait."
- **Timeout Policy**: 30s timeout. No automated retry.
- **Called in Code**: [`lib/data/repository/auth_repository.dart:181`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L181) (`signIn()`).

---

### 2.2 Get Active Session & User Info
- **Name**: Get Session
- **Method**: `GET`
- **URL**: `https://iam.drgodly.com/api/auth/get-session`
- **Purpose**: Validates active session cookie and retrieves user profile with `activeOrganizationId`.
- **Headers**:
  - `Cookie`: `__Secure-better-auth.session_token=<SESSION_COOKIE>`
- **Request Body**: None (GET).
- **Success Response (200 OK)**:
  ```json
  {
    "session": {
      "id": "sess_88123",
      "userId": "usr_99812",
      "activeOrganizationId": "0fb41e50-82a4-461e-96c7-bd11359d892d",
      "expiresAt": "2026-11-08T12:00:00Z"
    },
    "user": {
      "id": "usr_99812",
      "email": "patient@example.com",
      "name": "Saythu"
    }
  }
  ```
- **Error Codes & Handling**:
  - `401 Unauthorized`: Session expired; triggers redirect to `/login`.
- **Called in Code**: [`lib/data/repository/auth_repository.dart:219`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L219) (`getSession()`).

---

### 2.3 Mint EdDSA Session JWT
- **Name**: Mint Session JWT
- **Method**: `GET`
- **URL**: `https://iam.drgodly.com/api/auth/token`
- **Purpose**: Exchanges active session cookie for an EdDSA-signed Session JWT required by FHIR and AI Intake.
- **Headers**:
  - `Cookie`: `__Secure-better-auth.session_token=<SESSION_COOKIE>`
- **Request Body**: None (GET).
- **Success Response (200 OK)**:
  ```json
  {
    "token": "eyJhbGciOiJFZERTQSIs..." // EdDSA signed JWT containing sub, org_id, exp
  }
  ```
- **Error Codes & Handling**:
  - `401 Unauthorized`: Session cookie invalid or missing.
- **Called in Code**: [`lib/data/repository/auth_repository.dart:238`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L238) (`getJwtToken()`).

---

### 2.4 OAuth 2.0 PKCE Token Exchange & Refresh
- **Name**: OAuth 2.0 Token
- **Method**: `POST`
- **URL**: `https://iam.drgodly.com/api/auth/oauth2/token`
- **Purpose**: Exchanges authorization code for tokens, or exchanges refresh token for new access token.
- **Headers**: `Content-Type: application/x-www-form-urlencoded`
- **Request Body (Code Exchange)**:
  `grant_type=authorization_code&code=AUTH_CODE&redirect_uri=CALLBACK_URL&client_id=CLIENT_ID&code_verifier=VERIFIER`
- **Request Body (Refresh)**:
  `grant_type=refresh_token&refresh_token=REFRESH_TOKEN&client_id=CLIENT_ID`
- **Success Response (200 OK)**:
  ```json
  {
    "access_token": "cfRg...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "rt_89123...",
    "id_token": "eyJ..."
  }
  ```
- **Error Codes & Handling**:
  - `400 Bad Request / invalid_grant`: Stored refresh token is dead; purges KeyStore and prompts login.
- **Called in Code**: [`lib/data/repository/auth_repository.dart:94`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L94) (`exchangeCodeForToken()`, `refreshOAuth2Token()`).

---

### 2.5 End Session / Logout
- **Name**: End Session
- **Method**: `POST` (or `GET`)
- **URL**: `https://iam.drgodly.com/api/auth/oauth2/end-session`
- **Purpose**: Revokes the user session across the DrGodly IAM server cluster.
- **Headers**:
  - `Authorization`: `Bearer <ACCESS_TOKEN>`
  - `Cookie`: `__Secure-better-auth.session_token=<SESSION_COOKIE>`
- **Request Body**: `{"id_token_hint": "<ID_TOKEN>"}`
- **Success Response (200 OK / 204 No Content)**
- **Called in Code**: [`lib/data/repository/auth_repository.dart:265`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/auth_repository.dart#L265) (`endSession()`).

---

## 3. Module 2: Clinical & FHIR Middleware (DrGodly FHIR)

### 3.1 Get Patient Profile (`/api/v1/patients/me`)
- **Name**: Get Patient Profile
- **Method**: `GET`
- **URL**: `https://fhirgql.drgodly.com/api/v1/patients/me`
- **Purpose**: Retrieves the patient's FHIR ID, full name, telecom, gender, and birthdate.
- **Headers**:
  - `Authorization`: `Bearer <EdDSA_JWT>`
  - `Accept`: `application/json`
- **Query Params**: None.
- **Request Body**: None (GET).
- **Success Response (200 OK)**:
  ```json
  {
    "id": 401,
    "user_id": "usr_99812",
    "name": [{"family": "Saythu", "given": ["Saythu"]}],
    "telecom": [{"system": "email", "value": "saythu@example.com"}],
    "gender": "male",
    "birthDate": "1995-05-12"
  }
  ```
- **Error Codes & Handling**:
  - `404 Not Found`: Patient profile not yet created; app routes to `/profile_setup`.
  - `401 Unauthorized`: Triggers transparent token refresh.
- **Called in Code**: [`lib/data/repository/profile_repository.dart:67`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/profile_repository.dart#L67) (`fetchPatientMe()`).

---

### 3.2 Create Full Patient Profile (`/api/v1/patients/full`)
- **Name**: Create Full Patient
- **Method**: `POST`
- **URL**: `https://fhirgql.drgodly.com/api/v1/patients/full`
- **Purpose**: Creates the patient's FHIR Resource if missing before initial booking.
- **Headers**:
  - `Authorization`: `Bearer <EdDSA_JWT>`
  - `Content-Type`: `application/json`
- **Request Body**:
  ```json
  {
    "user_id": "usr_99812",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "name": [{"text": "Saythu", "family": "Saythu", "given": ["Saythu"]}],
    "telecom": [{"system": "email", "value": "saythu@example.com"}],
    "gender": "male",
    "birthDate": "1995-05-12"
  }
  ```
- **Success Response (201 Created)**: Returns created FHIR Patient JSON with numeric ID.
- **Called in Code**: [`lib/data/repository/profile_repository.dart:123`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/profile_repository.dart#L123) (`createPatientFull()`).

---

### 3.3 List Medical Specialists (`/api/v1/practitioner-roles/booking`)
- **Name**: List Booking Specialists
- **Method**: `GET`
- **URL**: `https://fhirgql.drgodly.com/api/v1/practitioner-roles/booking`
- **Purpose**: Fetches active doctors, specialties, bios, and consultation fee details.
- **Headers**:
  - `Authorization`: `Bearer <EdDSA_JWT>`
- **Query Params**: `active=true`, `limit=50`, `org_id=<ORG_ID>`
- **Request Body**: None (GET).
- **Success Response (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 12,
        "practitioner_name": "Dr. Kalyan Kalwa",
        "specialties": ["Endocrinology"],
        "photo_url": "https://...",
        "consultation_fee": 500,
        "available_today": true
      }
    ]
  }
  ```
- **Error Codes & Handling**:
  - Network error / 500: ViewModel falls back to SQLite cache (`specialists_cache`).
- **Called in Code**: [`lib/data/repository/booking_repository.dart:37`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L37) (`getPractitionerRoles()`).

---

### 3.4 Retrieve Free Consultation Slots (`/api/v1/slots/`)
- **Name**: Get Available Slots
- **Method**: `GET`
- **URL**: `https://fhirgql.drgodly.com/api/v1/slots/`
- **Purpose**: Retrieves open calendar slots for a specific doctor and date.
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`
- **Query Params**:
  - `practitioner_role_id`: `12` (int, required)
  - `date`: `2026-10-10` (String YYYY-MM-DD, optional)
  - `status`: `free` (String, required)
  - `limit`: `100` (int)
- **Request Body**: None (GET).
- **Success Response (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 1042,
        "start": "2026-10-10T10:00:00Z",
        "end": "2026-10-10T10:30:00Z",
        "status": "free"
      }
    ]
  }
  ```
- **Called in Code**: [`lib/data/repository/booking_repository.dart:78`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L78) (`getAvailableSlots()`).

---

### 3.5 Create FHIR Appointment (`/api/v1/appointments`)
- **Name**: Create Appointment
- **Method**: `POST`
- **URL**: `https://fhirgql.drgodly.com/api/v1/appointments`
- **Purpose**: Claims a slot and registers a formal clinical consultation.
- **Headers**:
  - `Authorization`: `Bearer <EdDSA_JWT>`
  - `Content-Type`: `application/json`
- **Request Body**:
  ```json
  {
    "status": "booked",
    "slot_id": 1042,
    "practitioner_role_id": 12,
    "patient_id": 401,
    "user_id": "usr_99812",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "start": "2026-10-10T10:00:00Z",
    "end": "2026-10-10T10:30:00Z",
    "patient_instruction": "Severe headache for 3 days",
    "description": "DrGodly Telehealth Consultation"
  }
  ```
- **Success Response (201 Created)**: Returns created appointment JSON with numeric ID.
- **Error Codes & Handling**:
  - `400 / 409 Conflict`: Slot already taken by another patient. Surfaces double-booking alert.
- **Called in Code**: [`lib/data/repository/booking_repository.dart:148`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L148) (`createAppointment()`).

---

### 3.6 Reschedule Appointment (`/api/v1/appointments/{id}/reschedule`)
- **Name**: Reschedule Appointment
- **Method**: `POST`
- **URL**: `https://fhirgql.drgodly.com/api/v1/appointments/{id}/reschedule`
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Path Params**: `id` (Appointment ID)
- **Request Body**: `{"new_slot_id": 2045}`
- **Success Response (200 OK)**: Returns updated appointment JSON with new slot.
- **Called in Code**: [`lib/data/repository/booking_repository.dart:228`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L228) (`rescheduleAppointmentServer()`).

---

### 3.7 Cancel Appointment (`/api/v1/appointments/{id}`)
- **Name**: Cancel Appointment
- **Method**: `PATCH`
- **URL**: `https://fhirgql.drgodly.com/api/v1/appointments/{id}`
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Path Params**: `id` (Appointment ID)
- **Request Body**: `{"status": "cancelled"}`
- **Success Response (200 OK / 204 No Content)**
- **Called in Code**: [`lib/data/repository/booking_repository.dart:340`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L340) (`cancelAppointmentServer()`).

---

### 3.8 Submit Vitals Observation Bundle (`/api/v1/vitals/bundle`)
- **Name**: Submit Vitals Bundle
- **Method**: `POST`
- **URL**: `https://fhirgql.drgodly.com/api/v1/vitals/bundle`
- **Purpose**: Uploads background batched health observations (steps, HR, calories, SpO2).
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "user_id": "usr_99812",
    "org_id": "0fb41e50-82a4-461e-96c7-bd11359d892d",
    "metrics": [
      {"type": "steps", "value": 4520, "timestamp": "2026-10-09T14:30:00Z"},
      {"type": "heart_rate", "value": 72, "timestamp": "2026-10-09T14:30:00Z"}
    ]
  }
  ```
- **Success Response (200 OK)**
- **Called in Code**: [`lib/data/repository/vitals_repository.dart:58`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/vitals_repository.dart#L58) (`submitVitals()`).

---

## 4. Module 3: AI Clinical Intake (Python Agents)

### 4.1 Live Streaming Intake Chat (`/api/agent/intake`)
- **Name**: Stream Intake Chat Turn
- **Method**: `POST`
- **URL**: `https://agents.drgodly.com/api/agent/intake`
- **Purpose**: Multi-turn clinical interview streaming responses token-by-token.
- **Headers**:
  - `Authorization`: `Bearer <EdDSA_JWT>`
  - `Content-Type`: `application/json`
  - `Accept`: `application/json, text/event-stream`
- **Request Body**:
  ```json
  {
    "message": "I've had a headache for 3 days", // String, required
    "session_id": null                           // String, null on Turn 1; non-null on Turn 2+
  }
  ```
- **Stream Output Format**:
  - SSE / Newline-delimited JSON chunks:
    - `{"type": "text_delta", "data": {"content": "Thank you..."}}`
    - `{"type": "agent_end", "data": {"session_id": "sess_intake_991"}}`
    - `{"type": "status_end"}` (Signals whole conversation complete)
- **Response Headers**: `X-Session-Id: <SESSION_ID>`
- **Error Codes & Handling**:
  - `401 Unauthorized`: "Invalid or expired token" caught and displayed in UI.
- **Called in Code**: [`lib/data/service/intake_service.dart:74`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L74) (`streamChatTurn()`).

---

### 4.2 Generate Structured Clinical Report (`/api/agent/assessment`)
- **Name**: Generate Clinical Assessment
- **Method**: `POST`
- **URL**: `https://agents.drgodly.com/api/agent/assessment`
- **Purpose**: Generates structured SOAP clinical notes from the conversation history.
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "conversation": [
      {"role": "user", "content": "Headache for 3 days"},
      {"role": "assistant", "content": "Any fever?"}
    ],
    "demographics": {"age": 30, "gender": "male"}
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "chief_complaint": "Persistent headache with mild fever",
    "hpi": "Patient reports 3-day history of throbbing cephalalgia...",
    "triage_level": "Urgent",
    "suggested_specialty": "Neurology"
  }
  ```
- **Called in Code**: [`lib/data/service/intake_service.dart:181`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L181) (`generateClinicalReport()`).

---

## 5. Module 4: Consultation & Relational Database (DrGodly Web App)

### 5.1 Persist Clinical Intake Record (`/api/intake/create`)
- **Name**: Create Intake DB Record
- **Method**: `POST`
- **URL**: `https://app.drgodly.com/api/intake/create`
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "patient_id": 401,
    "session_id": "sess_intake_991",
    "chief_complaint": "Persistent headache with mild fever",
    "report_json": "{\"chief_complaint\": ...}",
    "raw_transcript": "[...]"
  }
  ```
- **Success Response (201 Created)**: Returns `{"intake_id": 892}`.
- **Called in Code**: [`lib/data/service/intake_service.dart:251`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L251) (`saveIntakeRecord()`).

---

### 5.2 Provision Consultation Video Room (`/api/consultation/create`)
- **Name**: Create Consultation Room
- **Method**: `POST`
- **URL**: `https://app.drgodly.com/api/consultation/create`
- **Headers**: `Authorization: Bearer <EdDSA_JWT>`, `Content-Type: application/json`
- **Request Body**: `{"fhir_appointment_id": 1042}`
- **Success Response (200 OK / 201 Created)**: Returns room metadata and status.
- **Called in Code**: [`lib/data/repository/booking_repository.dart:210`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart#L210) (`provisionConsultationRoom()`).
