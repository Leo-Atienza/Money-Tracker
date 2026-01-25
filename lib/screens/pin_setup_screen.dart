import 'package:flutter/material.dart';
import '../utils/pin_security_helper.dart';
import '../utils/haptic_helper.dart';

/// Screen for setting up a new PIN or changing an existing PIN
class PinSetupScreen extends StatefulWidget {
  final bool isChangingPin;
  final String? oldPin; // Required when changing PIN

  const PinSetupScreen({
    super.key,
    this.isChangingPin = false,
    this.oldPin,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  int _pinLength = 4;
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirmMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          widget.isChangingPin ? 'Change PIN' : 'Set Up PIN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Title and instruction
              Text(
                _isConfirmMode ? 'Confirm your PIN' : 'Create a PIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirmMode
                    ? 'Enter your PIN again to confirm'
                    : 'Enter a $_pinLength-digit PIN to secure your app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // PIN length selector (only in first step)
              if (!_isConfirmMode) ...[
                Text(
                  'PIN Length',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [4, 5, 6].map((length) {
                    final isSelected = _pinLength == length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _pinLength = length;
                            _firstPin = '';
                          });
                          HapticHelper.lightImpact();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '$length',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 48),
              ],

              // PIN dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final currentPin = _isConfirmMode ? _confirmPin : _firstPin;
                  final isFilled = index < currentPin.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Number pad
              _buildNumberPad(theme),

              const SizedBox(height: 24),
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
            padding: const EdgeInsets.only(bottom: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
              style: TextStyle(
                fontSize: 28,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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

      if (_isConfirmMode) {
        if (_confirmPin.length < _pinLength) {
          _confirmPin += number;

          // Auto-submit when PIN is complete
          if (_confirmPin.length == _pinLength) {
            _submitPin();
          }
        }
      } else {
        if (_firstPin.length < _pinLength) {
          _firstPin += number;

          // Move to confirm mode when first PIN is complete
          if (_firstPin.length == _pinLength) {
            Future.delayed(const Duration(milliseconds: 200), () {
              setState(() {
                _isConfirmMode = true;
              });
            });
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    HapticHelper.lightImpact();

    setState(() {
      _errorMessage = null;

      if (_isConfirmMode) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Go back to first PIN entry
          _isConfirmMode = false;
          _firstPin = '';
        }
      } else {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      }
    });
  }

  Future<void> _submitPin() async {
    if (_firstPin != _confirmPin) {
      await HapticHelper.error();
      setState(() {
        _errorMessage = 'PINs do not match. Try again.';
        _isConfirmMode = false;
        _firstPin = '';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool success;

      if (widget.isChangingPin && widget.oldPin != null) {
        success = await PinSecurityHelper.changePin(widget.oldPin!, _firstPin);
      } else {
        success = await PinSecurityHelper.setPin(_firstPin);
      }

      if (success) {
        await HapticHelper.success();
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        await HapticHelper.error();
        setState(() {
          _errorMessage = 'Failed to save PIN. Please try again.';
          _isConfirmMode = false;
          _firstPin = '';
          _confirmPin = '';
        });
      }
    } catch (e) {
      await HapticHelper.error();
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isConfirmMode = false;
        _firstPin = '';
        _confirmPin = '';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
