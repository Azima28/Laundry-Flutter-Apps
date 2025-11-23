enum TransactionType {
  item,
  coupon,
  iron
}

class TransactionModel {
  final int? id;
  final String nama;
  final int harga;
  final int? stock;
  final bool isUnlimitedStock;
  final TransactionType type;
  final int? parentId;
  final bool isUsed;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.nama,
    required this.harga,
    this.stock,
    this.isUnlimitedStock = false,
    this.type = TransactionType.item,
    this.parentId,
    this.isUsed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'harga': harga,
      'stock': stock,
      'is_unlimited_stock': isUnlimitedStock ? 1 : 0,
      'type': type.index,
      'parent_id': parentId,
      'is_used': isUsed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      nama: map['nama'],
      harga: map['harga'],
      stock: map['stock'],
      isUnlimitedStock: map['is_unlimited_stock'] == 1,
      type: TransactionType.values[map['type'] ?? 0],
      parentId: map['parent_id'],
      isUsed: map['is_used'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  TransactionModel copyWith({
    int? id,
    String? nama,
    int? harga,
    int? stock,
    bool? isUnlimitedStock,
    TransactionType? type,
    int? parentId,
    bool? isUsed,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      harga: harga ?? this.harga,
      stock: stock ?? this.stock,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      isUsed: isUsed ?? this.isUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
