import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../database/models/payment_model.dart';
import '../database/models/order_model.dart';
import '../database/database_helper.dart';
import '../services/midtrans_service.dart';

class PaymentScreen extends StatefulWidget {
  final Order order;

  const PaymentScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _isProcessing = false;
  String? _qrisUrl;
  String? _qrisId;
  Timer? _statusCheckTimer;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_selectedMethod == PaymentMethod.qris) {
        // Generate unique order ID (you might want to use your own order ID format)
        final orderId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Create QRIS transaction
        final response = await MidtransService.createQRISTransaction(
          orderId: widget.order.id?.toString() ?? orderId,
          amount: widget.order.totalAmount,
          customerName: widget.order.customerName,
        );

        setState(() {
          _qrisUrl = response['qris_url'];
          _qrisId = orderId;
        });

        // Start checking payment status
        _startCheckingPaymentStatus(orderId);
      } else {
        // Cash payment
        _completePayment(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing payment: $e')),
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _startCheckingPaymentStatus(String orderId) {
    _statusCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await MidtransService.checkTransactionStatus(orderId);
        if (status['transaction_status'] == 'settlement') {
          timer.cancel();
          _completePayment(true);
        }
      } catch (e) {
        print('Error checking payment status: $e');
      }
    });
  }

  Future<void> _completePayment(bool success) async {
    _statusCheckTimer?.cancel();
    setState(() {
      _isProcessing = false;
    });

    try {
      // Create updated order with payment information
      final updatedOrder = Order(
        id: widget.order.id,
        customerName: widget.order.customerName,
        orderDate: widget.order.orderDate,
        totalAmount: widget.order.totalAmount,
        items: widget.order.items,
        status: widget.order.status,
        userId: widget.order.userId,
        isPaid: success,
        paymentMethod: _selectedMethod == PaymentMethod.cash ? 'cash' : 'qris',
        qrisUrl: _qrisUrl,
        qrisId: _qrisId,
        paymentTimestamp: DateTime.now(),
      );

      // Update order in database
      await _dbHelper.updateOrder(updatedOrder);

      if (mounted) {
        // Show success dialog and return to previous screen
        _showPaymentCompleteDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment status: $e')),
        );
      }
    }
  }

  void _showPaymentCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pembayaran Berhasil'),
        content: const Text('Pembayaran telah berhasil diproses.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to previous screen with success result
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:'),
                        Text(
                          'Rp${widget.order.totalAmount}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  RadioListTile<PaymentMethod>(
                    title: Text('Tunai'),
                    value: PaymentMethod.cash,
                    groupValue: _selectedMethod,
                    onChanged: _isProcessing ? null : (PaymentMethod? value) {
                      setState(() {
                        _selectedMethod = value!;
                      });
                    },
                  ),
                  RadioListTile<PaymentMethod>(
                    title: Text('QRIS'),
                    value: PaymentMethod.qris,
                    groupValue: _selectedMethod,
                    onChanged: _isProcessing ? null : (PaymentMethod? value) {
                      setState(() {
                        _selectedMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            if (_isProcessing && _selectedMethod == PaymentMethod.qris && _qrisUrl != null)
              Column(
                children: [
                  Text(
                    'Scan QRIS untuk Membayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    alignment: Alignment.center,
                    child: QrImageView(
                      data: _qrisUrl!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Menunggu pembayaran...',
                    style: TextStyle(color: Colors.orange),
                  ),
                  SizedBox(height: 8),
                  CircularProgressIndicator(),
                ],
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.indigo,
              ),
              child: Text(
                _isProcessing ? 'Memproses...' : 'Bayar Sekarang',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}