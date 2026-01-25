import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const BiometricLockScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Automatically trigger authentication when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Authenticate to access your budget data',
      );

      if (isAuthenticated && mounted) {
        widget.onAuthenticated();
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isAuthenticating = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isAuthenticating = false;
        });
      }
    }
  }

  String _getErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device.';
      case 'NotEnrolled':
        return 'No biometric credentials are enrolled. Please set up biometric authentication in your device settings.';
      case 'LockedOut':
        return 'Too many failed attempts. Biometric authentication is temporarily locked.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked. Please use your device passcode.';
      default:
        return 'Authentication failed: ${e.message ?? 'Unknown error'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 56,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Expense Tracker',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Your data is protected',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 64),

                // Biometric Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAuthenticating
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: _isAuthenticating
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 32),

                // Status Message
                if (_isAuthenticating)
                  Text(
                    'Authenticating...',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                // Error Message
                if (_errorMessage.isNotEmpty && !_isAuthenticating)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Retry Button
                if (!_isAuthenticating && _errorMessage.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),

                const SizedBox(height: 16),

                // Use PIN Fallback Button
                if (!_isAuthenticating)
                  TextButton.icon(
                    onPressed: () {
                      // Show PIN entry dialog
                      _showPinDialog();
                    },
                    icon: const Icon(Icons.pin),
                    label: const Text('Use PIN Instead'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPinDialog() {
    final theme = Theme.of(context);
    final pinController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your device PIN to continue',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // For now, we'll use biometric authentication with PIN fallback
              // The local_auth package handles PIN fallback automatically when biometricOnly is false
              Navigator.pop(context);
              _authenticate();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
