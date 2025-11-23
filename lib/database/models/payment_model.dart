enum PaymentMethod {
  cash,
  qris,
}

class PaymentStatus {
  final bool isPaid;
  final PaymentMethod method;
  final String? qrisUrl;
  final String? qrisId;
  final DateTime timestamp;

  PaymentStatus({
    required this.isPaid,
    required this.method,
    this.qrisUrl,
    this.qrisId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_paid': isPaid,
      'method': method.toString().split('.').last,
      'qris_url': qrisUrl,
      'qris_id': qrisId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PaymentStatus.fromMap(Map<String, dynamic> map) {
    return PaymentStatus(
      isPaid: map['is_paid'] ?? false,
      method: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == map['method'],
        orElse: () => PaymentMethod.cash,
      ),
      qrisUrl: map['qris_url'],
      qrisId: map['qris_id'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}