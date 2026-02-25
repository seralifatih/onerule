# Security Architecture

Version: 2026-02-24
Status: Current implementation snapshot from this repository.

## 1) Data at Rest

- Primary vault storage is an encrypted SQLite database via SQLCipher (`sqflite_sqlcipher`), file name `onerule_vault.db`.
- SQLCipher database password is derived from the in-memory session key as `base64UrlEncode(sessionKey)`.
- SQLCipher cipher internals are not overridden by custom `PRAGMA cipher_*` settings in this app code; runtime uses SQLCipher defaults from the bundled library build.
- The `password` column is additionally encrypted at the application layer using AES-256-GCM.
- Field-level AES-GCM payload format is versioned:
  - `or1:v2:gcm:<nonce_b64url>:<cipherText_b64url>:<tag_b64url>`
  - `nonce`: 12 random bytes
  - `tag`: 16-byte authentication tag (MAC)
  - all binary segments are base64url-encoded.

## 2) Key Derivation and Key Storage

Current implementation has two PBKDF2 profiles:

- PIN KDF (vault unlock/session key path):
  - algorithm: PBKDF2-HMAC-SHA256
  - iterations: 100,000
  - output size: 256 bits (32 bytes)
  - salt: 16 random bytes
  - memory/parallelism: not configurable for PBKDF2 in this codepath (N/A).
- Backup passphrase KDF (backup import/export):
  - algorithm: PBKDF2-HMAC-SHA256
  - iterations: 200,000
  - output size: 256 bits (32 bytes)
  - salt: 16 random bytes
  - memory/parallelism: not configurable for PBKDF2 in this codepath (N/A).

Salt storage and scope:

- PIN/session salt is persisted in secure storage key `hiveSalt` (base64url).
  - generated on first derivation, and rotated when PIN is changed (`rotateSalt: true`).
- Master PIN verifier salt is persisted as `masterPinSalt` with verifier `masterPinHash`.
- Panic PIN verifier salt is persisted as `panicPinSalt` with verifier `panicPinHash`.
- Backup salt is stored inside each backup file payload (`salt` field), not in device secure storage.

Key storage and usage:

- Security-sensitive values are stored in `flutter_secure_storage` (Android uses `EncryptedSharedPreferences`).
- The active vault session key is kept in memory only (`_sessionKey`) and cleared on logout/panic path.
- Biometric unlock restores a previously derived key from secure storage key `hiveEncryptionKey`.
- SQLCipher DB password is derived from the in-memory session key as base64url of that 32-byte key.

Rationale (as implemented today):

- PBKDF2-HMAC-SHA256 is used for broad platform support via the `cryptography` package and deterministic derivation behavior across app codepaths.
- Iteration counts are separated by use case:
  - 100k for interactive PIN unlock latency
  - 200k for backup passphrase derivation where higher cost is acceptable.
- Independent random salts prevent cross-user/device precomputation and ensure derived keys differ even for equal PIN/passphrases.

## 3) Master PIN Flow, Irrecoverability, Panic Mode

### Master PIN Flow

- First-time setup stores master PIN hash+salt and derives session key.
- Normal unlock:
  - checks master PIN
  - on success derives and sets session key
  - exits panic mode.
- PIN change:
  - rotates PBKDF2 salt
  - derives a new session key
  - rekeys SQLCipher (`PRAGMA rekey`)
  - re-encrypts field-level `password` values with the new key.

### Irrecoverability

- There is no server-side recovery path in this codebase.
- If the user forgets the master PIN and does not have an exported backup passphrase-protected file, vault data is not recoverable through the app.

### Panic Mode Behavior

- Panic PIN is a separate PIN hash/salt pair.
- When panic PIN is entered:
  - session key is cleared
  - panic mode is enabled in app state.
- In panic mode, the provider returns an empty vault view instead of real vault items.
- Panic mode does not delete vault data; real data remains encrypted on disk and is visible again after a real unlock.

## 4) Backup Format and Encryption

- Export format is JSON (`.enc`) with schema version `v: 3`.
- Backup encryption:
  - KDF: PBKDF2-HMAC-SHA256
  - iterations: 200,000
  - salt: 16 random bytes
  - key size: 256 bits
  - cipher: AES-GCM-256 with 12-byte nonce and MAC.
- Backup payload includes:
  - `salt`
  - `envelope` (`algorithm`, `nonce`, `cipherText`, `tag`, format/version metadata)
  - `kdf` metadata
  - `cipher` metadata
  - `meta` (`createdAt`, `itemCount`).
- Import supports:
  - encrypted `.enc` backups (current default)
  - encrypted `.onerule` backups (legacy extension compatibility)
  - encrypted backup schema `v: 2` (legacy GCM layout)
  - encrypted backup schema `v: 1` (legacy CBC or legacy GCM layout).

## 5) Threat Model Assumptions

This implementation is designed to protect against:

- offline file access to app data without the PIN-derived key
- theft/exfiltration of database files at rest
- tampering attempts on AES-GCM protected field/backup payloads (integrity check via authentication tag).

This implementation does not fully protect against:

- a fully compromised or rooted device/OS
- malware or instrumentation with runtime access while the app is unlocked
- user-side PIN disclosure (phishing, shoulder surfing, keylogging)
- clipboard capture by other software before auto-clear runs.

Operational note:

- The Android manifest currently includes `android.permission.INTERNET`, but vault operations in this codebase are local-first and no cloud sync/backend is used for core vault cryptography flows.

## 6) Legacy Migration Note

- The code still contains a one-time legacy migration reader for old Hive-based vault data.
- Legacy records are imported into SQLCipher, then legacy Hive box data is removed and a migration completion flag is set.
- Current active storage architecture is SQLCipher + field-level AES-256-GCM.

## 6.1) KDF Versioning

Current status:

- There is no explicit standalone KDF version field for the PIN/session derivation path in secure storage.
- Effective compatibility today is tied to code expectations plus stored salt/hash keys (`hiveSalt`, `masterPinSalt`, `masterPinHash`, etc.).
- Backup format already carries explicit KDF metadata (`kdf.algorithm`, `kdf.iterations`, etc.) per file.

Forward-compatible migration strategy (documentation only, not implemented yet):

- Introduce a dedicated secure-storage key for PIN KDF metadata/version (for example `pinKdfVersion` plus parameters).
- On unlock:
  - read KDF version/params
  - derive with matching legacy/current profile
  - verify PIN hash and unlock.
- On successful unlock with legacy profile:
  - re-derive using latest profile
  - rewrite salts/verifier/session-derivation metadata atomically
  - preserve backward readability during migration window.
- Only remove legacy KDF readers after all active installs are expected to have migrated.

## 7) AES-CBC -> AES-GCM Migration (Vault and Backups)

### Codepaths

- Vault entry encryption/decryption and envelope migration:
  - `lib/services/field_cipher_service.dart`
  - `lib/services/database_service.dart`
- Backup encryption/decryption and backward-compat import:
  - `lib/services/backup_service.dart`

### Versioned envelope strategy

- Vault field payloads:
  - Current: `or1:v2:gcm:<nonce>:<cipherText>:<tag>`
  - Legacy supported during migration:
    - `or1:v1:cbc:<iv>:<cipherText>`
    - old marker-based GCM payload (pre-envelope format)
- Backups:
  - Current export format uses schema `v: 3` with an explicit `envelope` block and AES-GCM tag.
  - Reader remains backward-compatible for `v: 2` (GCM) and `v: 1` (legacy CBC or legacy GCM layout).

### Unlock-time migration behavior

- On unlock, vault rows are scanned.
- Per row:
  - if already `v2:gcm`, leave unchanged
  - if legacy CBC, legacy marker-GCM, or plaintext legacy value, decrypt/read then re-encrypt to `v2:gcm`
  - persist migrated value immediately.
- Row updates are done via transaction-scoped atomic update for each row (`id`-targeted update must affect exactly one row).
- If a row fails crypto validation/decryption, migration hard-fails with a clear integrity error; original row remains untouched (no lossy partial overwrite).

### Tamper detection and failure mode

- AES-GCM payloads (vault fields and backups) enforce authentication tags.
- Tag failure is treated as hard failure (`FieldCipherException` / `BackupCipherException`) with explicit message indicating tamper or wrong key/passphrase.

### Rollback considerations

- Backward readability is retained during rollout:
  - readers can still open legacy formats
  - writers always emit latest format.
- This allows safe staged deployment and rollback to a build that still understands old envelopes.
- Full removal of legacy readers should happen only after all active installs are expected to have completed migration and backups have been re-exported in current format.

## 8) Android Autofill Security Boundary

- Android Autofill integration uses a native `AutofillService` (`OneRuleAutofillService`) on API 26+.
- Flutter syncs an encrypted credential snapshot to native storage through platform channel methods:
  - `syncAutofillCredentialSnapshot`
  - `setAutofillSessionKey`
  - `clearAutofillSessionKey`.
- Snapshot and session-key data are stored in `EncryptedSharedPreferences` (Android Keystore-backed master key).
- Credential values synced from Flutter are encrypted envelope strings (`or1:v2:gcm:...`), not plaintext usernames/passwords.
- Decryption of autofill credential values occurs only inside the native Autofill service at fill time.
- If AES-GCM tag/auth validation fails during autofill decrypt, autofill hard-fails for that request and does not return partial fills.
- Session key can be cleared on lock/logout paths; without it, the Autofill service returns no credential datasets.
