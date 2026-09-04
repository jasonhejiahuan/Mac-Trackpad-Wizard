# Security Policy

Thank you for helping keep Mac Trackpad Wizard and its users secure.

---

## Supported Versions

Security fixes are currently provided for the latest version on the default branch.

| Version | Supported |
| :--- | :---: |
| Latest default branch | ✅ |
| Older revisions | ❌ |

> [!NOTE]
> Mac Trackpad Wizard uses private macOS APIs for certain trackpad functionality. Changes to these APIs between macOS releases may cause compatibility issues and are not necessarily security vulnerabilities.

---

## Reporting a Vulnerability

> [!IMPORTANT]
> **Do not open a public issue for a suspected security vulnerability.**

Contact the repository owner privately through their GitHub profile without including exploit details in the initial message.

Once a private communication channel has been established, please provide:

| Information | Description |
| :--- | :--- |
| **Summary** | A clear description of the vulnerability |
| **Impact** | The potential security impact |
| **Reproduction** | Steps required to reproduce the issue |
| **Affected revision** | The affected version, commit, or branch |
| **Environment** | Relevant macOS version and hardware configuration |

Please remove personal or device-identifying information from logs and diagnostic material before sharing it.

---

## Security Scope

Mac Trackpad Wizard does **not** require administrator privileges for its normal operation and does not intentionally access:

- User passwords or credentials
- Keychain contents
- Authentication tokens
- Personal documents or files
- Other sensitive user data

The project does use private macOS APIs for enhanced trackpad functionality.

Issues involving private API compatibility, unsupported macOS versions, unexpected haptic behaviour, or ordinary application crashes should generally be reported through the public issue tracker unless they create a meaningful security impact.

---

## Responsible Disclosure

Please allow reasonable time for a reported vulnerability to be investigated and, where appropriate, addressed before publicly disclosing technical details.

As this project is independently maintained, no specific response time, remediation timeline, or disclosure date is guaranteed.

---

## Where Should I Report It?

| Issue | Reporting Channel |
| :--- | :---: |
| Security vulnerability | Private |
| Privilege or permission bypass | Private |
| Unexpected access to user data | Private |
| Private API compatibility issue | Public issue |
| Trackpad or haptic malfunction | Public issue |
| Application crash | Public issue |
| Feature request | Public issue |
