enum PaymentMethod {
  cash,
  qris
}

class PaymentStatus {
  final bool isPaid;
  final PaymentMethod method;
  final String? qrisUrl;
  final String? qrisId;
  final DateTime timestamp;

  PaymentStatus({
    this.isPaid = false,
    this.method = PaymentMethod.cash,
    this.qrisUrl,
    this.qrisId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_paid': isPaid ? 1 : 0,
      'method': method.index,
      'qris_url': qrisUrl,
      'qris_id': qrisId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PaymentStatus.fromMap(Map<String, dynamic> map) {
    return PaymentStatus(
      isPaid: map['is_paid'] == 1,
      method: PaymentMethod.values[map['method'] ?? 0],
      qrisUrl: map['qris_url'],
      qrisId: map['qris_id'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}