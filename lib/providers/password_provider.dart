import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/password_model.dart';
import '../services/database_service.dart';

class PasswordProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<PasswordModel> _passwords = [];
  List<PasswordModel> _filteredPasswords = [];

  String _selectedCategory = 'All';

  // Panik Modu Kontrolcüsü
  bool _isPanicMode = false;
  bool get isPanicMode => _isPanicMode;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Panik Modu açıksa boş liste dön
  List<PasswordModel> get passwords => _isPanicMode ? [] : _filteredPasswords;

  String get selectedCategory => _selectedCategory;

  // Uygulama açılışında çağrılır (Veritabanını burada açıyoruz)
  Future<void> init() async {
    await _dbService.init(); // <--- Kutu burada açılıyor
    _loadPasswords(); // <--- Veriler burada okunuyor
    _isLoading = false;
    notifyListeners();
  }

  // --- PANİK MODU YÖNETİMİ ---
  void enterPanicMode() {
    _isPanicMode = true;
    _passwords.clear();
    _filteredPasswords.clear();
    notifyListeners();
  }

  void exitPanicMode() {
    _isPanicMode = false;
    // _loadPasswords();  <--- HATALI SATIR SİLİNDİ!
    // Burada yükleme yapmamıza gerek yok, çünkü Login'den sonra zaten init() çalışacak.
    notifyListeners();
  }
  // ---------------------------

  void _loadPasswords() {
    // Veritabanından çek
    _passwords = _dbService.getAllPasswords();
    // Sırala (Yeniden eskiye)
    _passwords.sort((a, b) => b.createdDate.compareTo(a.createdDate));

    // Filtrele
    _applyFilter();
  }

  void _applyFilter() {
    if (_selectedCategory == 'All') {
      _filteredPasswords = List.from(_passwords);
    } else {
      _filteredPasswords =
          _passwords.where((p) => p.category == _selectedCategory).toList();
    }
  }

  // Kategoriye Göre Filtrele
  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilter();
    notifyListeners();
  }

  // Arama Fonksiyonu
  void search(String query) {
    List<PasswordModel> baseList = _selectedCategory == 'All'
        ? _passwords
        : _passwords.where((p) => p.category == _selectedCategory).toList();

    if (query.isEmpty) {
      _filteredPasswords = baseList;
    } else {
      _filteredPasswords = baseList.where((p) {
        return p.title.toLowerCase().contains(query.toLowerCase()) ||
            p.username.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // Şifre Ekleme
  Future<void> addPassword(
      String title, String username, String password, String category) async {
    final newPass = PasswordModel(
      id: const Uuid().v4(),
      title: title,
      username: username,
      password: password,
      category: category,
      createdDate: DateTime.now(),
    );

    await _dbService.addPassword(newPass);
    _loadPasswords();
    notifyListeners();
  }

  // Şifre Silme
  Future<void> deletePassword(String id) async {
    await _dbService.deletePassword(id);
    _loadPasswords();
    notifyListeners();
  }

  // Şifre Güncelleme
  Future<void> updatePassword(PasswordModel password) async {
    await _dbService.updatePassword(password);
    _loadPasswords();
    notifyListeners();
  }

  // Tüm veriyi sil
  Future<void> deleteAllPasswords() async {
    await _dbService.deleteAllPasswords();
    _passwords.clear();
    _filteredPasswords.clear();
    notifyListeners();
  }

  Future<void> reencryptWithNewKey(List<int> newKey) async {
    await _dbService.reencryptBox(newKey);
    _loadPasswords();
    notifyListeners();
  }
}
