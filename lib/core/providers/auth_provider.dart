import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/crashlytics_service.dart';

/// Provider untuk mengelola status autentikasi Google Firebase di seluruh aplikasi
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _authService.currentUser;
    if (_user != null) {
      AnalyticsService.instance.setUserId(_user!.uid);
      CrashlyticsService.instance.setUserIdentifier(_user!.uid);
    }
    _authSubscription = _authService.authStateChanges.listen((User? newUser) {
      _user = newUser;
      if (newUser != null) {
        AnalyticsService.instance.setUserId(newUser.uid);
        CrashlyticsService.instance.setUserIdentifier(newUser.uid);
      } else {
        AnalyticsService.instance.setUserId(null);
        CrashlyticsService.instance.setUserIdentifier('');
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Memulai proses Login Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loggedInUser = await _authService.signInWithGoogle();
      _user = loggedInUser;
      if (loggedInUser != null) {
        AnalyticsService.instance.logUserLogin(method: 'google');
        AnalyticsService.instance.setUserId(loggedInUser.uid);
        CrashlyticsService.instance.setUserIdentifier(loggedInUser.uid);
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _errorMessage = 'Gagal melakukan login Google: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout akun Google
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      AnalyticsService.instance.logUserLogout();
      AnalyticsService.instance.setUserId(null);
      CrashlyticsService.instance.setUserIdentifier('');
    } catch (e) {
      _errorMessage = 'Gagal keluar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
