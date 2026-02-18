import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';

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
    super.dispose();
  }

  void _showGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return PasswordGeneratorDialog(
          onConfirm: (generatedPassword) {
            setState(() {
              _passwordController.text = generatedPassword;
              _isObscure = false;
            });
          },
        );
      },
    );
  }

  String _categoryLabel(AppLocalizations loc, String category) {
    return PasswordCategories.labelFor(loc, category);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.passwordToEdit != null;
    final loc = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final effectiveBottomPadding =
        keyboardInset > 0 ? keyboardInset : safeBottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: effectiveBottomPadding),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditing ? loc.editPassword : loc.addNewPassword,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isEditing) ...[
                    _buildCredentialPreview(loc),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: loc.categoryLabel,
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(_categoryLabel(loc, cat)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: loc.platformTitleLabel,
                      prefixIcon: const Icon(Icons.label_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? loc.titleRequired : null,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (isEditing) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: loc.usernameEmailLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? loc.usernameRequired : null,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (isEditing) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      labelText: loc.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isObscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _isObscure = !_isObscure),
                          ),
                          IconButton(
                            onPressed: _showGeneratorDialog,
                            icon: const Icon(Icons.casino),
                            tooltip: loc.generatePasswordTooltip,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? loc.passwordRequired : null,
                    onChanged: (_) {
                      if (isEditing) setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _showSaved
                            ? const Icon(Icons.check_circle, key: ValueKey('ok'))
                            : Icon(
                                _isSaving
                                    ? Icons.sync
                                    : (isEditing ? Icons.update : Icons.save),
                                key: ValueKey(_isSaving ? 'saving' : 'idle'),
                              ),
                      ),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _showSaved
                              ? loc.save
                              : (isEditing ? loc.update : loc.saveAction),
                          key: ValueKey(_showSaved),
                        ),
                      ),
                      onPressed: () async {
                        if (_isSaving) return;
                        setState(() {
                          _isSaving = true;
                          _showSaved = false;
                        });
                        await _analytics.primaryCtaTap(
                          ctaId: isEditing
                              ? 'credential_update_submit'
                              : 'credential_add_submit',
                          screen: 'add_password_sheet',
                        );
                        if (_formKey.currentState!.validate()) {
                          final provider = Provider.of<PasswordProvider>(
                            context,
                            listen: false,
                          );

                          if (isEditing) {
                            final updatedPassword = widget.passwordToEdit!;
                            updatedPassword.title = _titleController.text;
                            updatedPassword.username = _usernameController.text;
                            updatedPassword.password = _passwordController.text;
                            updatedPassword.category = _selectedCategory;
                            updatedPassword.lastModified = DateTime.now();

                            await _analytics.credentialUpdateSubmitted();
                            await provider.updatePassword(updatedPassword);
                          } else {
                            await provider.addPassword(
                              _titleController.text,
                              _usernameController.text,
                              _passwordController.text,
                              _selectedCategory,
                            );
                          }
                          if (!mounted) return;
                          setState(() {
                            _isSaving = false;
                            _showSaved = true;
                          });
                          await Future<void>.delayed(
                            const Duration(milliseconds: 380),
                          );
                          if (!mounted) return;
                          Navigator.of(this.context).pop();
                        } else {
                          if (!mounted) return;
                          setState(() {
                            _isSaving = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialPreview(AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final maskedLength =
        _passwordController.text.length.clamp(6, 16).toInt();
    final passwordPreview = _isObscure
        ? '•' * maskedLength
        : _passwordController.text;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.alternate_email_rounded),
            title: Text(loc.usernameEmailLabel),
            subtitle: Text(
              _usernameController.text.isEmpty ? '-' : _usernameController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: loc.usernameEmailLabel,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                _lockFacade.copyUsernameToClipboard(
                  context: context,
                  username: _usernameController.text,
                  title: _titleController.text,
                );
              },
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ListTile(
            dense: true,
            leading: const Icon(Icons.lock_outline),
            title: Text(loc.passwordLabel),
            subtitle: Text(
              passwordPreview.isEmpty ? '••••••' : passwordPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: loc.passwordLabel,
              icon: const Icon(Icons.copy_rounded),
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

  String _generatedPassword = "";
  bool _hasValidOptions = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final loc = AppLocalizations.of(context)!;
    final List<String> pools = [];
    if (_useUppercase) pools.add("ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    if (_useLowercase) pools.add("abcdefghijklmnopqrstuvwxyz");
    if (_useNumbers) pools.add("0123456789");
    if (_useSymbols) pools.add("!@#\$%^&*()_+-=[]{}|;:,.<>?");

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
    return AlertDialog(
      title: Text(loc.generatePasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _generatedPassword,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(loc.lengthLabel),
                Text(
                  "${_length.toInt()}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _length,
              min: 4,
              max: 32,
              divisions: 28,
              label: "${_length.toInt()}",
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
