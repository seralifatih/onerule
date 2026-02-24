import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/password_model.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';

class PasswordProvider extends ChangeNotifier {
  PasswordProvider({DatabaseService? dbService, AnalyticsService? analytics})
      : _dbService = dbService ?? DatabaseService(),
        _analytics = analytics ?? AnalyticsService.instance;

  final DatabaseService _dbService;
  final AnalyticsService _analytics;

  List<PasswordModel> _passwords = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  bool _isPanicMode = false;
  bool get isPanicMode => _isPanicMode;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;
  int _refreshRequestId = 0;

  List<PasswordModel> get passwords =>
      _isPanicMode ? <PasswordModel>[] : _applyFilters(_passwords);

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  int get totalPasswordsCount => _isPanicMode ? 0 : _passwords.length;
  bool get hasActiveSearch => _searchQuery.trim().isNotEmpty;
  bool get hasActiveCategoryFilter => _selectedCategory != 'All';
  bool get hasActiveRefinement => hasActiveSearch || hasActiveCategoryFilter;

  Future<void> init() async {
    await _dbService.init();
    await _refreshFromDatabase();
  }

  void enterPanicMode() {
    _isPanicMode = true;
    _passwords.clear();
    _notifySafely();
  }

  void exitPanicMode() {
    _isPanicMode = false;
    _notifySafely();
  }

  List<PasswordModel> _applyFilters(List<PasswordModel> source) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final byCategory = _selectedCategory == 'All'
        ? source
        : source.where((p) => p.category == _selectedCategory).toList();

    if (normalizedQuery.isEmpty) {
      return List<PasswordModel>.from(byCategory);
    }

    return byCategory.where((p) {
      return p.title.toLowerCase().contains(normalizedQuery) ||
          p.username.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    _notifySafely();
  }

  void search(String query) {
    _searchQuery = query;
    _notifySafely();
  }

  Future<void> addPassword(
    String title,
    String username,
    String password,
    String category,
  ) async {
    final newPass = PasswordModel(
      id: const Uuid().v4(),
      title: title,
      username: username,
      password: password,
      category: category,
      createdDate: DateTime.now(),
    );

    await _mutateAndRefresh(() => _dbService.addPassword(newPass));
  }

  Future<void> deletePassword(String id) async {
    await _mutateAndRefresh(() => _dbService.deletePassword(id));
  }

  Future<void> updatePassword(PasswordModel password) async {
    await _mutateAndRefresh(() => _dbService.updatePassword(password));
    await _analytics.credentialUpdateReflectedInList(
      totalItems: _passwords.length,
      selectedCategory: _selectedCategory,
    );
  }

  Future<void> deleteAllPasswords() async {
    await _mutateAndRefresh(_dbService.deleteAllPasswords);
  }

  Future<void> reencryptWithNewKey(List<int> newKey) async {
    await _mutateAndRefresh(() => _dbService.reencryptBox(newKey));
  }

  Future<void> _mutateAndRefresh(Future<void> Function() mutate) async {
    await mutate();
    await _refreshFromDatabase();
  }

  Future<void> _refreshFromDatabase() async {
    final requestId = ++_refreshRequestId;
    _isLoading = true;
    _notifySafely();

    // getAllPasswordsDecrypted() decrypts the GCM field-level password values
    // before returning — this is now the correct method to use everywhere.
    final allPasswords = await _dbService.getAllPasswordsDecrypted();
    allPasswords.sort((a, b) => b.createdDate.compareTo(a.createdDate));

    if (requestId != _refreshRequestId || _isDisposed) {
      return;
    }

    _passwords = allPasswords;
    _isLoading = false;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
