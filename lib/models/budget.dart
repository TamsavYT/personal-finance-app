class Budget {
  final int? id;
  final int categoryId;
  final double limit;
  final int month; // 1-12
  final int year;

  const Budget({
    this.id,
    required this.categoryId,
    required this.limit,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'budget_limit': limit,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      limit: (map['budget_limit'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }

  Budget copyWith({
    int? id,
    int? categoryId,
    double? limit,
    int? month,
    int? year,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limit: limit ?? this.limit,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }

  @override
  String toString() {
    return 'Budget(id: $id, categoryId: $categoryId, limit: $limit, month: $month, year: $year)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget && id != null && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
