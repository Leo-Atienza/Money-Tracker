import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium animation utilities for a polished app experience
class PremiumAnimations {
  /// Standard duration for micro-interactions
  static const Duration microDuration = Duration(milliseconds: 150);

  /// Standard duration for transitions
  static const Duration shortDuration = Duration(milliseconds: 200);

  /// Standard duration for page transitions
  static const Duration mediumDuration = Duration(milliseconds: 300);

  /// Standard duration for complex animations
  static const Duration longDuration = Duration(milliseconds: 500);

  /// Standard curve for enter animations
  static const Curve enterCurve = Curves.easeOutCubic;

  /// Standard curve for exit animations
  static const Curve exitCurve = Curves.easeInCubic;

  /// Spring curve for bouncy animations
  static const Curve springCurve = Curves.elasticOut;

  /// Smooth curve for most animations
  static const Curve smoothCurve = Curves.easeInOutCubic;
}

/// Animated counter that smoothly transitions between values
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimalPlaces;
  final bool compact;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.decimalPlaces = 2,
    this.compact = false,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = Tween<double>(begin: _oldValue, end: widget.value)
          .animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    if (widget.compact) {
      if (value.abs() >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value.abs() >= 1000) {
        return '${(value / 1000).toStringAsFixed(1)}K';
      }
    }
    return value.toStringAsFixed(widget.decimalPlaces);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_formatValue(_animation.value)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Staggered animation for list items
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  /// Maximum total delay before animation starts (prevents long waits for large lists)
  final Duration maxTotalDelay;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
    this.beginOffset = const Offset(0, 0.1),
    this.maxTotalDelay = const Duration(milliseconds: 500),
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // FIX: Cap the total delay to prevent long waits for large lists
    // Items beyond the cap threshold animate immediately
    final calculatedDelay = widget.delay * widget.index;
    final actualDelay = calculatedDelay > widget.maxTotalDelay
        ? Duration.zero // Animate immediately for items past the threshold
        : calculatedDelay;

    if (actualDelay == Duration.zero) {
      // Start animation immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // Stagger the animation based on index
      Future.delayed(actualDelay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated scale wrapper for tap feedback
class ScaleTapAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final bool enableHaptic;

  const ScaleTapAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.97,
    this.enableHaptic = true,
  });

  @override
  State<ScaleTapAnimation> createState() => _ScaleTapAnimationState();
}

class _ScaleTapAnimationState extends State<ScaleTapAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
        widget.onTap?.call();
      },
      onLongPress: () {
        if (widget.enableHaptic) {
          HapticFeedback.mediumImpact();
        }
        widget.onLongPress?.call();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Premium page route with slide and fade transition
class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  PremiumPageRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetTween = Tween<Offset>(
              begin: _getBeginOffset(direction),
              end: Offset.zero,
            );

            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
              ),
            );

            final slideAnimation = offsetTween.animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
        );

  static Offset _getBeginOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.right:
        return const Offset(0.15, 0);
      case SlideDirection.left:
        return const Offset(-0.15, 0);
      case SlideDirection.up:
        return const Offset(0, 0.15);
      case SlideDirection.down:
        return const Offset(0, -0.15);
    }
  }
}

enum SlideDirection { right, left, up, down }

/// Animated card that elevates on hover/press
class AnimatedPressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double elevation;
  final double pressedElevation;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;

  const AnimatedPressCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.elevation = 0,
    this.pressedElevation = 4,
    this.borderRadius,
    this.color,
    this.border,
  });

  @override
  State<AnimatedPressCard> createState() => _AnimatedPressCardState();
}

class _AnimatedPressCardState extends State<AnimatedPressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.pressedElevation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color ?? theme.colorScheme.surface,
                borderRadius: radius,
                border: widget.border,
                boxShadow: [
                  BoxShadow(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withAlpha((40 + _elevationAnimation.value * 10).round())
                        : Colors.black.withAlpha((8 + _elevationAnimation.value * 4).round()),
                    blurRadius: 12 + _elevationAnimation.value * 2,
                    offset: Offset(0, 4 + _elevationAnimation.value),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fade in widget on first build
class FadeInOnLoad extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const FadeInOnLoad({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
  });

  @override
  State<FadeInOnLoad> createState() => _FadeInOnLoadState();
}

class _FadeInOnLoadState extends State<FadeInOnLoad>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Bounce animation wrapper
class BounceAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Duration duration;

  const BounceAnimation({
    super.key,
    required this.child,
    this.animate = true,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(BounceAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

/// Animated progress bar with smooth transitions
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 4,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  color: color ?? theme.colorScheme.primary,
                  borderRadius: radius,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pulsing dot indicator for loading states
class PulsingDot extends StatefulWidget {
  final Color? color;
  final double size;

  const PulsingDot({
    super.key,
    this.color,
    this.size = 8,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color ?? Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Smooth theme transition wrapper
class AnimatedThemeWrapper extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AnimatedThemeWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: Theme.of(context),
      duration: duration,
      curve: Curves.easeInOut,
      child: child,
    );
  }
}

/// Extension methods for easy navigation with transitions
extension NavigatorExtensions on NavigatorState {
  Future<T?> pushPremium<T>(Widget page, {SlideDirection direction = SlideDirection.right}) {
    return push<T>(PremiumPageRoute<T>(page: page, direction: direction));
  }
}

/// Extension for BuildContext to easily navigate
extension ContextNavigatorExtensions on BuildContext {
  Future<T?> pushPremium<T>(Widget page, {SlideDirection direction = SlideDirection.right}) {
    return Navigator.of(this).push<T>(PremiumPageRoute<T>(page: page, direction: direction));
  }
}
