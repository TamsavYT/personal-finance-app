class TransactionRecord {
  final int? id;
  final String type; // 'income', 'expense', 'transfer'
  final double amount;
  final int categoryId;
  final int accountId;
  final int? toAccountId; // for transfers
  final String? friendName; // for transfers to friend
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final bool isRecurring;
  final String? recurringType; // 'daily', 'weekly', 'monthly', 'yearly'
  final String? txnId; // UPI transaction ID (from PSP callback)
  final String? txnRef; // UPI transaction ref / approval ref number

  const TransactionRecord({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.friendName,
    this.note,
    required this.date,
    required this.createdAt,
    this.isRecurring = false,
    this.recurringType,
    this.txnId,
    this.txnRef,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'friend_name': friendName,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_type': recurringType,
      'txn_id': txnId,
      'txn_ref': txnRef,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int,
      toAccountId: map['to_account_id'] as int?,
      friendName: map['friend_name'] as String?,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      isRecurring: (map['is_recurring'] as int) == 1,
      recurringType: map['recurring_type'] as String?,
      txnId: map['txn_id'] as String?,
      txnRef: map['txn_ref'] as String?,
    );
  }

  TransactionRecord copyWith({
    int? id,
    String? type,
    double? amount,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String? friendName,
    String? note,
    DateTime? date,
    DateTime? createdAt,
    bool? isRecurring,
    String? recurringType,
    String? txnId,
    String? txnRef,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      friendName: friendName ?? this.friendName,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      txnId: txnId ?? this.txnId,
      txnRef: txnRef ?? this.txnRef,
    );
  }

  @override
  String toString() {
    return 'TransactionRecord(id: $id, type: $type, amount: $amount, date: $date, accountId: $accountId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionRecord && id != null && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
