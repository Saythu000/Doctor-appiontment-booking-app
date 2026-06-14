# Architecture.md - PHIA Health Flutter Project

## Overview
PHIA is a health monitoring application built with Flutter, designed to track patient vitals, activity levels, and specialist bookings. The application follows a Clean Architecture approach, ensuring a clear separation of concerns between business logic, data access, and presentation.

## Architectural Pattern
The project utilizes the **MVVM (Model-View-ViewModel)** pattern integrated within a layered architecture.

### Layered Structure

1.  **Domain Layer (`lib/domain/`)**
    *   **Purpose:** The heart of the application, containing business entities and repository contracts. It is agnostic of any platform-specific dependencies or frameworks.
    *   **Key Components:** 
        *   `model/`: Plain Dart classes defining the core entities (e.g., `patient_profile.dart`, `health_metrics.dart`).
        *   `repository/`: Abstract interfaces defining data operations (e.g., `i_health_repository.dart`).
        *   `service/`: Interface definitions for platform-specific services (sensors, sensors).

2.  **Data Layer (`lib/data/`)**
    *   **Purpose:** Responsible for data retrieval and persistence. It implements the interfaces defined in the domain layer.
    *   **Key Components:**
        *   `repository/`: Concrete implementations of domain repositories (e.g., `auth_repository.dart`).
        *   `service/`: Concrete service implementations (e.g., `fhir_api_client.dart` for remote APIs, `pedometer_sensor.dart` for hardware sensors).
        *   `database/`: SQFlite local persistence implementation.

3.  **ViewModel Layer (`lib/viewmodel/`)**
    *   **Purpose:** Manages UI state and acts as the bridge between the View and Domain/Data layers.
    *   **Key Components:** Extends `ChangeNotifier` to expose state to the UI via the `Provider` pattern. Logic within ViewModels processes data before presenting it to the View.

4.  **View Layer (`lib/view/`)**
    *   **Purpose:** Handles the presentation layer, building the UI using Flutter widgets.
    *   **Key Components:** Feature-grouped screen widgets organized by module (e.g., `auth`, `booking`, `dashboard`). Utilizes custom widgets from `lib/core/widgets/` for design consistency.

## Dependency Injection
The project uses the **Provider** package for dependency injection and state management.
*   **Central Config:** `lib/main.dart` configures `MultiProvider` at the root of the widget tree.
*   **Provisioning:** Services and Repositories are injected as providers, allowing ViewModels to consume them via `context.read<T>()` or `context.watch<T>()`.

## Core Infrastructure (`lib/core/`)
*   `database/`: Infrastructure for local storage.
*   `routing/`: Definition of navigation flows.
*   `theme/`: Design system tokens including `colors.dart`, `typography.dart`, and visual effects like `scanline_effect.dart`.
*   `widgets/`: Reusable, project-wide UI components.

## Communication Patterns
*   **Reactive State:** `ChangeNotifier` / `ListenableBuilder` used for UI updates.
*   **Asynchronous Processing:** `Future` and `Stream` patterns used for network calls and sensor data acquisition respectively.
*   **External Data:** FHIR-compliant API interaction via `Dio` clients in `lib/data/service/`.

## Design System
*   **Theming:** Centralized `ThemeData` based on Material 3 principles.
*   **Typography:** Custom typography system defined in `typography.dart`.
*   **Visuals:** Custom UI effects (scanlines, dot matrix) to enforce the PHIA visual identity.
