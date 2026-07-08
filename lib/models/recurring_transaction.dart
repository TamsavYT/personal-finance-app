class RecurringTransaction {
  final int? id;
  final String type; // 'income', 'expense'
  final double amount;
  final int categoryId;
  final int accountId;
  final String? note;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastProcessedDate;
  final bool isActive;

  const RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.note,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastProcessedDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'note': note,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'last_processed_date': lastProcessedDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int,
      note: map['note'] as String?,
      frequency: map['frequency'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      lastProcessedDate: map['last_processed_date'] != null
          ? DateTime.parse(map['last_processed_date'] as String)
          : null,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? type,
    double? amount,
    int? categoryId,
    int? accountId,
    String? note,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastProcessedDate,
    bool? isActive,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'RecurringTransaction(id: $id, type: $type, amount: $amount, frequency: $frequency, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurringTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
