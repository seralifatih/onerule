import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../screens/password_generator_screen.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AddPasswordSheet extends StatefulWidget {
  final PasswordModel? passwordToEdit;

  const AddPasswordSheet({super.key, this.passwordToEdit});

  @override
  State<AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends State<AddPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController; // UI only, not persisted yet

  final List<String> _categories = PasswordCategories.entryCategories;
  String _selectedCategory = PasswordCategories.general;

  bool _isObscure = true;
  bool _isSaving = false;
  bool _showSaved = false;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final LockFacade _lockFacade = LockFacade();

  @override
  void initState() {
    super.initState();
    final p = widget.passwordToEdit;
    _titleController = TextEditingController(text: p?.title ?? '');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController(text: p?.password ?? '');
    _notesController = TextEditingController();

    if (p != null && _categories.contains(p.category)) {
      _selectedCategory = p.category;
    }
  }

  @override
  void dispose() {
    _lockFacade.dispose();
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openGeneratorScreen() async {
    final generated = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PasswordGeneratorScreen()),
    );
    if (generated != null && mounted) {
      setState(() {
        _passwordController.text = generated;
        _isObscure = false;
      });
    }
  }

  String _categoryLabel(AppLocalizations loc, String category) {
    return PasswordCategories.labelFor(loc, category);
  }

  int get _passwordStrengthScore {
    final pw = _passwordController.text;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 14) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]').hasMatch(pw)) score++;
    return score;
  }

  (String label, String detail, Color color) get _strengthInfo {
    final colorScheme = Theme.of(context).colorScheme;
    final score = _passwordStrengthScore;
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      return ('—', 'Enter a password to see strength.', colorScheme.onSurfaceVariant);
    }
    if (score <= 1) {
      return ('Very Weak', 'Add length and mixed characters.', colorScheme.error);
    }
    if (score == 2) {
      return ('Weak', 'Add numbers and special characters.', const Color(0xFFD7383B));
    }
    if (score == 3) {
      return ('Strong', 'Good password. Consider adding symbols.', colorScheme.primary);
    }
    return ('Excellent', 'This password would take 400+ years to crack.', colorScheme.tertiary);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.passwordToEdit != null;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Entry' : 'New Entry',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            120,
          ),
          children: [
            // ── Editorial Header ─────────────────────────────────────────
            if (!isEditing) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                width: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SECURITY PROTOCOL',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              RichText(
                text: TextSpan(
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  children: [
                    const TextSpan(text: 'Secure your digital '),
                    TextSpan(
                      text: 'assets.',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Every entry is encrypted using AES-256 standards before being committed to your vault.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── Edit mode credential preview ──────────────────────────────
            if (isEditing) ...[
              _buildCredentialPreview(loc),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Category + Title (grid layout) ────────────────────────────
            _buildSectionLabel(context, 'CATEGORY'),
            const SizedBox(height: AppSpacing.xs),
            _buildCategorySelector(context, loc),
            const SizedBox(height: AppSpacing.lg),

            _buildSectionLabel(context, 'PLATFORM / TITLE'),
            const SizedBox(height: AppSpacing.xs),
            _buildTitleField(context, loc),
            const SizedBox(height: AppSpacing.lg),

            // ── Identity group (tonal container) ─────────────────────────
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xlarge),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  _buildIdentityField(context, loc),
                  const SizedBox(height: AppSpacing.xs),
                  _buildPasswordField(context, loc),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Strength card ─────────────────────────────────────────────
            _buildStrengthCard(context),
            const SizedBox(height: AppSpacing.lg),

            // ── Notes ─────────────────────────────────────────────────────
            _buildSectionLabel(context, 'NOTES (OPTIONAL)'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Add recovery hints or specific details...',
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.lg),
              ),
            ),
          ],
        ),
      ),
      // ── Fixed bottom CTA ─────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _buildSaveButton(context, isEditing, loc),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        fontSize: 10,
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: colorScheme.surfaceContainerHigh,
          icon: Icon(Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant, size: 20),
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          items: _categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Row(
                children: [
                  Icon(
                    PasswordCategories.iconFor(cat),
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_categoryLabel(loc, cat)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ),
    );
  }

  Widget _buildTitleField(BuildContext context, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TextFormField(
      controller: _titleController,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'e.g. Adobe Creative Cloud',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        prefixIcon: Icon(Icons.label_outline_rounded,
            color: colorScheme.onSurfaceVariant, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      validator: (v) => (v?.isEmpty ?? true) ? loc.titleRequired : null,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (widget.passwordToEdit != null) setState(() {});
      },
    );
  }

  Widget _buildIdentityField(BuildContext context, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text(
              'USERNAME / EMAIL',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
          ),
          TextFormField(
            controller: _usernameController,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'art.director@studio.com',
              hintStyle: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
            validator: (v) =>
                (v?.isEmpty ?? true) ? loc.usernameRequired : null,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (widget.passwordToEdit != null) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text(
              'PASSWORD',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: _isObscure ? 3 : 0,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••••••',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? loc.passwordRequired : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // Visibility toggle
              Semantics(
                button: true,
                label: loc.passwordRevealControlLabel,
                child: IconButton(
                  icon: Icon(
                    _isObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isObscure = !_isObscure);
                  },
                  tooltip: _isObscure
                      ? loc.passwordRevealHoldTooltip
                      : loc.passwordRevealReleaseTooltip,
                ),
              ),
              // Generator button
              IconButton(
                icon: const Icon(Icons.casino_outlined, size: 20),
                color: colorScheme.primary,
                onPressed: _openGeneratorScreen,
                tooltip: loc.generatePasswordTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (label, detail, color) = _strengthInfo;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border(
          left: BorderSide(
            color: colorScheme.tertiary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: colorScheme.tertiary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Security Strength',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
      BuildContext context, bool isEditing, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: _isSaving ? null : () => _handleSave(context, isEditing, loc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          gradient: _isSaving || _showSaved
              ? null
              : LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
          color: _showSaved
              ? colorScheme.tertiary.withValues(alpha: 0.8)
              : _isSaving
                  ? colorScheme.surfaceContainerHigh
                  : null,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: _isSaving || _showSaved
              ? null
              : [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSaving)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              Icon(
                _showSaved ? Icons.check_circle : Icons.save_rounded,
                color: colorScheme.onPrimary,
                size: 20,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _showSaved
                  ? 'Saved!'
                  : _isSaving
                      ? 'Saving...'
                      : isEditing
                          ? loc.update
                          : loc.saveAction,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    bool isEditing,
    AppLocalizations loc,
  ) async {
    if (_isSaving) return;
    final provider = Provider.of<PasswordProvider>(context, listen: false);
    setState(() {
      _isSaving = true;
      _showSaved = false;
    });
    await _analytics.primaryCtaTap(
      ctaId: isEditing ? 'credential_update_submit' : 'credential_add_submit',
      screen: 'add_password_screen',
    );
    if (_formKey.currentState!.validate()) {
      if (isEditing) {
        final updated = widget.passwordToEdit!;
        updated.title = _titleController.text;
        updated.username = _usernameController.text;
        updated.password = _passwordController.text;
        updated.category = _selectedCategory;
          updated.lastModified = DateTime.now();
        await _analytics.credentialUpdateSubmitted();
        await provider.updatePassword(updated);
      } else {
        await provider.addPassword(
          _titleController.text,
          _usernameController.text,
          _passwordController.text,
          _selectedCategory,
        );
      }
      if (!context.mounted) return;
      setState(() {
        _isSaving = false;
        _showSaved = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } else {
      if (!context.mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Widget _buildCredentialPreview(AppLocalizations loc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final maskedLength = _passwordController.text.length.clamp(6, 16).toInt();
    final passwordPreview =
        _isObscure ? '•' * maskedLength : _passwordController.text;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(Icons.alternate_email_rounded,
                color: colorScheme.primary, size: 18),
            title: Text(loc.usernameEmailLabel,
                style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            subtitle: Text(
              _usernameController.text.isEmpty ? '-' : _usernameController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurface),
            ),
            trailing: IconButton(
              tooltip: loc.usernameEmailLabel,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: colorScheme.onSurfaceVariant,
              onPressed: () {
                _lockFacade.copyUsernameToClipboard(
                  context: context,
                  username: _usernameController.text,
                  title: _titleController.text,
                );
              },
            ),
          ),
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ListTile(
            dense: true,
            leading: Icon(Icons.lock_outline_rounded,
                color: colorScheme.primary, size: 18),
            title: Text(loc.passwordLabel,
                style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            subtitle: Text(
              passwordPreview.isEmpty ? '••••••' : passwordPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurface),
            ),
            trailing: IconButton(
              tooltip: loc.passwordLabel,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: colorScheme.onSurfaceVariant,
              onPressed: () {
                _lockFacade.copyPasswordToClipboard(
                  context: context,
                  password: _passwordController.text,
                  title: _titleController.text,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legacy password generator dialog (kept for compatibility) ─────────────────

class PasswordGeneratorDialog extends StatefulWidget {
  final Function(String) onConfirm;

  const PasswordGeneratorDialog({super.key, required this.onConfirm});

  @override
  State<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  double _length = 12;
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSymbols = true;

  String _generatedPassword = '';
  bool _hasValidOptions = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final loc = AppLocalizations.of(context)!;
    final List<String> pools = [];
    if (_useUppercase) pools.add('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (_useLowercase) pools.add('abcdefghijklmnopqrstuvwxyz');
    if (_useNumbers) pools.add('0123456789');
    if (_useSymbols) pools.add('!@#\$%^&*()_+-=[]{}|;:,.<>?');

    if (pools.isEmpty) {
      setState(() {
        _hasValidOptions = false;
        _generatedPassword = loc.selectOptions;
      });
      return;
    }

    final int length =
        _length.toInt() < pools.length ? pools.length : _length.toInt();
    if (length != _length.toInt()) {
      setState(() => _length = length.toDouble());
    }
    _hasValidOptions = true;

    final Random rnd = Random.secure();
    final List<int> codes = [];
    for (final pool in pools) {
      codes.add(pool.codeUnitAt(rnd.nextInt(pool.length)));
    }
    final String allChars = pools.join();
    for (int i = codes.length; i < length; i++) {
      codes.add(allChars.codeUnitAt(rnd.nextInt(allChars.length)));
    }
    for (int i = codes.length - 1; i > 0; i--) {
      final int j = rnd.nextInt(i + 1);
      final int tmp = codes[i];
      codes[i] = codes[j];
      codes[j] = tmp;
    }
    setState(() {
      _generatedPassword = String.fromCharCodes(codes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AlertDialog(
      title: Text(loc.generatePasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: SelectableText(
                _generatedPassword,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(loc.lengthLabel),
                Text('${_length.toInt()}',
                    style: textTheme.labelLarge),
              ],
            ),
            Slider(
              value: _length,
              min: 4,
              max: 32,
              divisions: 28,
              label: '${_length.toInt()}',
              onChanged: (val) {
                setState(() => _length = val);
                _generate();
              },
            ),
            CheckboxListTile(
              title: Text(loc.uppercaseOption),
              value: _useUppercase,
              onChanged: (val) {
                setState(() => _useUppercase = val!);
                _generate();
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text(loc.lowercaseOption),
              value: _useLowercase,
              onChanged: (val) {
                setState(() => _useLowercase = val!);
                _generate();
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text(loc.numbersOption),
              value: _useNumbers,
              onChanged: (val) {
                setState(() => _useNumbers = val!);
                _generate();
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: Text(loc.symbolsOption),
              value: _useSymbols,
              onChanged: (val) {
                setState(() => _useSymbols = val!);
                _generate();
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh),
          label: Text(loc.refresh),
        ),
        FilledButton(
          onPressed: _hasValidOptions
              ? () {
                  widget.onConfirm(_generatedPassword);
                  Navigator.pop(context);
                }
              : null,
          child: Text(loc.use),
        ),
      ],
    );
  }
}
