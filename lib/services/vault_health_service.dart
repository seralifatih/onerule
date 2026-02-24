import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/password_model.dart';

enum VaultHealthIssueType { weakPassword, duplicatePassword, stalePassword }

class VaultHealthConfig {
  const VaultHealthConfig({this.includeAdvancedChecks = false});

  final bool includeAdvancedChecks;
}

class VaultHealthIssueBucket {
  const VaultHealthIssueBucket({
    required this.type,
    required this.title,
    required this.description,
    required this.entries,
    this.isAdvanced = false,
  });

  final VaultHealthIssueType type;
  final String title;
  final String description;
  final List<PasswordModel> entries;
  final bool isAdvanced;

  int get count => entries.length;
}

class VaultHealthReport {
  const VaultHealthReport({
    required this.totalEntries,
    required this.score,
    required this.buckets,
  });

  final int totalEntries;
  final int score;
  final List<VaultHealthIssueBucket> buckets;

  int get weakCount => _countFor(VaultHealthIssueType.weakPassword);
  int get duplicateCount => _countFor(VaultHealthIssueType.duplicatePassword);
  int get staleCount => _countFor(VaultHealthIssueType.stalePassword);

  int _countFor(VaultHealthIssueType type) {
    return buckets
        .where((bucket) => bucket.type == type)
        .fold<int>(0, (sum, bucket) => sum + bucket.count);
  }
}

class VaultHealthService {
  VaultHealthService({VaultHealthConfig? config})
      : _config = config ?? const VaultHealthConfig();

  final VaultHealthConfig _config;
  final HashAlgorithm _sha256 = Sha256();

  Future<VaultHealthReport> analyze(
    List<PasswordModel> entries, {
    DateTime? now,
  }) async {
    final referenceNow = now ?? DateTime.now();
    final checks = _buildChecks();

    final buckets = <VaultHealthIssueBucket>[];
    for (final check in checks) {
      if (check.isAdvanced && !_config.includeAdvancedChecks) {
        continue;
      }
      final matched = await check.run(entries, referenceNow);
      buckets.add(
        VaultHealthIssueBucket(
          type: check.type,
          title: check.title,
          description: check.description,
          entries: matched,
          isAdvanced: check.isAdvanced,
        ),
      );
    }

    final score = _computeScore(
      totalEntries: entries.length,
      weakCount: buckets
          .where((bucket) => bucket.type == VaultHealthIssueType.weakPassword)
          .fold<int>(0, (sum, bucket) => sum + bucket.count),
      duplicateCount: buckets
          .where(
              (bucket) => bucket.type == VaultHealthIssueType.duplicatePassword)
          .fold<int>(0, (sum, bucket) => sum + bucket.count),
      staleCount: buckets
          .where((bucket) => bucket.type == VaultHealthIssueType.stalePassword)
          .fold<int>(0, (sum, bucket) => sum + bucket.count),
    );

    return VaultHealthReport(
      totalEntries: entries.length,
      score: score,
      buckets: buckets,
    );
  }

  List<_VaultHealthCheck> _buildChecks() {
    return <_VaultHealthCheck>[
      _VaultHealthCheck(
        type: VaultHealthIssueType.weakPassword,
        title: 'Weak Passwords',
        description: 'Length under 10 or missing character variety.',
        run: _runWeakPasswordCheck,
      ),
      _VaultHealthCheck(
        type: VaultHealthIssueType.duplicatePassword,
        title: 'Duplicate Passwords',
        description:
            'Exact-match duplicates detected using local hash compare.',
        run: _runDuplicatePasswordCheck,
      ),
      _VaultHealthCheck(
        type: VaultHealthIssueType.stalePassword,
        title: 'Stale Passwords',
        description: 'No update in the last 12 months.',
        run: _runStalePasswordCheck,
      ),
      _VaultHealthCheck(
        type: VaultHealthIssueType.weakPassword,
        title: 'Advanced Health Checks',
        description: 'Reserved for future advanced checks.',
        isAdvanced: true,
        run: _runAdvancedPlaceholderCheck,
      ),
    ];
  }

  Future<List<PasswordModel>> _runWeakPasswordCheck(
    List<PasswordModel> entries,
    DateTime now,
  ) async {
    return entries.where(_isWeakPassword).toList(growable: false);
  }

  Future<List<PasswordModel>> _runDuplicatePasswordCheck(
    List<PasswordModel> entries,
    DateTime now,
  ) async {
    final byHash = <String, List<PasswordModel>>{};

    for (final entry in entries) {
      final passwordHash = await _hashPassword(entry.password);
      final bucket = byHash.putIfAbsent(passwordHash, () => <PasswordModel>[]);
      bucket.add(entry);
    }

    final duplicates = <PasswordModel>[];
    for (final group in byHash.values) {
      if (group.length > 1) {
        duplicates.addAll(group);
      }
    }

    return duplicates;
  }

  Future<List<PasswordModel>> _runStalePasswordCheck(
    List<PasswordModel> entries,
    DateTime now,
  ) async {
    return entries.where((entry) {
      final lastTouched = entry.lastModified ?? entry.createdDate;
      return now.difference(lastTouched).inDays >= 365;
    }).toList(growable: false);
  }

  Future<List<PasswordModel>> _runAdvancedPlaceholderCheck(
    List<PasswordModel> entries,
    DateTime now,
  ) async {
    return const <PasswordModel>[];
  }

  bool _isWeakPassword(PasswordModel entry) {
    final value = entry.password;
    if (value.length < 10) {
      return true;
    }

    var hasLower = false;
    var hasUpper = false;
    var hasDigit = false;
    var hasSymbol = false;

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[a-z]').hasMatch(char)) {
        hasLower = true;
      } else if (RegExp(r'[A-Z]').hasMatch(char)) {
        hasUpper = true;
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        hasDigit = true;
      } else {
        hasSymbol = true;
      }
    }

    final varietyCount = <bool>[hasLower, hasUpper, hasDigit, hasSymbol]
        .where((item) => item)
        .length;

    return varietyCount < 3;
  }

  Future<String> _hashPassword(String password) async {
    final hash = await _sha256.hash(utf8.encode(password));
    return base64UrlEncode(hash.bytes);
  }

  int _computeScore({
    required int totalEntries,
    required int weakCount,
    required int duplicateCount,
    required int staleCount,
  }) {
    if (totalEntries <= 0) {
      return 100;
    }

    final weakPenalty = (weakCount / totalEntries) * 40.0;
    final duplicatePenalty = (duplicateCount / totalEntries) * 35.0;
    final stalePenalty = (staleCount / totalEntries) * 25.0;

    final score = 100.0 - weakPenalty - duplicatePenalty - stalePenalty;
    return score.clamp(0.0, 100.0).round();
  }
}

class _VaultHealthCheck {
  const _VaultHealthCheck({
    required this.type,
    required this.title,
    required this.description,
    required this.run,
    this.isAdvanced = false,
  });

  final VaultHealthIssueType type;
  final String title;
  final String description;
  final bool isAdvanced;
  final Future<List<PasswordModel>> Function(
    List<PasswordModel> entries,
    DateTime now,
  ) run;
}
