class SqlCipherSpikeFeatureFlag {
  const SqlCipherSpikeFeatureFlag({bool? overrideEnabled})
      : _overrideEnabled = overrideEnabled;

  final bool? _overrideEnabled;

  bool get isEnabled =>
      _overrideEnabled ??
      const bool.fromEnvironment(
        'ONERULE_SQLCIPHER_SPIKE',
        defaultValue: false,
      );
}
