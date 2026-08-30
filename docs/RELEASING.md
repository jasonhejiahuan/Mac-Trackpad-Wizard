# Releasing Trackpad Wizard

## Release metadata

The first release heading in `CHANGELOG.md` is the release source of truth:

```text
## Version 0.2.1 (Build 3) - 2026-08-30
```

`Version` must match Xcode `MARKETING_VERSION`, and `Build` must match the monotonically increasing `CURRENT_PROJECT_VERSION`. `script/release_metadata.sh` rejects a mismatch before signing or notarization. The same values determine the app metadata, DMG name and volume name, Git tag, and GitHub Release title.

## Local first run

The local pipeline finds the installed `Developer ID Application` certificate for team `WBU2AFY549`, builds a universal app, verifies its signature, lays out and signs the DMG, and writes a SHA-256 checksum.

To test packaging without contacting Apple’s notary service:

```sh
./script/release_local.sh --package-only
```

That artifact is signed but intentionally labeled **not notarized**. For the release-ready path, first store notarization credentials in the login Keychain, then pass that profile explicitly:

```sh
xcrun notarytool store-credentials trackpad-wizard
./script/release_local.sh --notary-profile trackpad-wizard
```

The second command submits the signed DMG, waits for acceptance, staples the ticket, validates the staple, and asks Gatekeeper to assess the disk image.

## GitHub Actions credentials

The manual workflow requires these repository secrets:

- `DEVELOPER_ID_APPLICATION_CERT_BASE64` — base64-encoded `.p12` containing the Developer ID Application certificate and private key.
- `DEVELOPER_ID_APPLICATION_CERT_PASSWORD` — password for that `.p12`.
- `APP_STORE_CONNECT_API_KEY_P8_BASE64` — base64-encoded App Store Connect API private key.
- `APP_STORE_CONNECT_API_KEY_ID` — API key ID.
- `APP_STORE_CONNECT_API_ISSUER_ID` — issuer UUID for a team API key.

The workflow uses a temporary Keychain and deletes it after the job. It always uploads the notarized DMG as a workflow artifact. Creating a public GitHub Release is a separate, default-off manual choice.

## Automatic releases

Automatic triggering is intentionally disabled before the first public release. When it is time to enable it, add this event next to `workflow_dispatch` in `.github/workflows/release.yml`:

```yaml
push:
  branches: [main]
  paths:
    - CHANGELOG.md
```

The existing guard skips a push when the top CHANGELOG version/build tag already exists. A new top release heading therefore follows the same signed, notarized, stapled DMG path as a manual run.

The installer artwork is stored as 1x and 2x PNGs in `Assets/DMG`. The layout script embeds both files and uses the 1x asset as the Finder background while macOS selects the Retina companion when appropriate.
