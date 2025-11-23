class OrderItem {
  final int? id;
  final int itemId;
  final String itemName;
  final int quantity;
  final int price;
  final String? note;

  OrderItem({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'price': price,
      'note': note,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      itemId: map['item_id'],
      itemName: map['item_name'],
      quantity: map['quantity'],
      price: map['price'],
      note: map['note'],
    );
  }
}

class Order {
  final int? id;
  final String customerName;
  final DateTime orderDate;
  final int totalAmount;
  final List<OrderItem> items;
  final String status;
  final int userId;
  final bool isPaid;
  final String paymentMethod;
  final String? qrisUrl;
  final String? qrisId;
  final DateTime? paymentTimestamp;

  Order({
    this.id,
    required this.customerName,
    required this.orderDate,
    required this.totalAmount,
    required this.items,
    required this.status,
    required this.userId,
    this.isPaid = false,
    this.paymentMethod = 'cash',
    this.qrisUrl,
    this.qrisId,
    this.paymentTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'order_date': orderDate.toIso8601String(),
      'total_amount': totalAmount,
      'status': status,
      'user_id': userId,
      'is_paid': isPaid ? 1 : 0,
      'payment_method': paymentMethod,
      'qris_url': qrisUrl,
      'qris_id': qrisId,
      'payment_timestamp': paymentTimestamp?.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<OrderItem> orderItems) {
    return Order(
      id: map['id'],
      customerName: map['customer_name'],
      orderDate: DateTime.parse(map['order_date']),
      totalAmount: map['total_amount'],
      status: map['status'],
      items: orderItems,
      isPaid: map['is_paid'] == 1,
      userId: map['user_id'],
      paymentMethod: map['payment_method'] ?? 'cash',
      qrisUrl: map['qris_url'],
      qrisId: map['qris_id'],
      paymentTimestamp: map['payment_timestamp'] != null 
          ? DateTime.parse(map['payment_timestamp'])
          : null,
    );
  }
}
