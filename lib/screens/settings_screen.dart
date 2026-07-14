import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/currency_formatter.dart';
import '../utils/export_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../utils/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildAccountsSection(context),
          const Divider(),
          _buildCategoriesSection(context),
          const Divider(),
          _buildBudgetsSection(context),
          const Divider(),
          ListTile(
            title: const Text('Recurring Transactions'),
            leading: const Icon(Icons.repeat),
            onTap: () => Navigator.pushNamed(context, '/recurring-transactions'),
          ),
          const Divider(),
          _buildAutoTrackingSection(context),
          const Divider(),
          _buildAppearanceSection(context),
          const Divider(),
          _buildSecuritySection(context),
          const Divider(),
          _buildDataSection(context),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text('Expense Ledger v1.0.0\nMade with ❤️', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context) {
    return Consumer<AccountProvider>(
      builder: (context, provider, child) {
        return ExpansionTile(
          title: const Text('Accounts'),
          leading: const Icon(Icons.account_balance),
          children: [
            ...provider.accounts.map((acc) => ListTile(
                  title: Text(acc.name),
                  subtitle: Text(acc.type),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'clear') {
                        final txProvider = context.read<TransactionProvider>();
                        await txProvider.clearTransactionsForAccount(acc.id!);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transactions cleared for ${acc.name}')),
                        );
                      } else if (value == 'delete') {
                        provider.deleteAccount(acc.id!);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'clear', child: Text('Clear Transactions')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Account', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _showAddAccountDialog(context),
                child: const Text('Add Account'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String type = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: ['cash', 'bank', 'upi', 'wallet', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => type = val!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(labelText: 'Initial Balance'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final balance = double.tryParse(balanceController.text) ?? 0.0;
                final acc = Account(
                  name: nameController.text.trim(),
                  type: type,
                  icon: '0xe57a', // default icon
                  color: '#4CAF50', // default color
                  initialBalance: balance,
                  createdAt: DateTime.now(),
                  isActive: true,
                );
                context.read<AccountProvider>().addAccount(acc);
                Navigator.pop(context);
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        return ExpansionTile(
          title: const Text('Categories'),
          leading: const Icon(Icons.category),
          children: [
            const ListTile(title: Text('Income Categories', style: TextStyle(fontWeight: FontWeight.bold))),
            ...provider.incomeCategories.map((cat) => _buildCategoryTile(cat, provider)),
            const ListTile(title: Text('Expense Categories', style: TextStyle(fontWeight: FontWeight.bold))),
            ...provider.expenseCategories.map((cat) => _buildCategoryTile(cat, provider)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _showAddCategoryDialog(context),
                child: const Text('Add Category'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryTile(Category cat, CategoryProvider provider) {
    return ListTile(
      title: Text(cat.name),
      trailing: IconButton(
        icon: const Icon(Icons.delete), 
        onPressed: () => provider.deleteCategory(cat.id!),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    String type = 'expense';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: ['income', 'expense']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => type = val!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final cat = Category(
                  name: nameController.text.trim(),
                  type: type,
                  icon: '0xe57a',
                  color: '#2196F3',
                  isDefault: false,
                  isActive: true,
                );
                context.read<CategoryProvider>().addCategory(cat);
                Navigator.pop(context);
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetsSection(BuildContext context) {
    return Consumer2<BudgetProvider, CategoryProvider>(
      builder: (context, budgetProvider, catProvider, child) {
        // Load budgets if not loaded (deferred to avoid mutating state during build)
        final now = DateTime.now();
        if (!budgetProvider.hasLoadedFor(now.month, now.year) && !budgetProvider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            budgetProvider.loadBudgets(now.month, now.year);
          });
        }

        return ExpansionTile(
          title: const Text('Budgets'),
          leading: const Icon(Icons.pie_chart),
          children: [
            ...budgetProvider.budgets.map((b) {
              final cat = catProvider.getCategoryById(b.categoryId);
              return ListTile(
                title: Text(cat?.name ?? 'Unknown Category'),
                subtitle: Text('Limit: ${CurrencyFormatter.formatCurrency(b.limit)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => budgetProvider.deleteBudget(b.id!),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _showAddBudgetDialog(context, catProvider),
                child: const Text('Set Budget'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddBudgetDialog(BuildContext context, CategoryProvider catProvider) {
    final limitController = TextEditingController();
    int? categoryId;
    if (catProvider.expenseCategories.isNotEmpty) {
      categoryId = catProvider.expenseCategories.first.id;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                items: catProvider.expenseCategories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (val) => categoryId = val,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: limitController,
                decoration: const InputDecoration(labelText: 'Budget Limit'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final limit = double.tryParse(limitController.text) ?? 0.0;
                if (categoryId != null && limit > 0) {
                  final now = DateTime.now();
                  final budget = Budget(
                    categoryId: categoryId!,
                    limit: limit,
                    month: now.month,
                    year: now.year,
                  );
                  context.read<BudgetProvider>().addBudget(budget);
                  Navigator.pop(context);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAutoTrackingSection(BuildContext context) {
    return FutureBuilder<bool>(
      future: NotificationService().isAutoTrackingEnabled,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        bool isEnabled = snapshot.data!;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return SwitchListTile(
              title: const Text('Auto-Track Expenses (Android)'),
              subtitle: const Text('Reads GPay/Paytm notifications to auto-add expenses'),
              secondary: const Icon(Icons.notifications_active),
              value: isEnabled,
              onChanged: (val) async {
                if (val) {
                  final granted = await NotificationService().isPermissionGranted();
                  if (!granted) {
                    final req = await NotificationService().requestPermission();
                    if (req != true) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permission required for auto-tracking')),
                        );
                      }
                      return;
                    }
                  }
                }
                await NotificationService().setAutoTrackingEnabled(val);
                setState(() {
                  isEnabled = val;
                });
              },
            );
          }
        );
      }
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        return SwitchListTile(
          title: const Text('Dark Mode'),
          secondary: const Icon(Icons.dark_mode),
          value: provider.isDarkMode,
          onChanged: (val) {
            provider.toggleTheme();
          },
        );
      },
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            const ListTile(title: Text('Security', style: TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(
              title: const Text('PIN Lock'),
              secondary: const Icon(Icons.pin),
              value: provider.isPinEnabled,
              onChanged: (val) {
                if (val) {
                  _showSetPinDialog(context, provider);
                } else {
                  provider.disablePin();
                }
              },
            ),
            SwitchListTile(
              title: const Text('Biometric Lock'),
              secondary: const Icon(Icons.fingerprint),
              value: provider.isBiometricEnabled,
              onChanged: (val) {
                if (val) {
                  provider.enableBiometric();
                } else {
                  provider.disableBiometric();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('Export Data to CSV'),
          leading: const Icon(Icons.download),
          onTap: () async {
            final txProvider = context.read<TransactionProvider>();
            final catProvider = context.read<CategoryProvider>();
            final accProvider = context.read<AccountProvider>();
            
            try {
              final path = await ExportHelper.exportToCsv(
                txProvider.transactions,
                catProvider.categories,
                accProvider.accounts,
              );
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox?;
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(path)],
                  text: 'Expense Ledger CSV Export',
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                ));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to export: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          title: const Text('Export Data to PDF'),
          leading: const Icon(Icons.picture_as_pdf),
          onTap: () async {
            final txProvider = context.read<TransactionProvider>();
            final catProvider = context.read<CategoryProvider>();
            final accProvider = context.read<AccountProvider>();
            
            try {
              final path = await ExportHelper.exportToPdf(
                txProvider.transactions,
                catProvider.categories,
                accProvider.accounts,
              );
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox?;
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(path)],
                  text: 'Expense Ledger PDF Report',
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                ));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to export PDF: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          title: const Text('Import Data from CSV'),
          leading: const Icon(Icons.upload_file),
          onTap: () async {
            final txProvider = context.read<TransactionProvider>();
            final catProvider = context.read<CategoryProvider>();
            final accProvider = context.read<AccountProvider>();

            try {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['csv'],
              );
              final pickedPath = result?.files.single.path;
              if (pickedPath == null) return;

              final parsed = await ExportHelper.importFromCsv(
                pickedPath,
                catProvider.categories,
                accProvider.accounts,
              );

              if (parsed.transactions.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No valid rows found (${parsed.skipped} skipped)')),
                  );
                }
                return;
              }

              if (!context.mounted) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Import Transactions?'),
                  content: Text(
                    '${parsed.transactions.length} of ${parsed.total} rows will be imported.'
                    '${parsed.skipped > 0 ? ' ${parsed.skipped} skipped (unknown category/account or bad format).' : ''}',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('IMPORT')),
                  ],
                ),
              );

              if (confirmed == true) {
                final count = await txProvider.importTransactions(parsed.transactions);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported $count transactions')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to import: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          title: const Text('Clear All Transactions', style: TextStyle(color: Colors.red)),
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear All Transactions?'),
                content: const Text('This will delete all transaction history across all accounts. This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text('CANCEL')
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final txProvider = context.read<TransactionProvider>();
                      await txProvider.clearAllTransactions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All transactions cleared')),
                        );
                      }
                    },
                    child: const Text('CLEAR ALL'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showSetPinDialog(BuildContext context, AuthProvider provider) {
    final pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set PIN'),
          content: TextField(
            controller: pinController,
            decoration: const InputDecoration(labelText: 'Enter 4-digit PIN'),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('CANCEL')
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.length == 4) {
                  provider.enablePin(pin);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be exactly 4 digits')),
                  );
                }
              },
              child: const Text('SET PIN'),
            ),
          ],
        );
      },
    );
  }
}
