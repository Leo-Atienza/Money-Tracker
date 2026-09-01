import 'package:flutter/material.dart';

/// Default identity colours for categories.
///
/// This is the one place category colour is defined. It lives under `theme/`
/// rather than beside the widget because a colour table in a widget file is how
/// palettes drift — screens end up with literals that no theme change can reach.
///
/// **Why these values and not the previous ones.** The original set was the
/// stock Tailwind 500 ramp (violet `#8B5CF6`, blue `#3B82F6`, emerald
/// `#10B981`, pink `#EC4899`…). Three problems, in order of how much they cost:
///
/// 1. **Semantic collision.** `Health` was red and `Investment` was emerald —
///    the same two hues the app uses to mean *expense* and *income*. A red
///    category chip next to a red amount says two different things with one
///    colour.
/// 2. **Duplicate hues.** Shopping and Grocery were the same emerald;
///    Education, Bills and Utilities were all the same indigo. Category colour
///    exists to make a list scannable, and a palette that repeats itself cannot
///    do that.
/// 3. **Saturation.** Full-strength Tailwind next to the deliberately
///    monochrome chrome of v5.1.2 read as leftovers from a different design.
///
/// The replacements are pigment-like: distinct hues, held to a narrow
/// mid-luminance band so no single category shouts louder than the rest, and
/// desaturated enough to sit beside grayscale chrome. Red and green are left
/// alone so they keep meaning expense and income.
///
/// Contrast is not eyeballed. `test/theme/category_palette_test.dart` asserts
/// every entry clears the 3:1 WCAG floor for non-text UI as an icon on its own
/// tinted tile, in both themes.
class CategoryPalette {
  CategoryPalette._();

  // Hues, each used for one idea only.
  // Pushed to hue 28 deg / saturation 0.40. At the first attempt this was
  // #A9603F, which sat 19 deg off semantic red at saturation 0.46 — close
  // enough to read as "expense red" rather than as Food. The palette test
  // caught it; the fix is to move the colour, not to widen the test.
  static const Color _clay = Color(0xFFA17045); // amber-clay
  // A soft cocoa: same warm family as Food so the two read as related, but
  // far less saturated so they are still tellable apart in a list. These two
  // were previously the identical violet.
  static const Color _terracotta = Color(0xFF8A6A5A); // muted cocoa
  static const Color _steel = Color(0xFF4A6FA5); // muted blue
  static const Color _ochre = Color(0xFF9C7C36); // mustard
  static const Color _olive = Color(0xFF6B7F42); // yellow-green, not income
  static const Color _plum = Color(0xFF7D5A82); // dusty purple
  static const Color _teal = Color(0xFF3F7F7A); // blue-green
  static const Color _indigo = Color(0xFF565A9B); // slate violet
  static const Color _cyanSlate = Color(0xFF4C7C8C); // desaturated cyan
  static const Color _bronze = Color(0xFF8A6B33); // deep amber
  static const Color _rose = Color(0xFFA05F70); // dusty rose
  static const Color _stone = Color(0xFF6E6A66); // warm neutral

  /// Default colours for expense categories, by name.
  ///
  /// The first eight are what `database_helper` actually seeds. The rest are
  /// names a user is plausibly going to type when creating their own category —
  /// a miss is not an error, it just yields the duller [_stone], so matching a
  /// few extra names is cheap. `Groceries` in particular is not optional:
  /// `onboarding_screen` creates it for the sample data, and its absence here
  /// is why the first category a new user saw rendered grey.
  static const Map<String, Color> expenseColors = {
    'Food': _clay,
    'Transport': _steel,
    'Shopping': _ochre,
    'Groceries': _olive,
    'Entertainment': _plum,
    // Deliberately teal rather than red: red means "expense" everywhere else
    // in this app, so a red Health chip would be reporting a category as a
    // status.
    'Health': _teal,
    'Education': _indigo,
    'Bills': _cyanSlate,
    'Other': _stone,
    // Not seeded — matched opportunistically for user-created categories.
    'Grocery': _olive,
    'Restaurant': _terracotta,
    'Utilities': _cyanSlate,
    'Rent': _stone,
    'Travel': _steel,
    'Fitness': _teal,
    'Pets': _clay,
    'Subscriptions': _plum,
  };

  /// Default colours for income categories, by name.
  static const Map<String, Color> incomeColors = {
    'Salary': _bronze,
    'Freelance': _teal,
    // Deliberately slate rather than emerald, for the same reason Health is
    // not red — green already means "income" on the amount beside it.
    'Investment': _indigo,
    'Gift': _rose,
    'Other': _stone,
  };

  /// Fallback when a category name is not in the tables above — a
  /// user-created category with no colour of its own.
  static const Color expenseFallback = _stone;
  static const Color incomeFallback = _stone;

  /// Resolve the default colour for [categoryName] of [categoryType].
  static Color getDefaultColor(String categoryName, String categoryType) {
    if (categoryType == 'income') {
      return incomeColors[categoryName] ?? incomeFallback;
    }
    return expenseColors[categoryName] ?? expenseFallback;
  }

  /// Every distinct colour the palette can produce — used by the contrast test.
  ///
  /// Both fallbacks are covered already: each is [_stone], which both tables
  /// carry as their `'Other'` entry. Listing them again would be a set literal
  /// with two provably equal elements.
  static List<Color> get allColors => <Color>{
        ...expenseColors.values,
        ...incomeColors.values,
      }.toList(growable: false);
}
