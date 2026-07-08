/// Represents a single financial transaction (income, expense, or transfer).
class TransactionRecord {
  final int? id;
  final double amount;
  final String type; // 'income', 'expense', 'transfer'
  final int categoryId;
  final int accountId;
  final int? toAccountId; // only for transfers
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const TransactionRecord({
    this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int,
      toAccountId: map['to_account_id'] as int?,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  TransactionRecord copyWith({
    int? id,
    double? amount,
    String? type,
    int? categoryId,
    int? accountId,
    int? toAccountId,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TransactionRecord(id: $id, amount: $amount, type: $type, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
