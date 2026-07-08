class Account {
  final int? id;
  final String name;
  final String type; // 'cash', 'bank', 'upi', 'wallet', 'other'
  final String icon; // icon code point as string
  final String color; // hex color string
  final double initialBalance;
  final DateTime createdAt;
  final bool isActive;

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.initialBalance = 0.0,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'initial_balance': initialBalance,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      initialBalance: (map['initial_balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: (map['is_active'] as int) == 1,
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
    String? color,
    double? initialBalance,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: $type, initialBalance: $initialBalance, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
