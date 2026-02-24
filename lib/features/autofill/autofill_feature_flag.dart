class AutofillFeatureFlag {
  const AutofillFeatureFlag({bool? overrideEnabled})
      : _overrideEnabled = overrideEnabled;

  final bool? _overrideEnabled;

  bool get isEnabled =>
      _overrideEnabled ??
      const bool.fromEnvironment(
        'ONERULE_AUTOFILL_MVP',
        defaultValue: true,
      );
}
