import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthWrapper extends StatelessWidget {
  final Widget child;
  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isLocked = auth.isLocked && !auth.isAuthenticated;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget widget, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                child: widget,
              ),
            );
          },
          child: isLocked 
              ? const LockScreen(key: ValueKey('lock_screen')) 
              : KeyedSubtree(key: const ValueKey('app_content'), child: child),
        );
      },
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pinInput = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isBiometricEnabled) {
        _authenticateBiometric(auth);
      }
    });
  }

  Future<void> _authenticateBiometric(AuthProvider auth) async {
    final success = await auth.authenticateWithBiometric();
    if (!success && mounted) {
      // Failed or cancelled, user can use PIN
    }
  }

  void _onDigitPress(String digit) {
    if (_pinInput.length < 4) {
      setState(() {
        _pinInput += digit;
        _hasError = false;
      });
      if (_pinInput.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_pinInput.isNotEmpty) {
      setState(() {
        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.authenticateWithPin(_pinInput);
    if (!success) {
      setState(() {
        _pinInput = '';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.teal),
                const SizedBox(height: 24),
                const Text(
                  'App Locked',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Enter your PIN to access'),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pinInput.length
                            ? (_hasError ? Colors.red : Colors.teal)
                            : Colors.transparent,
                        border: Border.all(
                          color: _hasError ? Colors.red : Colors.teal,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                if (_hasError)
                  const Text('Incorrect PIN', style: TextStyle(color: Colors.red)),
                const SizedBox(height: 48),
                _buildKeypad(),
                const SizedBox(height: 24),
                if (auth.isBiometricEnabled)
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.fingerprint, color: Colors.teal),
                    onPressed: () => _authenticateBiometric(auth),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('1'), _buildKey('2'), _buildKey('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('4'), _buildKey('5'), _buildKey('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey('7'), _buildKey('8'), _buildKey('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 64),
              _buildKey('0'),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: _onDelete,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 64,
      height: 64,
      child: InkWell(
        onTap: () => _onDigitPress(digit),
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
