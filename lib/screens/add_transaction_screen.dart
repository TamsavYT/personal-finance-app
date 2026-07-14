import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../utils/icon_helper.dart';
import '../utils/color_helper.dart';
import '../utils/date_formatter.dart';
import '../utils/upi_payment_service.dart';
import '../models/upi_payment_result.dart';
import '../models/upi_qr_prefill.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _type = 'expense';
  DateTime _date = DateTime.now();
  int? _selectedCategoryId;
  int? _selectedAccountId;
  int? _selectedToAccountId;
  
  bool _isTransferToFriend = false;
  final _friendNameController = TextEditingController();
  
  bool _isRecurring = false;
  String _recurringType = 'monthly';

  bool _isPayingViaUpi = false;
  String? _qrVpa;
  String? _qrPayeeName;

  TransactionRecord? _editingTransaction;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is TransactionRecord) {
        _editingTransaction = args;
        _type = _editingTransaction!.type;
        _amountController.text = _editingTransaction!.amount.toString();
        _selectedCategoryId = _editingTransaction!.categoryId;
        _selectedAccountId = _editingTransaction!.accountId;
        _selectedToAccountId = _editingTransaction!.toAccountId;
        if (_editingTransaction!.friendName != null && _editingTransaction!.friendName!.isNotEmpty) {
          _isTransferToFriend = true;
          _friendNameController.text = _editingTransaction!.friendName!;
        }
        _noteController.text = _editingTransaction!.note ?? '';
        _date = _editingTransaction!.date;
        _isRecurring = _editingTransaction!.isRecurring;
        _recurringType = _editingTransaction!.recurringType ?? 'monthly';
      } else if (args != null && args is UpiQrPrefill) {
        final accProvider = context.read<AccountProvider>();
        final catProvider = context.read<CategoryProvider>();

        _type = 'expense';
        _qrVpa = args.vpa;
        _qrPayeeName = args.payeeName;
        if (args.amount != null) _amountController.text = args.amount!.toStringAsFixed(2);
        if (args.note != null) _noteController.text = args.note!;

        // Prefer a UPI-type account so the Pay button shows right away; fall
        // back to whatever account exists so the user can still save it as a
        // plain manual expense if they have none.
        final upiAccounts = accProvider.accounts.where((a) => a.type == 'upi').toList();
        if (upiAccounts.isNotEmpty) {
          _selectedAccountId = upiAccounts.first.id;
        } else if (accProvider.accounts.isNotEmpty) {
          _selectedAccountId = accProvider.accounts.first.id;
        }
        if (catProvider.expenseCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.expenseCategories.first.id;
        }
      } else {
        // Set defaults if accounts/categories exist
        final accProvider = context.read<AccountProvider>();
        final catProvider = context.read<CategoryProvider>();

        if (accProvider.accounts.isNotEmpty) {
          _selectedAccountId = accProvider.accounts.first.id;
        }
        if (catProvider.expenseCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.expenseCategories.first.id;
        }
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _friendNameController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final catProvider = context.read<CategoryProvider>();
    int? finalCategoryId = _selectedCategoryId;
    if (_type == 'transfer') {
      try {
        final transferCat = catProvider.categories.firstWhere((c) => c.type == 'transfer');
        finalCategoryId = transferCat.id;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer category not found. Restart app.')));
        return;
      }
    } else if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }

    if (_type == 'transfer') {
      if (_isTransferToFriend) {
        if (_friendNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter friend name')));
          return;
        }
      } else if (_selectedToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination account')));
        return;
      }
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than 0')));
      return;
    }

    final tx = TransactionRecord(
      id: _editingTransaction?.id,
      type: _type,
      amount: amount,
      categoryId: finalCategoryId!,
      accountId: _selectedAccountId!,
      toAccountId: _type == 'transfer' && !_isTransferToFriend ? _selectedToAccountId : null,
      friendName: _type == 'transfer' && _isTransferToFriend ? _friendNameController.text.trim() : null,
      note: _noteController.text.trim(),
      date: _date,
      createdAt: _editingTransaction?.createdAt ?? DateTime.now(),
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? _recurringType : null,
    );

    final txProvider = context.read<TransactionProvider>();
    if (_editingTransaction != null) {
      txProvider.updateTransaction(tx);
    } else {
      txProvider.addTransaction(tx);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingTransaction != null ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildAmountInput(),
              const SizedBox(height: 24),
              if (_type != 'transfer') _buildCategorySelector(),
              if (_type != 'transfer') const SizedBox(height: 24),
              _buildAccountSelector(),
              _buildUpiPayButton(),
              const SizedBox(height: 24),
              _buildDateSelector(),
              const SizedBox(height: 24),
              _buildNoteInput(),
              const SizedBox(height: 24),
              _buildRecurringToggle(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'income', label: Text('Income')),
        ButtonSegment(value: 'expense', label: Text('Expense')),
        ButtonSegment(value: 'transfer', label: Text('Transfer')),
      ],
      selected: {_type},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _type = newSelection.first;
          // Reset category if switching between income/expense
          if (_type == 'income') {
            final cats = context.read<CategoryProvider>().incomeCategories;
            _selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
          } else if (_type == 'expense') {
            final cats = context.read<CategoryProvider>().expenseCategories;
            _selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
          }
        });
      },
    );
  }

  Widget _buildAmountInput() {
    Color textColor = Colors.black;
    if (_type == 'income') textColor = Colors.green;
    if (_type == 'expense') textColor = Colors.red;
    if (_type == 'transfer') textColor = Colors.blue;

    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: textColor),
      decoration: InputDecoration(
        prefixText: '₹ ',
        prefixStyle: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: textColor),
        border: InputBorder.none,
        hintText: '0.00',
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Please enter amount';
        if (double.tryParse(val) == null) return 'Invalid amount';
        return null;
      },
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<CategoryProvider>(
      builder: (context, catProvider, child) {
        List<Category> categories = _type == 'income'
            ? catProvider.incomeCategories
            : catProvider.expenseCategories;

        if (categories.isEmpty) {
          return const Text('No categories available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategoryId == cat.id;
                final catColor = ColorHelper.hexToColor(cat.color);
                return ChoiceChip(
                  label: Text(cat.name),
                  selected: isSelected,
                  selectedColor: catColor.withValues(alpha: 0.2),
                  avatar: Icon(IconHelper.getIconFromCodePoint(int.parse(cat.icon)), size: 18, color: catColor),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategoryId = cat.id);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountSelector() {
    return Consumer<AccountProvider>(
      builder: (context, accProvider, child) {
        if (accProvider.accounts.isEmpty) {
          return const Text('No accounts available. Please add one first.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: accProvider.accounts.map((acc) {
                return DropdownMenuItem<int>(
                  value: acc.id,
                  child: Text(acc.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAccountId = val),
            ),
            if (_type == 'transfer') ...[
              const SizedBox(height: 16),
              const Text('Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              RadioGroup<bool>(
                groupValue: _isTransferToFriend,
                onChanged: (val) => setState(() => _isTransferToFriend = val!),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('To Account', style: TextStyle(fontSize: 14)),
                        value: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('To Friend', style: TextStyle(fontSize: 14)),
                        value: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_isTransferToFriend)
                TextFormField(
                  controller: _friendNameController,
                  decoration: const InputDecoration(
                    labelText: 'Friend Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (val) {
                    if (_type == 'transfer' && _isTransferToFriend && (val == null || val.trim().isEmpty)) {
                      return 'Please enter friend name';
                    }
                    return null;
                  },
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedToAccountId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: accProvider.accounts.map((acc) {
                    return DropdownMenuItem<int>(
                      value: acc.id,
                      child: Text(acc.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedToAccountId = val),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: const Text('Date'),
      trailing: Text(DateFormatter.formatDate(_date), style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() => _date = picked);
        }
      },
    );
  }

  Widget _buildNoteInput() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Note (Optional)',
        prefixIcon: Icon(Icons.notes),
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildRecurringToggle() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Make Recurring'),
          value: _isRecurring,
          onChanged: (val) => setState(() => _isRecurring = val),
        ),
        if (_isRecurring)
          DropdownButtonFormField<String>(
            initialValue: _recurringType,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: ['daily', 'weekly', 'monthly', 'yearly'].map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(toBeginningOfSentenceCase(type)!),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _recurringType = val);
              }
            },
          ),
      ],
    );
  }

  bool _selectedAccountIsUpi() {
    if (_selectedAccountId == null) return false;
    final accounts = context.read<AccountProvider>().accounts;
    for (final acc in accounts) {
      if (acc.id == _selectedAccountId) return acc.type == 'upi';
    }
    return false;
  }

  Widget _buildUpiPayButton() {
    // Only offered for expenses paid out of a UPI account - editing an
    // existing transaction never re-triggers a live payment.
    if (_type != 'expense' || _editingTransaction != null || !_selectedAccountIsUpi()) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_qrVpa != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Paying $_qrPayeeName ($_qrVpa)',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _isPayingViaUpi ? null : _payViaUpi,
            icon: _isPayingViaUpi
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_scanner),
            label: Text(_isPayingViaUpi ? 'Waiting for UPI app...' : 'Pay via UPI'),
          ),
        ],
      ),
    );
  }

  Future<({String vpa, String name})?> _askPayeeDetails() {
    final vpaController = TextEditingController();
    final nameController = TextEditingController();
    return showDialog<({String vpa, String name})>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Pay via UPI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vpaController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Payee VPA (e.g. name@bank)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Payee Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final vpa = vpaController.text.trim();
              final name = nameController.text.trim();
              if (vpa.isEmpty || !vpa.contains('@') || name.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid VPA and payee name')),
                );
                return;
              }
              Navigator.of(dialogCtx).pop((vpa: vpa, name: name));
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _payViaUpi() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount first')));
      return;
    }
    if (_selectedCategoryId == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category and account first')));
      return;
    }

    final payee = (_qrVpa != null && _qrPayeeName != null)
        ? (vpa: _qrVpa!, name: _qrPayeeName!)
        : await _askPayeeDetails();
    if (payee == null) return;

    setState(() => _isPayingViaUpi = true);
    try {
      // The UPI app handoff can take the app to the background for the
      // whole duration of this call - the loading state above must stay up
      // until it resolves, since the callback (or lack of one) only arrives
      // when the user returns to this app.
      final result = await UpiPaymentService.instance.payViaUpi(
        payeeVpa: payee.vpa,
        payeeName: payee.name,
        amount: amount,
        note: _noteController.text.trim(),
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
      );

      if (!mounted) return;

      switch (result.status) {
        case UpiPaymentStatus.success:
          // Already written to the DB inside the service - just refresh and
          // leave. Calling txProvider.addTransaction here would double-log it.
          await context.read<TransactionProvider>().loadTransactions();
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Payment successful, logged.')));
          Navigator.of(context).pop();
          break;
        case UpiPaymentStatus.failure:
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Payment failed.')));
          break;
        case UpiPaymentStatus.cancelled:
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
          break;
        case UpiPaymentStatus.pending:
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              "Couldn't confirm the payment status. It'll be logged automatically "
              "once the ${payee.name} notification arrives - add it manually if it never does.",
            ),
            duration: const Duration(seconds: 6),
          ));
          break;
      }
    } on UpiAppNotFoundException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No UPI app found on this device.')));
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Payment could not be started: ${e.message ?? e.code}')));
    } finally {
      if (mounted) setState(() => _isPayingViaUpi = false);
    }
  }
}
