import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/pin_security_helper.dart';
import '../utils/haptic_helper.dart';
import '../constants/spacing.dart';
import '../main.dart';

/// Screen for unlocking the app with PIN
class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _enteredPin = '';
  int _pinLength = 4;
  bool _isLoading = false;
  String? _errorMessage;
  // FIX: Use PinSecurityHelper's global tracking instead of local tracking
  // to prevent inconsistency between local and global rate limiting state
  int _remainingAttempts = 5;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    if (_lockoutSeconds <= 0) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds--;
        if (_lockoutSeconds <= 0) {
          timer.cancel();
          _errorMessage = null;
        } else {
          _errorMessage =
              'Too many attempts. Try again in $_lockoutSeconds seconds.';
        }
      });
    });
  }

  /// FIX: Load both PIN length and current rate limiting state from PinSecurityHelper
  Future<void> _loadInitialState() async {
    final length = await PinSecurityHelper.getPinLength();
    final remaining = await PinSecurityHelper.getRemainingAttempts();
    final lockoutSecs = await PinSecurityHelper.getRemainingLockoutSeconds();

    if (!mounted) return;
    setState(() {
      _pinLength = length;
      _remainingAttempts = remaining;
      _lockoutSeconds = lockoutSecs;
      if (_lockoutSeconds > 0) {
        _errorMessage =
            'Too many attempts. Try again in $_lockoutSeconds seconds.';
        _startLockoutCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),

              // App icon/logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(Spacing.radiusXLarge),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: theme.colorScheme.onPrimary,
                ),
              ),

              const SizedBox(height: Spacing.screenPadding),

              // Title
              Text(
                'Money Tracker',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 48),

              // Instruction
              Text(
                'Enter your PIN to unlock',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: Spacing.xxl),

              // PIN dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: isFilled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: Spacing.screenPadding),
                Builder(
                  builder: (context) {
                    final appColors = Theme.of(context).extension<AppColors>()!;
                    return Container(
                      padding: const EdgeInsets.all(Spacing.sm),
                      decoration: BoxDecoration(
                        color: appColors.expenseRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: appColors.expenseRed,
                            size: 20,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Flexible(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: appColors.expenseRed,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const Spacer(),

              // Number pad
              _buildNumberPad(theme),

              const SizedBox(height: Spacing.screenPadding),

              // Forgot PIN hint - show after multiple failed attempts
              // FIX: Use global remaining attempts from PinSecurityHelper
              if (_remainingAttempts <= 2)
                TextButton(
                  onPressed: () {
                    _showResetHint(context, theme);
                  },
                  child: Text(
                    'Forgot PIN?',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

              const SizedBox(height: Spacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    return Column(
      children: [
        // Rows 1-3
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                final number = row * 3 + col + 1;
                return _buildNumberButton(number.toString(), theme);
              }),
            ),
          ),
        // Row 4: blank, 0, backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // blank space
            _buildNumberButton('0', theme),
            _buildBackspaceButton(theme),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: InkWell(
        onTap: _isLoading ? null : () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: InkWell(
        onTap: _isLoading ? null : _onBackspacePressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: theme.colorScheme.onSurface,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    HapticHelper.lightImpact();

    setState(() {
      _errorMessage = null;

      if (_enteredPin.length < _pinLength) {
        _enteredPin += number;

        // Auto-verify when PIN is complete
        if (_enteredPin.length == _pinLength) {
          _verifyPin();
        }
      }
    });
  }

  void _onBackspacePressed() {
    HapticHelper.lightImpact();

    setState(() {
      _errorMessage = null;
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    try {
      // FIX: Check for lockout before attempting verification
      final isLockedOut = await PinSecurityHelper.isLockedOut();
      if (isLockedOut) {
        final lockoutSecs =
            await PinSecurityHelper.getRemainingLockoutSeconds();
        await HapticHelper.error();
        if (!mounted) return;
        setState(() {
          _enteredPin = '';
          _lockoutSeconds = lockoutSecs;
          _errorMessage =
              'Too many attempts. Try again in $lockoutSecs seconds.';
        });
        return;
      }

      final isValid = await PinSecurityHelper.verifyPin(_enteredPin);

      if (isValid) {
        await HapticHelper.success();
        if (mounted) {
          Navigator.pop(context, true); // Return true on successful unlock
        }
      } else {
        await HapticHelper.error();
        // FIX: Fetch the current remaining attempts from PinSecurityHelper
        final remaining = await PinSecurityHelper.getRemainingAttempts();
        final lockoutSecs =
            await PinSecurityHelper.getRemainingLockoutSeconds();

        if (!mounted) return;
        setState(() {
          _enteredPin = '';
          _remainingAttempts = remaining;
          _lockoutSeconds = lockoutSecs;

          if (lockoutSecs > 0) {
            _errorMessage =
                'Too many attempts. Try again in $lockoutSecs seconds.';
            _startLockoutCountdown();
          } else if (remaining <= 0) {
            _errorMessage = 'Too many failed attempts. Please try again later.';
          } else {
            _errorMessage =
                'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
          }
        });
      }
    } catch (e) {
      await HapticHelper.error();
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showResetHint(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
          'To reset your PIN, you will need to clear the app data from your device settings. '
          'This will delete all your data including expenses, budgets, and settings.\n\n'
          'Go to: Settings > Apps > Money Tracker > Storage > Clear Data',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
