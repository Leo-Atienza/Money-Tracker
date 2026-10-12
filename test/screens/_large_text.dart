import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The compact phone class the audit tests at: 360dp wide (the narrowest
/// common Android width), short enough that tall content must scroll.
const Size compactPhone = Size(360, 640);

/// Large text, as a user who raised the system font size has it.
const double largeTextScale = 1.3;

bool _fontLoaded = false;

/// Loads the app's real typeface. The default test font draws every glyph a
/// full em wide, which reports overflows a device never shows (and hides
/// none); measuring with Hanken Grotesk makes "overflowed by N pixels" mean
/// what it means on the phone.
Future<void> loadAppFont() async {
  if (_fontLoaded) return;
  final loader = FontLoader('HankenGrotesk')
    ..addFont(rootBundle.load(
        'assets/fonts/HankenGrotesk/HankenGrotesk-Variable.ttf'));
  await loader.load();
  _fontLoaded = true;
}

/// A MaterialApp.builder that applies [largeTextScale] to everything below.
Widget largeTextBuilder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(largeTextScale)),
      child: child!,
    );
