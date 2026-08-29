# Changelog

All notable changes to Trackpad Wizard are documented here.

## 0.2.0 - 2026-08-28

- Unified enhanced raw touch and direct actuator control behind a compact, global Enhanced Mode switch with shared device targeting.
- Added optional process-scoped system-gesture suppression that automatically disappears after crash or force-quit and never edits trackpad preferences.
- Added background lifecycle controls; Enhanced Mode defaults off when the app becomes inactive and always stops during termination.
- Added a resizable/full-screen touch preview with Fit, Enlarged, and display-calibrated Physical Size modes.
- Added the Trackpad Haptic Pattern schema v1 with click recording, persistent library storage, replay, JSON import/export, validation, amplitude, timing, and pulse frequency.
- Added persistent per-device haptic oscillation statistics, daily graphs, collection controls, and reset without global click monitoring or power assertions.
- Added configurable trail lifetime, heatmap half-life, fade refresh rate, and adaptive card layouts.
- Added a native About window with runtime bundle version/build metadata and JASON Studio attribution.
- Updated trackpad, permission, and experimental icons and corrected built-in USB identity to Internal.
- Added separately gated Advanced Features controls for surface orientation and macOS system haptics, with exact-state confirmation rollback and default restoration when a feature flag is disabled.
- Added native 0°/180° surface orientation plus clearly labeled app-coordinate 90°/270° rotation for the current runtime, which rejects quarter-turn surface reports.
- Added an unclean-session recovery marker so a confirmed private override can be restored to the selected target's macOS default on the next launch after interrupted cleanup.
- Consolidated preview controls across Touch Lab and Gesture Studio, added status indicators to macOS trackpad settings, and moved sidebar counts into their corresponding rows.
- Required Apple Development signing for Xcode test and verification builds.
- Replaced the nested-box icon with a macOS 26/27 Icon Composer source: six scalable dot/ripple layers, adaptive Default/Dark/tinted/clear renditions, and verified 16–1024 px fallback output.

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
