import 'dart:developer';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  bool _isListening = false;
  static const String _prefKey = 'auto_track_notifications';

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

    final packageName = event.packageName ?? '';
    
    // Check if it's from a payment app
    if (packageName == 'com.google.android.apps.nbu.paisa.user' ||
        packageName == 'net.one97.paytm' ||
        packageName == 'com.phonepe.app') {
          
      final title = event.title ?? '';
      final content = event.content ?? '';
      
      // Combine title and content to parse
      final textToParse = '$title $content';
      
      // Simple check to ensure it's a payment/debit notification
      if (textToParse.toLowerCase().contains('paid') || 
          textToParse.toLowerCase().contains('sent') || 
          textToParse.toLowerCase().contains('debited')) {
        
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
