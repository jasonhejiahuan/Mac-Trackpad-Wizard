# Trackpad Wizard

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-blue)](LICENSE)

Trackpad Wizard is a native SwiftUI macOS utility for exploring the built-in trackpad and external Magic Trackpads. It combines public AppKit behavior with a clearly separated, session-only experimental engine for capabilities Apple does not expose publicly.

The interface targets macOS 26 or later and uses the current system Liquid Glass materials, sidebar/window conventions, semantic colors, and SF typography. It intentionally avoids decorative gradients or colorful page backgrounds.

## What it does

- **Touch Lab** — live contacts, resting touches, stable contact labels, trails, a monochrome heatmap, sample-rate estimates, Force Click pressure, and JSON session export.
- **Gesture Studio** — live magnification, rotation, precision scrolling, swipes, pressure stages, gesture lifecycle events, and derived three-finger directions.
- **Haptic Composer** — system-safe feedback, empirical actuator waveforms, per-pulse near-stepless amplitude, device routing, amplitude-shaped presets, a 16-step pattern editor, and a custom 8–120 Hz press-and-hold signal.
- **Mappings** — map swipes, pinches, rotation, or Force Click to keyboard shortcuts or haptic patterns. Shortcut capture uses native key events; keyboard injection is gated behind explicit Accessibility permission.
- **Devices** — live I/O Registry discovery, transport, battery when reported, Force Touch capability, report interval/rate, USB VID/PID, and current user trackpad preferences.
- **Privacy boundaries** — no Bluetooth address, serial-like value, or private actuator identifier is displayed or exported. Touch data remains local unless the user explicitly exports a session.

## Public and enhanced modes

| Capability | System mode | Enhanced mode |
| --- | --- | --- |
| Haptic API | `NSHapticFeedbackManager` | Runtime-loaded `MultitouchSupport.framework` actuator |
| Available patterns | Alignment, Level Change, Generic | Empirical waveform IDs 1–6, 15, and 16 |
| Amplitude | Chosen by macOS | Normalized 0–100% empirical waveform multiplier |
| Frequency | Not exposed | Direct 8–120 Hz pulse-repetition control |
| Routing | Chosen by macOS | All, built-in, or external trackpad |
| Touch input | `NSTouch` while the pointer is over the capture surface | Raw contact callback for one selected device |
| Pressure | AppKit pressure and Force Click stage | Contact area proxy plus cumulative-pressure field |
| Distribution | Uses public API | Private API; not appropriate for the Mac App Store |
| Persistence | Normal app setting | Opt-in for the current process only |

Apple’s public haptic API deliberately does not expose strength, duration, arbitrary waveform, or device targeting. System mode therefore cannot honor a composed amplitude. Enhanced mode uses the private actuator call’s floating-point waveform multiplier for close-to-stepless amplitude and schedules impulses at the selected pulse frequency. That frequency is repetition rate, not arbitrary control of the actuator’s internal carrier; the hardware still renders an empirical base waveform and quantizes the physical result.

The presets now use amplitude envelopes rather than relying only on coarse strong/medium/weak waveform changes. **Quiet Click** is intentionally restrained and inspired by the feel of macOS Silent Clicking, but it does not modify the system’s trackpad preference and is not claimed to be Apple’s exact private tuning.

If explicit enhanced routing targets an unavailable built-in or external trackpad, Trackpad Wizard does not silently actuate another device. “All Trackpads” may fall back to the system performer if the private call fails.

## Build and run

Requirements:

- macOS 26 or later
- Xcode 26 or later; the project also builds with the current Xcode 27 beta and Swift 6.4

Open `Package.swift` in Xcode, or run:

```sh
./script/build_and_run.sh
```

Useful variants:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --debug
./script/build_and_run.sh --logs
./script/check.sh
```

The runner selects `/Applications/Xcode-beta.app` first when `DEVELOPER_DIR` is unset, assembles `dist/Trackpad Wizard.app`, and uses a local Apple Development signing identity when available. Otherwise it uses ad-hoc signing. A Codex Run action is included in `.codex/environments/environment.toml`.

Signing can be selected explicitly without storing identity data in the repository:

```sh
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" \
./script/build_and_run.sh --verify
```

The bundle version is automatic: the latest `vX.Y.Z` Git tag is used when present, otherwise the newest version in `CHANGELOG.md` is used. The Git commit count becomes the bundle build number.

The assembled app is signed with hardened runtime enabled and then checked with `codesign --verify --deep --strict`. Local Development signing is suitable for development and testing. Public distribution additionally requires a Developer ID archive, secure timestamping, notarization, and stapling; those credentials are deliberately not part of this repository.

`script/check.sh` uses the same Xcode selection logic, runs all tests, and performs an optimized Release build.

Regenerate the editable neutral icon with:

```sh
./script/generate_icon.sh
```

## Permission behavior

Trackpad Wizard never opens a permission prompt during model initialization or before the main window appears. Accessibility is requested only from the user-facing **Request Access…** button and is needed only to post keyboard shortcuts. Touch inspection, device diagnostics, and haptic playback do not require Accessibility.

## Research basis

- Apple’s [`NSHapticFeedbackManager`](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager) defines the public fallback and its three patterns.
- [`HapticKey`](https://github.com/niw/HapticKey) documents the private actuator ABI’s two floating-point parameters and provides a long-lived compatibility reference.
- [`mactic`](https://github.com/MatMercer/mactic) demonstrates current runtime lookup for both raw multitouch callbacks and actuator waveform calls.
- [`Tactile`](https://github.com/Mason363/Tactile) demonstrates practical built-in/external routing with `MTDeviceGetDeviceID` and a public fallback.
- [`OpenMultitouchSupport`](https://github.com/Kyome22/OpenMultitouchSupport) and [`macos-trackpad-demo`](https://github.com/shaunlebron/macos-trackpad-demo) informed touch lifecycle and AppKit capture boundaries.
- [`mac-precision-touchpad`](https://github.com/imbushuo/mac-precision-touchpad) is a Windows Precision Touchpad driver; it is useful evidence for contact/pressure parsing, not a macOS haptic implementation.
- [`magictrackpad2-dkms`](https://github.com/robbi5/magictrackpad2-dkms) is an older Linux DKMS input driver; it likewise informs raw reports but provides no macOS actuator control.
- NotchNook is closed source, so only its observable tactile interaction is treated as product inspiration. No claim is made about its internal implementation.

No code from either GPL driver is included. See `THIRD_PARTY_NOTICES.md` for the reference-only provenance and licensing notes.

## Project policy

- See [CONTRIBUTING.md](CONTRIBUTING.md) for development and verification requirements.
- Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).
- Releases and compatibility changes are recorded in [CHANGELOG.md](CHANGELOG.md).
- Copyright and reuse terms are in [LICENSE](LICENSE).

## Known constraints

- AppKit indirect touches are view-scoped by design; keep the pointer over a capture surface.
- Enhanced touch streams one selected device because raw callbacks do not provide a public, stable aggregation layer.
- macOS may consume system gestures such as Mission Control before an app receives them.
- Private framework symbols, contact layouts, and waveform meanings can change without notice.
- Enhanced amplitude and pulse frequency are empirical controls; output resolution and feel vary by trackpad hardware and firmware.
- The project is intentionally unsandboxed for local experimentation. A public-only distribution build should remove the two enhanced service files and expose only System mode.
