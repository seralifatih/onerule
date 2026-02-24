import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../features/database/sqlcipher_spike_feature_flag.dart';

class SqlCipherSpikeService {
  SqlCipherSpikeService({
    SqlCipherSpikeFeatureFlag? featureFlag,
  }) : _featureFlag = featureFlag ?? const SqlCipherSpikeFeatureFlag();

  final SqlCipherSpikeFeatureFlag _featureFlag;

  Future<void> runOnceIfEnabled() async {
    if (!_featureFlag.isEnabled) return;

    const dbKey = String.fromEnvironment(
      'ONERULE_SQLCIPHER_KEY',
      defaultValue: 'spike-only-key-not-for-production',
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath =
          '${directory.path}${Platform.pathSeparator}onerule_sqlcipher_spike.db';

      final db = await openDatabase(
        dbPath,
        password: dbKey,
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS spike_passwords(
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              username TEXT NOT NULL,
              passwordCiphertext TEXT NOT NULL,
              url TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT,
              category TEXT NOT NULL
            )
          ''');
        },
      );

      await db.insert(
        'spike_passwords',
        <String, Object?>{
          'id': 'spike-1',
          'title': 'Spike Title',
          'username': 'spike@example.com',
          'passwordCiphertext': 'ciphertext-placeholder',
          'url': 'https://example.com',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'updatedAt': null,
          'category': 'General',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(
        'spike_passwords',
        where: 'id = ?',
        whereArgs: const <Object>['spike-1'],
        limit: 1,
      );

      if (kDebugMode) {
        final found = rows.isNotEmpty;
        debugPrint('[SQLCipherSpike] open+write+read success=$found');
      }

      await db.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SQLCipherSpike] failed to run: $e');
      }
    }
  }
}
