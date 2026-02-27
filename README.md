# 🔐 OneRule

**OneRule is a 100% offline, zero-knowledge password manager for Android, built to protect your secrets with uncompromising privacy.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Google Play](https://img.shields.io/badge/Google%20Play-Available%20Now-34A853?logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.fidevelopment.onerule)

---

## ✨ Core Features

- **100% Offline by Design**  
  OneRule is designed to work fully offline and does not rely on backend services for vault operations.
- **Zero-Knowledge Security Model**  
  Your vault is encrypted locally. Only you hold the credentials needed to unlock it.
- **Strong Local Encryption**  
  Sensitive data is protected at rest using modern cryptographic primitives.
- **Privacy First**  
  No cloud sync, no remote telemetry by default, no third-party data processing of your vault contents.

---

## 📱 On Google Play

OneRule is in production and publicly available on Google Play:  
https://play.google.com/store/apps/details?id=com.fidevelopment.onerule

---

## 🌐 Live Website

GitHub Pages landing page:  
https://seralifatih.github.io/OneRuleWeb/

---

## 📸 Screenshots

| Vault | Settings | Password Generator |
|---|---|---|
| ![Vault Screenshot](assets/screenshots/2.jpeg) | ![Settings Screenshot](assets/screenshots/1.jpeg) | ![Password Generator Screenshot](assets/screenshots/5.jpeg) |

---

## 🔒 Security

- Canonical security spec: [docs/security-architecture.md](docs/security-architecture.md)
- Vault data at rest: SQLCipher-encrypted SQLite + app-level AES-256-GCM for the sensitive password field
- PIN/key derivation: PBKDF2-HMAC-SHA256 (100k iterations) with per-install/per-secret salts in secure storage
- Backup encryption: passphrase-based AES-256-GCM backups (`.enc`) with PBKDF2-HMAC-SHA256 (200k iterations)

Use the security architecture document above as the source of truth for implementation details and threat model assumptions.

---

## ☕ Support Development

Built by one developer. Your support helps keep OneRule offline and maintained.

- Buy me a coffee: https://buymeacoffee.com/seralifatih

---

## 🧪 Build From Source (Android Studio)

Privacy-conscious users can build OneRule locally and verify behavior themselves.

### Prerequisites

- Android Studio (latest stable)
- Android SDK + platform tools
- Flutter SDK: **3.38.7 (stable)** (Dart 3.10.7; project constraint `sdk: >=3.2.3 <4.0.0`)
- Git

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/seralifatih/OneRule.git
   cd onerule
   ```
2. **Install dependencies**
   ```bash
   flutter pub get
   ```
3. **(Optional) Generate localization/resources**
   ```bash
   flutter gen-l10n
   ```
4. **Open in Android Studio**
   - Open the project folder.
   - Let Gradle/SDK indexing complete.
5. **Run on device/emulator**
   ```bash
   flutter run
   ```
6. **Build release artifact**
   ```bash
   flutter build apk --release
   ```

### Deterministic Android Release Validation (Windows)

To avoid mixed Flutter artifacts and startup crashes on device, run:

```powershell
.\scripts\android-release-validate.ps1
```

Full checklist and fallback commands:
- [docs/android-release-checklist.md](docs/android-release-checklist.md)

---

## 🧰 Tech Stack

- **Language:** Dart
- **UI:** Flutter (Material)
- **Local Database:** SQLite via **SQLCipher** (`sqflite_sqlcipher`)
- **State Management:** Provider
- **Crypto & Secure Storage:** `cryptography`, `flutter_secure_storage`, `local_auth`, SQLCipher
- **Architecture:** Layered Flutter app (UI/screens -> Provider state -> service/facade layer)

---

## 🤝 Contributing

Contributions are welcome via Pull Requests.

1. Fork the repository.
2. Create a feature branch.
3. Make focused, testable changes.
4. Open a Pull Request with clear context and screenshots (if UI-related).

Please keep PRs small and security-aware.

### 🔒 Security Policy

If you discover a security vulnerability, **do not open a public GitHub issue**.

Report it privately via email: **oneruleapp@gmail.com**  

We will investigate and coordinate responsible disclosure.

---

## 📄 License & Copyright

**Copyright © 2026 FI Software.**  
Licensed under **GNU General Public License v3.0 (GPL-3.0)**.

See [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0) for full terms.
