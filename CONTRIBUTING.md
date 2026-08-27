# Contributing

Trackpad Wizard currently accepts changes by prior arrangement with the copyright holder.

## Development requirements

- macOS 26 or later
- Xcode 26 or later
- Swift 6.2 or later

Before proposing a change, run:

```sh
./script/check.sh
./script/build_and_run.sh --verify
```

Keep public AppKit behavior separate from runtime-loaded private APIs. Do not add Bluetooth addresses, serial-like identifiers, private actuator identifiers, exported touch sessions, signing certificates, provisioning profiles, credentials, or local diagnostics to source control.

Changes that affect private framework behavior must describe the tested macOS version and hardware class. Do not claim Mac App Store compatibility while enhanced mode remains present.
