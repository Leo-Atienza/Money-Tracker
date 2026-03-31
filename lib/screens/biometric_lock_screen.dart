import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';
import '../constants/spacing.dart';
import '../main.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const BiometricLockScreen({super.key, required this.onAuthenticated});

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
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Spacing.screenPadding),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 56,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: Spacing.xxl),

                // Title
                Text(
                  'Expense Tracker',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: Spacing.md),

                // Subtitle
                Text(
                  'Your data is protected',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 64),

                // Biometric Icon
                Container(
                  padding: const EdgeInsets.all(Spacing.screenPadding),
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

                const SizedBox(height: Spacing.xxl),

                // Status Message
                if (_isAuthenticating)
                  Text(
                    'Authenticating...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                // Error Message
                if (_errorMessage.isNotEmpty && !_isAuthenticating)
                  Builder(
                    builder: (context) {
                      final appColors = Theme.of(context).extension<AppColors>()!;
                      return Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: appColors.expenseRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(Spacing.radiusMedium),
                          border: Border.all(color: appColors.expenseRed.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: appColors.expenseRed,
                              size: 24,
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: Spacing.xxl),

                // Retry Button
                if (!_isAuthenticating && _errorMessage.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xxl,
                        vertical: Spacing.md,
                      ),
                    ),
                  ),

                const SizedBox(height: Spacing.md),

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

    // FIX: PIN fallback requires local_auth package with biometricOnly: false.
    // Since BiometricService is a stub, show a message instead of a fake PIN dialog
    // that ignores input and just calls _authenticate() (which always returns true).
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Spacing.radiusXLarge)),
        title: const Text('PIN Not Available'),
        content: Text(
          'Device credential authentication requires the local_auth package. '
          'Please use biometric authentication or contact support.',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _authenticate();
            },
            child: const Text('Try Biometric Again'),
          ),
        ],
      ),
    );
  }
}
