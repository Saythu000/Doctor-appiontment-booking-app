# 02. Architectural Principles & Industry Standards Compliance

## Plain-Language Summary
This section provides an objective, code-verified audit of the software engineering principles applied in the PHIA codebase. We evaluate core engineering patterns (SOLID, Separation of Concerns, Repository Pattern, DRY, Error Handling, Logging, and Code Linting) against globally recognized industry benchmarks, including the **Google Android Architecture Guidance**, **Clean Architecture guidelines**, and the **OWASP Mobile Application Security Verification Standard (MASVS)**. 

Gaps are documented transparently alongside actionable remediation steps.

---

## 1. Compliance Matrix: Principles vs. Industry Standards

The table below summarizes each engineering principle, where it is implemented in the repository, the governing industry standard, its verified compliance status (**Met**, **Partial**, or **Not met**), and any technical gaps identified in the code.

| Principle | Where Applied (Files & Classes) | Industry Standard | Status | Identified Code Gap |
|---|---|---|---|---|
| **Separation of Concerns (SoC)** | • `lib/view/` (Presentation)<br>• `lib/viewmodel/` (State/Logic)<br>• `lib/data/repository/` (Data)<br>• `lib/data/service/` (Network/Sensors) | Google Android Architecture Guidance (Layered Architecture); Clean Architecture | **Met** | UI widgets strictly observe ViewModels via Provider and do not invoke raw HTTP endpoints or direct SQLite database queries. |
| **Repository Pattern** | • `BookingRepository`<br>• `AuthRepository`<br>• `ProfileRepository`<br>• `VitalsRepository`<br>• `HealthRepository` | Google Android Guide to App Architecture (Data Layer - Single Source of Truth) | **Partial** | Repositories manage data fetching and SQLite caching, but they are concrete classes without abstract interfaces (e.g., `IBookingRepository` is absent), making dependency inversion and unit test mocking harder. |
| **Single Responsibility Principle (SRP)** | • `IntakeService` (Network)<br>• `BleHeartRateService` (GATT)<br>• `PkceHelper` (Crypto)<br>• `SqfliteDatabaseHelper` (DB) | SOLID (Robert C. Martin); Clean Code | **Partial** | Highly focused utility and service classes, but `AuthViewModel` ([`auth_viewmodel.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/viewmodel/auth_viewmodel.dart)) contains over 600 lines coordinating OAuth, legacy login, biometric refresh, and profile syncing in one class. |
| **Open/Closed Principle (OCP)** | • `WearableProviderType` extension<br>• `IntakeStreamChunk` switch handling | SOLID (Open for extension, closed for modification) | **Partial** | Adding new wearable device types or FHIR observation codes requires modifying existing switch statements and enum extensions rather than plugging in new strategy classes. |
| **Liskov Substitution Principle (LSP)** | • `ChangeNotifier` derivatives in `lib/viewmodel/` | SOLID | **Met** | ViewModels properly extend Flutter's `ChangeNotifier` and can be substituted transparently across `ChangeNotifierProvider` declarations. |
| **Interface Segregation Principle (ISP)** | • `lib/data/service/` | SOLID | **Not met** | Services expose large monolithic API interfaces. There are no segregated interfaces (e.g. `IHealthReader`, `IHealthWriter`) representing granular consumer requirements. |
| **Dependency Inversion Principle (DIP)** | • `MultiProvider` in `lib/main.dart` | SOLID; OWASP MASVS-ARCH-1 | **Partial** | ViewModels receive Repositories via constructor injection, but they depend on concrete implementations rather than abstractions/interfaces (`BookingRepository` instead of `IBookingRepository`). |
| **Don't Repeat Yourself (DRY)** | • `ApiConstants`<br>• `PhiaColors`<br>• `PhiaTypography`<br>• `ImageHelper` | Pragmatic Programmer DRY Principle | **Met** | API endpoints, color palettes, card themes, and typography definitions are centralized into reusable constants without copy-paste duplicates. |
| **Error Handling & Fault Tolerance** | • `lib/viewmodel/intake_viewmodel.dart`<br>• `lib/data/service/fhir_api_client.dart` | OWASP MASVS-RESILIENCE; Google Robust App Architecture | **Partial** | Network calls and streaming responses are wrapped in `try/catch` with fallback values, but error types are largely generic `catch (e)` without categorized domain failure objects (e.g. `NetworkException`, `AuthExpiredException`). |
| **Logging & Telemetry** | • `print(...)` in `lib/data/`<br>• `debugPrint(...)` in `lib/viewmodel/` | OWASP MASVS-CODE-2 (No sensitive logs in release); Android Logging Best Practices | **Partial** | Debug logs use `if (kDebugMode) print(...)` and `debugPrint`, but the codebase lacks an enterprise structured logging framework (e.g. `logger` package or Crashlytics breadcrumbs). There are 96 raw `print` statements in `lib/`. |
| **Code Style & Static Linting** | • `analysis_options.yaml`<br>• `flutter_lints: ^5.0.0` | Official Effective Dart Guide | **Met** | Passes `flutter analyze` with 0 errors and 0 warnings (1 minor info on unnecessary import). Adheres to official Flutter style and naming conventions. |

---

## 2. Technical Evaluation of Implemented Principles

### Plain-Language Summary
The application follows clean architectural separation between presentation and data sources. The biggest opportunities for improvement lie in creating formal abstract interfaces and cleaning up raw console print statements.

### Technical Detail

#### A. Separation of Concerns (SoC) & Repository Pattern
- **Implemented**: The application adheres strictly to the separation of concerns. UI files inside `lib/view/` never import `dio`, `sqflite`, or low-level platform channels. 
- **Code Proof**: 
  - [`lib/view/booking/select_specialist_screen.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/view/booking/select_specialist_screen.dart): UI binds to `BookingViewModel.specialists`. It does not know whether data arrived via FHIR REST or the offline SQLite cache.
  - [`lib/data/repository/booking_repository.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/repository/booking_repository.dart): Encapsulates both `FhirApiClient` queries and fallback reading from `SqfliteDatabaseHelper`.
- **Gap**: Repositories are concrete classes. To achieve 100% adherence to Google's Recommended Architecture, an abstract contract (`abstract class IBookingRepository`) should be introduced.

#### B. Error Handling & Resilience
- **Implemented**:
  - The streaming AI client in [`lib/data/service/intake_service.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/intake_service.dart#L86-L91) isolates network failures during stream initialization from SSE line parse failures.
  - The offline FHIR client in [`lib/data/service/fhir_api_client.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/data/service/fhir_api_client.dart#L20-L50) intercepts timeouts and unhandled server errors, falling back to local cached directory entries.
- **Gap**: ViewModels convert exceptions directly to UI strings:
  ```dart
  // Found in intake_viewmodel.dart:133
  _errorMessage = 'Stream error: ${err.toString().replaceFirst("Exception: ", "")}';
  ```
  Industry best practice is to map raw exceptions to typed UI Failure models (`Failure.noInternet()`, `Failure.serverUnavailable()`, `Failure.sessionExpired()`).

#### C. Logging & OWASP MASVS Compliance
- **Implemented**: Production credentials and tokens are masked or stripped from standard logs. Cryptographic PKCE challenge logic is isolated in [`lib/core/auth/pkce_helper.dart`](file:///home/mi/Desktop/AI_projects/phia_flutter/lib/core/auth/pkce_helper.dart).
- **Gap**: 
  - There are **96 raw `print()`** calls throughout `lib/`. While many are wrapped in `if (kDebugMode)`, raw `print` statements on Android output to logcat and can slow down the Dart UI thread under heavy load.
  - **Remediation**: Migrate all logging calls to a dedicated logger service or `debugPrint`.

---

## 3. Open Questions / Assumptions / Items to Verify

1. **Abstract Interfaces for Repositories**: Verify if introducing abstract repository contracts (`IBookingRepository`, `IAuthRepository`) is desired for automated mock testing with `mockito` or `mocktail`.
2. **Unified Error Model**: Verify if a centralized `Result<T, Failure>` pattern (e.g. using `dartz` or `fpdart`) should be introduced to standardize API error propagation.
3. **Structured Logger**: Verify if console `print` calls should be replaced with a structured logging framework before production deployment to Google Play.
