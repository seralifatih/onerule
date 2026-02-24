import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/services/vault_health_service.dart';

PasswordModel _entry({
  required String id,
  required String password,
  DateTime? createdDate,
  DateTime? lastModified,
}) {
  return PasswordModel(
    id: id,
    title: 'Entry $id',
    username: '$id@example.com',
    password: password,
    category: 'General',
    createdDate: createdDate ?? DateTime(2026, 1, 1),
    lastModified: lastModified,
  );
}

void main() {
  test('weak password heuristic catches short and low-variety values',
      () async {
    final service = VaultHealthService();
    final report = await service.analyze(
      <PasswordModel>[
        _entry(id: 'a', password: 'short'),
        _entry(id: 'b', password: 'alllowercase123'),
        _entry(id: 'c', password: 'Strong@1234'),
      ],
      now: DateTime(2026, 2, 24),
    );

    expect(report.weakCount, 2);
  });

  test('duplicate detection uses exact password hash matching', () async {
    final service = VaultHealthService();
    final report = await service.analyze(
      <PasswordModel>[
        _entry(id: 'a', password: 'SamePass@123'),
        _entry(id: 'b', password: 'SamePass@123'),
        _entry(id: 'c', password: 'Different@987'),
      ],
      now: DateTime(2026, 2, 24),
    );

    expect(report.duplicateCount, 2);
  });

  test('stale detection marks entries not updated in 12+ months', () async {
    final service = VaultHealthService();
    final report = await service.analyze(
      <PasswordModel>[
        _entry(
          id: 'a',
          password: 'Strong@1234',
          createdDate: DateTime(2024, 1, 1),
        ),
        _entry(
          id: 'b',
          password: 'Strong@1234',
          createdDate: DateTime(2026, 1, 1),
        ),
      ],
      now: DateTime(2026, 2, 24),
    );

    expect(report.staleCount, 1);
  });

  test('score is clamped between 0 and 100', () async {
    final service = VaultHealthService();
    final report = await service.analyze(
      <PasswordModel>[
        _entry(
          id: 'a',
          password: 'weak',
          createdDate: DateTime(2020, 1, 1),
        ),
      ],
      now: DateTime(2026, 2, 24),
    );

    expect(report.score, inInclusiveRange(0, 100));
  });
}
