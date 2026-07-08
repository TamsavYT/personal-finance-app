import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLocked = false;
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isAuthenticated = false;
  String? _pin;

  bool get isLocked => _isLocked;
  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAuthenticated => _isAuthenticated;
  String? get pin => _pin;

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isPinEnabled = prefs.getBool('pin_enabled') ?? false;
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _pin = prefs.getString('pin_code');
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
      await prefs.setString('pin_code', pin);

      _isPinEnabled = true;
      _pin = pin;

      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling PIN: $e');
    }
  }

  Future<void> disablePin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('pin_enabled', false);
      await prefs.remove('pin_code');

      _isPinEnabled = false;
      _pin = null;

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
      if (pin == _pin) {
        _isAuthenticated = true;
        _isLocked = false;
        notifyListeners();
        return true;
      }
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
      await prefs.remove('pin_code');

      _isPinEnabled = false;
      _isBiometricEnabled = false;
      _isAuthenticated = false;
      _isLocked = false;
      _pin = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }
}
