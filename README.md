# 🔐 OneRule
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**OneRule is a 100% offline, zero-knowledge password manager for Android, built to protect your secrets with uncompromising privacy.**

[![License](https://img.shields.io/badge/License-[Insert%20License]-blue.svg)](./LICENSE)
[![Google Play](https://img.shields.io/badge/Google%20Play-Available%20Now-34A853?logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.fidevelopment.onerule)
[![Build Status](https://img.shields.io/badge/Build-[Insert%20Status]-orange.svg)]([Insert-CI-Link])

---

## ✨ Core Features

- **100% Offline by Design**  
  OneRule is designed to work fully offline and should require **no internet permission**.
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

## 📸 Screenshots

| Vault | Settings | Password Generator |
|---|---|---|
| ![Vault Screenshot](assets/screenshots/2.jpeg) | ![Settings Screenshot](assets/screenshots/1.jpeg) | ![Password Generator Screenshot](assets/screenshots/5.jpeg) |

---

## 🛡️ Security Architecture

OneRule follows a local-first security architecture where all critical operations happen on-device.

1. **Master Secret Handling**  
   The user provides a master password/PIN, which is transformed using **[Insert KDF, e.g., Argon2id / PBKDF2]** with **[Insert Salt Strategy]**.
2. **Vault Encryption**  
   Vault records are encrypted locally using **[Insert Encryption Method, e.g., AES-256-GCM / ChaCha20-Poly1305]**.
3. **Integrity Protection**  
   Data tampering is detected using **[Insert Integrity Mechanism, e.g., AEAD tag / HMAC-SHA256]**.
4. **Key Storage Boundary**  
   Encryption material is stored using **[Insert Secure Storage Method, e.g., Android Keystore / EncryptedSharedPreferences]** where applicable.
5. **Zero-Transmission Principle**  
   Secrets are never transmitted to external servers by default.

> Important: Fill in all placeholders before final public release so security claims are fully auditable.

---

## 🧪 Build From Source (Android Studio)

Privacy-conscious users can build OneRule locally and verify behavior themselves.

### Prerequisites

- Android Studio (latest stable)
- Android SDK + platform tools
- [If applicable] Flutter SDK: **[Insert Required Version]**
- Git

### Steps

1. **Clone the repository**
   ```bash
   git clone [Insert-Repo-URL]
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

---

## 🧰 Tech Stack

> Replace placeholders with your final stack.

- **Language:** [Kotlin / Dart]
- **UI:** [Jetpack Compose / Flutter]
- **Local Database:** [Room / Hive / SQLCipher]
- **State Management:** [Insert State Management]
- **Crypto & Secure Storage:** [Insert Security Libraries]
- **Architecture:** [Insert Architecture Pattern]

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

Report it privately via email: **[security@fisoftware.com]**  
Alternative contact: **[Insert Security Contact Email]**

We will investigate and coordinate responsible disclosure.

---

## 📄 License & Copyright

**Copyright © 2026 FI Software.**  
Licensed under **[Insert License, e.g., GPLv3 / MIT / Apache-2.0]**.

See [`LICENSE`](./LICENSE) for full terms.

## 📄 License
"This project is licensed under the **GNU General Public License v3.0**. 

Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. This ensures that OneRule remains free, open, and secure for everyone.

For more details, see the [LICENSE](LICENSE) file in the root directory.

Copyright © 2026 FI Software. All rights reserved."


