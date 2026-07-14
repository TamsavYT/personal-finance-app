import 'dart:developer';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import 'upi_payment_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  bool _isListening = false;
  static const String _prefKey = 'auto_track_notifications';
  static const Duration _dedupWindow = Duration(seconds: 30);

  // Notifications processed in the last _dedupWindow, keyed by package+text.
  // A map (not a single last-key) so two distinct notifications sharing the
  // window don't clobber each other's dedup state.
  final Map<String, DateTime> _recentlyProcessed = {};

  Future<bool> get isAutoTrackingEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setAutoTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    if (enabled) {
      startListening();
    }
  }

  Future<bool> requestPermission() async {
    return await NotificationListenerService.requestPermission();
  }

  Future<bool> isPermissionGranted() async {
    return await NotificationListenerService.isPermissionGranted();
  }

  Future<void> initialize() async {
    final enabled = await isAutoTrackingEnabled;
    if (enabled) {
      startListening();
    }
  }

  void startListening() async {
    if (_isListening) return;

    bool granted = await isPermissionGranted();
    if (!granted) {
      log('Notification permission not granted.');
      return;
    }

    _isListening = true;
    NotificationListenerService.notificationsStream.listen((ServiceNotificationEvent event) {
      _handleNotification(event);
    });
  }

  void _handleNotification(ServiceNotificationEvent event) async {
    final enabled = await isAutoTrackingEnabled;
    if (!enabled) return;

    final packageName = event.packageName;
    
    // Check if it's from a payment app
    if (packageName == 'com.google.android.apps.nbu.paisa.user' ||
        packageName == 'net.one97.paytm' ||
        packageName == 'com.phonepe.app') {
          
      final title = event.title;
      final content = event.content;
      
      // Combine title and content to parse
      final textToParse = '$title $content';
      
      // Simple check to ensure it's a payment/debit notification
      if (textToParse.toLowerCase().contains('paid') ||
          textToParse.toLowerCase().contains('sent') ||
          textToParse.toLowerCase().contains('debited')) {

        // Key on the OS notification's own id+postTime, not the parsed text -
        // two distinct real payments (e.g. splitting a bill) can render
        // identical notification text within the window and must not be
        // treated as the same event.
        final dedupKey = '$packageName|${event.id}|${event.timestamp}';
        final now = DateTime.now();
        _recentlyProcessed.removeWhere((_, at) => now.difference(at) > _dedupWindow);
        if (_recentlyProcessed.containsKey(dedupKey)) {
          log('Duplicate notification ignored: $dedupKey');
          return;
        }
        _recentlyProcessed[dedupKey] = now;

        _parseAndSaveExpense(textToParse);
      }
    }
  }

  void _parseAndSaveExpense(String text) async {
    // Try to find amount: Rs. 100, ₹100, INR 100
    final amountRegex = RegExp(r'(?:Rs\.?|INR|₹)\s?(\d+(?:,\d+)*(?:\.\d+)?)', caseSensitive: false);
    final match = amountRegex.firstMatch(text);

    if (match != null && match.groupCount >= 1) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {

          // This notification may be the delayed confirmation of a payment
          // started from our own UPI screen (see UpiPaymentService) - GPay/
          // PhonePe often don't report success back through the app-switch
          // callback for P2P transfers, so this is the fallback that
          // actually logs it.
          final upiService = UpiPaymentService.instance;
          if (await upiService.tryReconcile(amount)) {
            log('Reconciled UPI payment via notification: $amount');
            return;
          }
          if (upiService.wasAlreadyLogged(amount)) {
            log('Notification amount already logged via UPI callback, skipping: $amount');
            return;
          }

          // Get database helper
          final db = DatabaseHelper.instance;
          
          // Find active expense category (e.g., Other Expense)
          final categories = await db.getCategoriesByType('expense');
          if (categories.isEmpty) return;
          final category = categories.firstWhere(
            (c) => c.name.toLowerCase().contains('other'), 
            orElse: () => categories.first
          );
          
          // Find UPI account or first active account
          final accounts = await db.getActiveAccounts();
          if (accounts.isEmpty) return;
          final account = accounts.firstWhere(
            (a) => a.type == 'upi' || a.name.toLowerCase().contains('upi'), 
            orElse: () => accounts.first
          );
          
          final snippet = text.length > 30 ? '${text.substring(0, 30)}...' : text;
          final note = 'Auto-tracked: $snippet';
          
          final transaction = TransactionRecord(
            type: 'expense',
            amount: amount,
            categoryId: category.id!,
            accountId: account.id!,
            note: note,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          );
          
          await db.insertTransaction(transaction);
          log('Auto-saved transaction: $amount');
        }
      }
    }
  }
}
