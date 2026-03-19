import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _length = 16;
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSymbols = false;

  String _generatedPassword = '';
  bool _hasValidOptions = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final List<String> pools = [];
    if (_useUppercase) pools.add('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (_useLowercase) pools.add('abcdefghijklmnopqrstuvwxyz');
    if (_useNumbers) pools.add('0123456789');
    if (_useSymbols) pools.add('!@#\$%^&*()_+-=[]{}|;:,.<>?');

    if (pools.isEmpty) {
      setState(() {
        _hasValidOptions = false;
        _generatedPassword = 'Select at least one option';
      });
      return;
    }

    final int length =
        _length.toInt() < pools.length ? pools.length : _length.toInt();
    if (length != _length.toInt()) setState(() => _length = length.toDouble());
    _hasValidOptions = true;

    final rnd = Random.secure();
    final List<int> codes = [];
    for (final pool in pools) {
      codes.add(pool.codeUnitAt(rnd.nextInt(pool.length)));
    }
    final allChars = pools.join();
    for (int i = codes.length; i < length; i++) {
      codes.add(allChars.codeUnitAt(rnd.nextInt(allChars.length)));
    }
    for (int i = codes.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = codes[i];
      codes[i] = codes[j];
      codes[j] = tmp;
    }
    setState(() {
      _generatedPassword = String.fromCharCodes(codes);
      _copied = false;
    });
  }

  int get _entropyBars {
    int activeOptions = [_useUppercase, _useLowercase, _useNumbers, _useSymbols]
        .where((v) => v)
        .length;
    if (!_hasValidOptions) return 0;
    if (_length < 10) return 1;
    if (_length < 14 || activeOptions < 2) return 2;
    if (_length < 18 || activeOptions < 3) return 3;
    return 4;
  }

  String get _entropyLabel {
    final bars = _entropyBars;
    if (bars <= 1) return 'Weak';
    if (bars == 2) return 'Fair';
    if (bars == 3) return 'Good';
    return 'Excellent';
  }

  void _copyToClipboard() {
    if (!_hasValidOptions) return;
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _usePassword() {
    if (!_hasValidOptions) return;
    Navigator.of(context).pop(_generatedPassword);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bars = _entropyBars;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'VAULT GENERATOR',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),

            // ── Generated password display ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.xlarge),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Password output ──────────────────────────────────────
                  Text(
                    'SECURE OUTPUT',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _generatedPassword,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GestureDetector(
                          onTap: _copyToClipboard,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: _copied
                                  ? colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                            ),
                            child: Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 20,
                              color: _copied
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Length slider ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CHARACTER LENGTH',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        '${_length.toInt()}',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor:
                          colorScheme.surfaceContainerHighest,
                      thumbColor: colorScheme.primary,
                      overlayColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: _length,
                      min: 8,
                      max: 64,
                      onChanged: (val) {
                        setState(() => _length = val);
                        _generate();
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Parameter checkboxes (2×2 grid) ──────────────────────
                  Text(
                    'PARAMETERS',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildParamGrid(context),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Entropy score bar ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: colorScheme.tertiary, size: 22),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ENTROPY SCORE',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.tertiaryContainer,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      fontSize: 9,
                                    ),
                                  ),
                                  Text(
                                    _entropyLabel.toUpperCase(),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.tertiary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: List.generate(4, (i) {
                                  return Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: EdgeInsets.only(
                                          right: i < 3 ? AppSpacing.xs : 0),
                                      decoration: BoxDecoration(
                                        color: i < bars
                                            ? colorScheme.tertiary
                                            : colorScheme.tertiary
                                                .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Actions ──────────────────────────────────────────────
                  GestureDetector(
                    onTap: _hasValidOptions ? _usePassword : null,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _hasValidOptions
                            ? LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primaryContainer,
                                ],
                              )
                            : null,
                        color: _hasValidOptions
                            ? null
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        boxShadow: _hasValidOptions
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'USE PASSWORD',
                            style: textTheme.labelLarge?.copyWith(
                              color: _hasValidOptions
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.key_rounded,
                            size: 18,
                            color: _hasValidOptions
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: _generate,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 20,
                              color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'REFRESH',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildParamGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final params = [
      ('Uppercase (A-Z)', _useUppercase, (bool v) {
        setState(() => _useUppercase = v);
        _generate();
      }),
      ('Lowercase (a-z)', _useLowercase, (bool v) {
        setState(() => _useLowercase = v);
        _generate();
      }),
      ('Numbers (0-9)', _useNumbers, (bool v) {
        setState(() => _useNumbers = v);
        _generate();
      }),
      ('Symbols (!@#)', _useSymbols, (bool v) {
        setState(() => _useSymbols = v);
        _generate();
      }),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.xl,
      childAspectRatio: 4.5,
      children: params.map((p) {
        final (label, checked, onChanged) = p;
        return GestureDetector(
          onTap: () => onChanged(!checked),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: checked ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: checked
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: checked
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
