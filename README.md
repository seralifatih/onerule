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

## 🛡️ Security Architecture

OneRule follows a local-first security architecture where all critical operations happen on-device.

1. **Master Secret Handling**  
   The user provides a master password/PIN, which is transformed using **PBKDF2-HMAC-SHA256 (100,000 iterations, 256-bit output)** with **per-secret 16-byte random salts stored in secure storage (`masterPinSalt`, `hiveSalt`, `panicPinSalt`)**.
2. **Vault Encryption**  
   Vault records are encrypted locally using **HiveAesCipher (AES-256-CBC with PKCS7 padding and a random 16-byte IV)**.
3. **Integrity Protection**  
   Encrypted backup payload tampering is detected using **AES-GCM authentication tags (`mac`)**. (Vault storage encryption currently uses AES-CBC without a separate AEAD tag.)
4. **Key Storage Boundary**  
   Encryption material is stored using **Flutter Secure Storage (Android `EncryptedSharedPreferences`, backed by Android Keystore)** where applicable.
5. **Zero-Transmission Principle**  
   Secrets are never transmitted to external servers by default.

> Security details above reflect the current implementation in this repository.

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

---

## 🧰 Tech Stack

- **Language:** Dart
- **UI:** Flutter (Material)
- **Local Database:** Hive (`HiveAesCipher` encrypted box)
- **State Management:** Provider
- **Crypto & Secure Storage:** `cryptography`, `flutter_secure_storage`, `local_auth`, Hive `HiveAesCipher`
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

Report it privately via email: **security@fisoftware.com**  
Alternative contact: **oneruleapp@gmail.com**

We will investigate and coordinate responsible disclosure.

---

## 📄 License & Copyright

**Copyright © 2026 FI Software.**  
Licensed under **GNU General Public License v3.0 (GPL-3.0)**.

See [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0) for full terms.
