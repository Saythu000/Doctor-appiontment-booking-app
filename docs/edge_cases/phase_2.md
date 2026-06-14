# Edge Cases - Phase 2: Core Feature Expansion

- **Sensor Data Loss/Interruption:** Pedometer/GPS services failing due to OS background restrictions, device reboot, or sensor hardware failure.
- **Sync Conflicts:** Data updated locally in SQFlite while the device is offline, colliding with updates on the FHIR server upon reconnection.
- **Malformed/Invalid FHIR Responses:** API returning unexpected JSON structure or data types.
- **Threshold Triggers:** Rapid fluctuations in health metrics causing notification spam.
