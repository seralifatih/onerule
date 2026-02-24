# Hive -> SQLCipher Migration Plan (Architectural)

## Scope
- Migrate credential storage from Hive box (`passwords`) to SQLCipher-backed SQLite.
- Keep current app behavior unchanged during rollout.
- Do **not** remove Hive immediately; keep rollback path until migration is verified.

## Decision (for migration track)
- **Primary path:** `sqflite_sqlcipher` (incremental, least disruptive).
- **Optional phase 2:** introduce Drift on top of SQLCipher once storage is stable.

## Dependencies
### Required for SQLCipher track
- `sqflite_sqlcipher`

### Already present and reused
- `path_provider` (file/db paths)
- `flutter_secure_storage` (db key material / migration flags)
- `cryptography` (record verification hashes if needed)

## Platform setup checklist
## Android
- Keep `minSdk >= 23` (already true in this project).
- If code shrinking is enabled later (`minifyEnabled true`), add SQLCipher keep rules:
  - `-keep class net.sqlcipher.** { *; }`
  - `-keep class io.sqlc.** { *; }`

## iOS
- Ensure CocoaPods is installed and pods are resolvable (`pod install` via Flutter iOS build pipeline).
- If `ios/Podfile` is missing in repo, generate/refresh by running a normal iOS Flutter build once.

## Target SQLCipher schema
```sql
CREATE TABLE passwords (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  username TEXT NOT NULL,
  passwordCiphertext TEXT NOT NULL,
  url TEXT,
  createdAt TEXT NOT NULL,      -- ISO-8601 UTC
  updatedAt TEXT,               -- ISO-8601 UTC nullable
  category TEXT NOT NULL
);

CREATE INDEX idx_passwords_category ON passwords(category);
CREATE INDEX idx_passwords_title ON passwords(title);
```

Notes:
- `passwordCiphertext` stores the existing field-level ciphertext string (no plaintext writes).
- Search/filter fields remain plaintext as currently designed.

## Migration flow (concrete)
1. Detect old Hive box
- Check Hive box existence and row count.
- Check migration state flag in secure storage (`not_started|in_progress|validated|cleanup_done`).

2. Read all Hive entries
- Read models from Hive using existing decrypt-safe path.
- Do **not** log password values.

3. Write to SQLCipher
- Open SQLCipher DB with key from secure storage-derived material.
- Wrap writes in transaction/batches.
- Upsert by `id`.

4. Verify counts + hashes
- Compare `hiveCount == sqlCount`.
- Compute deterministic per-record hash over stable fields:
  - `id|title|username|passwordCiphertext|url|createdAt|updatedAt|category`
- Compare aggregate hash (e.g., sorted record hashes -> SHA-256).

5. Keep Hive backup until success
- Keep original Hive files untouched initially.
- Mark state `validated` only after count/hash verification succeeds.
- Switch reads to SQLCipher behind runtime flag.
- After N successful app launches on SQLCipher path, mark `cleanup_done` and optionally archive/delete Hive files.

## Failure/rollback strategy
- If migration fails at any stage:
  - keep Hive as source of truth,
  - keep migration state `in_progress` or revert to `not_started`,
  - retry on next app start.
- Never delete Hive files before `validated` + burn-in window.

## Security constraints during migration
- No plaintext password logging.
- No network transmission of migration diagnostics.
- Redact suspicious long blobs and key-like fields in error messages.

## Incremental rollout plan
1. Ship SQLCipher bootstrap behind compile-time feature flag.
2. Add read/write adapter layer (Hive + SQLCipher selectable).
3. Enable migration for internal builds only.
4. Enable for staged users.
5. Complete cutover and cleanup.

## Minimal spike implemented in this step
- SQLCipher DB open/create/write/read test behind flag:
  - `ONERULE_SQLCIPHER_SPIKE=true`
- Default remains **off**; production path unchanged.

Run spike:
```bash
flutter run --dart-define=ONERULE_SQLCIPHER_SPIKE=true
```

Optional key override for spike:
```bash
flutter run \
  --dart-define=ONERULE_SQLCIPHER_SPIKE=true \
  --dart-define=ONERULE_SQLCIPHER_KEY=your-spike-key
```

## Exact files changed for spike
- `pubspec.yaml` (adds `sqflite_sqlcipher`)
- `lib/features/database/sqlcipher_spike_feature_flag.dart`
- `lib/services/sqlcipher_spike_service.dart`
- `lib/main.dart` (invokes spike service behind feature flag)
