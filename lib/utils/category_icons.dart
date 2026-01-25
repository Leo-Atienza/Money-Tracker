import 'package:flutter/material.dart';

/// Helper class for category icons.
/// Provides default icons for built-in categories and a curated list for user selection.
class CategoryIcons {
  CategoryIcons._();

  /// Default icons for expense categories (by name)
  static const Map<String, IconData> defaultExpenseIcons = {
    'Food': Icons.restaurant_rounded,
    'Transport': Icons.directions_car_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Entertainment': Icons.movie_rounded,
    'Health': Icons.medical_services_rounded,
    'Education': Icons.school_rounded,
    'Bills': Icons.receipt_long_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  /// Default icons for income categories (by name)
  static const Map<String, IconData> defaultIncomeIcons = {
    'Salary': Icons.account_balance_wallet_rounded,
    'Freelance': Icons.laptop_rounded,
    'Investment': Icons.trending_up_rounded,
    'Gift': Icons.card_giftcard_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  /// Map of icon codePoints to IconData for reverse lookup
  /// This allows us to retrieve constant IconData from stored codePoints
  static final Map<int, IconData> _iconByCodePoint = {
    for (final icon in availableIcons) icon.codePoint: icon,
  };

  /// Curated list of icons for user selection
  /// Organized by category for easier browsing
  static const List<IconData> availableIcons = [
    // Money & Finance
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.attach_money_rounded,
    Icons.trending_up_rounded,
    Icons.receipt_long_rounded,

    // Food & Drink
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.fastfood_rounded,
    Icons.local_grocery_store_rounded,
    Icons.local_bar_rounded,
    Icons.cake_rounded,

    // Transport
    Icons.directions_car_rounded,
    Icons.directions_bus_rounded,
    Icons.local_taxi_rounded,
    Icons.flight_rounded,
    Icons.train_rounded,
    Icons.directions_bike_rounded,
    Icons.electric_scooter_rounded,
    Icons.local_gas_station_rounded,

    // Shopping
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.storefront_rounded,
    Icons.local_mall_rounded,
    Icons.checkroom_rounded,

    // Entertainment
    Icons.movie_rounded,
    Icons.music_note_rounded,
    Icons.sports_esports_rounded,
    Icons.sports_soccer_rounded,
    Icons.theater_comedy_rounded,
    Icons.celebration_rounded,
    Icons.nightlife_rounded,

    // Health & Wellness
    Icons.medical_services_rounded,
    Icons.local_hospital_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.self_improvement_rounded,
    Icons.medication_rounded,

    // Education & Work
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.laptop_rounded,
    Icons.work_rounded,
    Icons.business_center_rounded,
    Icons.science_rounded,

    // Home & Utilities
    Icons.home_rounded,
    Icons.electrical_services_rounded,
    Icons.water_drop_rounded,
    Icons.wifi_rounded,
    Icons.local_laundry_service_rounded,
    Icons.cleaning_services_rounded,
    Icons.handyman_rounded,

    // Communication
    Icons.phone_android_rounded,
    Icons.email_rounded,
    Icons.subscriptions_rounded,

    // Personal
    Icons.person_rounded,
    Icons.child_care_rounded,
    Icons.pets_rounded,
    Icons.card_giftcard_rounded,
    Icons.favorite_rounded,
    Icons.volunteer_activism_rounded,

    // Travel & Leisure
    Icons.beach_access_rounded,
    Icons.hotel_rounded,
    Icons.luggage_rounded,
    Icons.photo_camera_rounded,

    // Generic
    Icons.category_rounded,
    Icons.label_rounded,
    Icons.bookmark_rounded,
    Icons.star_rounded,
    Icons.more_horiz_rounded,
  ];

  /// Get the icon code point as a string for storage
  static String iconToString(IconData icon) {
    return icon.codePoint.toString();
  }

  /// Parse an icon from its stored string representation
  /// Uses lookup map to return constant IconData (required for tree-shaking)
  static IconData iconFromString(String? iconStr) {
    if (iconStr == null || iconStr.isEmpty) {
      return Icons.category_rounded;
    }
    final codePoint = int.tryParse(iconStr);
    if (codePoint == null) {
      return Icons.category_rounded;
    }
    // Look up the constant IconData from our available icons
    // Falls back to category icon if the codePoint isn't in our list
    return _iconByCodePoint[codePoint] ?? Icons.category_rounded;
  }

  /// Get the default icon for a category by name and type
  static IconData getDefaultIcon(String categoryName, String type) {
    if (type == 'income') {
      return defaultIncomeIcons[categoryName] ?? Icons.category_rounded;
    }
    return defaultExpenseIcons[categoryName] ?? Icons.category_rounded;
  }

  /// Get icon for a category, falling back to default if none set
  static IconData getIcon(String? iconStr, String categoryName, String type) {
    if (iconStr != null && iconStr.isNotEmpty) {
      return iconFromString(iconStr);
    }
    return getDefaultIcon(categoryName, type);
  }
}
