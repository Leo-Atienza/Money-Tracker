import 'package:flutter/material.dart';

/// Lays [child] (a Column, typically with Spacers) out at least as tall as the
/// space it is given, and scrolls it when it needs more. On a short screen or
/// with large text the content stays reachable instead of overflowing; on a
/// tall one the Spacers still share out the room, exactly as before.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
