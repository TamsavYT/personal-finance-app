import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthProvider extends ChangeNotifier {
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 1);

  bool _isLocked = false;
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isAuthenticated = false;
  String? _pinHash;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  bool get isLocked => _isLocked;
  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAuthenticated => _isAuthenticated;
  DateTime? get lockedUntil => _lockedUntil;

  bool get isLockedOut =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  final LocalAuthentication _localAuth = LocalAuthentication();

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isPinEnabled = prefs.getBool('pin_enabled') ?? false;
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _pinHash = prefs.getString('pin_hash');
      _failedAttempts = prefs.getInt('pin_failed_attempts') ?? 0;
      final lockedUntilMs = prefs.getInt('pin_locked_until');
      _lockedUntil = lockedUntilMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lockedUntilMs)
          : null;
      _isLocked = _isPinEnabled || _isBiometricEnabled;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading auth settings: $e');
    }
  }

  Future<void> enablePin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('pin_enabled', true);
      await prefs.setString('pin_hash', _hashPin(pin));

      _isPinEnabled = true;
      _pinHash = _hashPin(pin);

      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling PIN: $e');
    }
  }

  Future<void> disablePin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('pin_enabled', false);
      await prefs.remove('pin_hash');
      await prefs.remove('pin_failed_attempts');
      await prefs.remove('pin_locked_until');

      _isPinEnabled = false;
      _pinHash = null;
      _failedAttempts = 0;
      _lockedUntil = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
    }
  }

  Future<void> enableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('biometric_enabled', true);

      _isBiometricEnabled = true;

      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling biometric: $e');
    }
  }

  Future<void> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('biometric_enabled', false);

      _isBiometricEnabled = false;

      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling biometric: $e');
    }
  }

  Future<bool> authenticateWithPin(String pin) async {
    try {
      if (isLockedOut) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      if (_hashPin(pin) == _pinHash) {
        _failedAttempts = 0;
        _lockedUntil = null;
        await prefs.remove('pin_failed_attempts');
        await prefs.remove('pin_locked_until');

        _isAuthenticated = true;
        _isLocked = false;
        notifyListeners();
        return true;
      }

      _failedAttempts++;
      await prefs.setInt('pin_failed_attempts', _failedAttempts);
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
        await prefs.setInt(
          'pin_locked_until',
          _lockedUntil!.millisecondsSinceEpoch,
        );
        await prefs.setInt('pin_failed_attempts', 0);
      }
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error authenticating with PIN: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Expense Ledger',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isAuthenticated) {
        _isAuthenticated = true;
        _isLocked = false;
        notifyListeners();
      }

      return isAuthenticated;
    } catch (e) {
      debugPrint('Error authenticating with biometric: $e');
      return false;
    }
  }

  void lock() {
    _isAuthenticated = false;
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isAuthenticated = true;
    _isLocked = false;
    notifyListeners();
  }

  Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pin_enabled', false);
      await prefs.setBool('biometric_enabled', false);
      await prefs.remove('pin_hash');
      await prefs.remove('pin_failed_attempts');
      await prefs.remove('pin_locked_until');

      _isPinEnabled = false;
      _isBiometricEnabled = false;
      _isAuthenticated = false;
      _isLocked = false;
      _pinHash = null;
      _failedAttempts = 0;
      _lockedUntil = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }
}
