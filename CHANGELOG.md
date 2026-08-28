# Changelog

All notable changes to Trackpad Wizard are documented here.

## Unreleased

- Added normalized near-stepless amplitude control to enhanced haptic pulses.
- Added a live custom signal with independent amplitude and 8–120 Hz pulse-frequency controls.
- Added per-step amplitude editing, legacy saved-pattern migration, and amplitude-shaped presets including Quiet Click.
- Corrected the private actuator function signature so its waveform parameters use the floating-point ABI expected by MultitouchSupport.
- Added a persistent one-click switch for hiding sidebar descriptions and explanatory hint cards.
- Added a native Xcode project and explicit app metadata so Xcode builds consistently include the application icon.
- Relicensed the project under MPL-2.0 and expanded third-party research notices.

## 0.1.0 - 2026-08-27

- Initial native SwiftUI macOS application.
- Added Touch Lab, Gesture Studio, Haptic Composer, mappings, and device diagnostics.
- Added explicit public and opt-in enhanced modes.
- Added local JSON session export with privacy boundaries.
- Added SwiftPM tests, release builds, app-bundle assembly, and verified codesigning.
