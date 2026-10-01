# Project Rules

These rules must be strictly followed in all future development tasks for this Flutter project:

- **Target Android Versions:** Target Android 14 to 16 (`minSdk 34`, `targetSdk 36` or latest stable).
- **Behavior Preservation:** Do not change behavior unless explicitly asked. Refactors must be behavior-preserving.
- **Single-Feature Scope:** Never modify more than one feature per task.
- **Continuous Verification:** After every change, run `flutter analyze` and `flutter test` and report the results.
- **Security & Secrets:** Never hardcode secrets, API keys, or URLs.
- **Privacy & Compliance:** Never log health data or personal data.
- **Transparency:** Explain every file you change in a short summary.
