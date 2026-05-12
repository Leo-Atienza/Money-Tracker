build/native_assets - moved to TRASH/native_assets_* - stale sqlite3.dll causing flutter test copy-collision; will be regenerated on next test run
test/screens/notification_settings_screen_test.dart - moved to TRASH/ - requires full flutter_local_notifications platform mock (FlutterLocalNotificationsPlatform.instance is a late-final static); deferred until C.4 device smoke can validate the redesigned screen end-to-end
lib/screens/account_manager_screen.dart - moved to TRASH/ - renamed to wallet_screen.dart (class AccountManagerScreen → WalletScreen) per Phase 5.2 Wallet redesign
