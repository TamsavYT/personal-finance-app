import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database_helper.dart';
import 'theme/app_theme.dart';
import 'providers/account_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/lock_screen.dart' show AuthWrapper, LockScreen;
import 'package:home_widget/home_widget.dart';
import 'utils/notification_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      child: const ExpenseLedgerApp(),
    ),
  );
}

class ExpenseLedgerApp extends StatelessWidget {
  const ExpenseLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Expense Ledger',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(child: MainNavigation()),
          routes: {
            '/add-transaction': (context) => const AddTransactionScreen(),
          },
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onSeeAll: () {
        setState(() {
          _currentIndex = 1;
        });
      }),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ThemeProvider>().loadTheme();
      context.read<AuthProvider>().loadSettings();
      await DatabaseHelper.instance.processRecurringTransactions();
      NotificationService().initialize();
      
      // Check if opened from Home Screen Widget
      HomeWidget.setAppGroupId('com.sankar.expense_ledger');
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
      HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
    });
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri != null && uri.scheme == 'expense_ledger' && uri.host == 'add_expense') {
      Navigator.pushNamed(context, '/add-transaction');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-transaction');
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
