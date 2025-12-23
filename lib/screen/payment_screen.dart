import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _paymentCompleted = false; // Flag to prevent duplicate dialog
  String? _qrisUrl;
  String? _qrisId;
  Timer? _statusCheckTimer;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // Debug fields
  String? _lastStatus;
  String? _lastResponse;
  String? _lastError;
  
  // Payment credentials from SharedPreferences
  String _midtransServerKey = '';
  String _paymentProvider = 'midtrans';

  @override
  void initState() {
    super.initState();
    _loadPaymentCredentials();
  }

  Future<void> _loadPaymentCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _paymentProvider = prefs.getString('payment_provider') ?? 'midtrans';
        _midtransServerKey = prefs.getString('midtrans_server_key') ?? '';
      });
      
      // Check if credentials are configured
      if (_midtransServerKey.isEmpty && _paymentProvider == 'midtrans') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment credentials not configured. Please configure in Settings > Payment Settings'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Configure',
                onPressed: () {
                  Navigator.pushNamed(context, '/payment_settings');
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading payment credentials: $e');
    }
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _lastError = null;
    });

    try {
      if (_selectedMethod == PaymentMethod.qris) {
        // Generate unique order ID dengan format yang lebih baik
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final orderId = 'ORDER-${widget.order.id ?? timestamp}-$timestamp';
        
        print('Creating QRIS for order: $orderId');
        
        // Create QRIS transaction
        final response = await MidtransService.createQRISTransaction(
          orderId: orderId,
          amount: widget.order.totalAmount.toDouble(),
          customerName: widget.order.customerName,
          overrideServerKey: _midtransServerKey,
        );

        // Save raw response for debugging
        _lastResponse = response.toString();
        print('Midtrans createQRIS response: $_lastResponse');

        // Check if successful
        if (response['success'] != true) {
          final message = response['message'] ?? 'Gagal membuat QRIS';
          setState(() {
            _lastError = message.toString();
            _isProcessing = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $message'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Get QR code URL or string
        final qrisData = response['qris_url'] ?? response['qr_code_url'];
        
        if (qrisData == null || qrisData.toString().isEmpty) {
          setState(() {
            _lastError = 'QR code URL tidak ditemukan dalam response';
            _isProcessing = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: QR code tidak tersedia'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _qrisUrl = qrisData.toString();
          _qrisId = orderId;
          _lastStatus = response['transaction_status'];
        });

        // Start checking payment status
        _startCheckingPaymentStatus(orderId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR Code berhasil dibuat. Silakan scan untuk membayar.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Cash payment - langsung complete
        _completePayment(true);
      }
    } catch (e) {
      print('Error in _processPayment: $e');
      setState(() {
        _lastError = e.toString();
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _startCheckingPaymentStatus(String orderId) {
    // Check immediately first
    _checkStatus(orderId);
    
    // Then check every 5 seconds
    _statusCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _checkStatus(orderId);
    });
  }

  Future<void> _checkStatus(String orderId) async {
    try {
      final status = await MidtransService.checkTransactionStatus(
        orderId, 
        overrideServerKey: _midtransServerKey,
      );
      
      setState(() {
        _lastResponse = status.toString();
        _lastStatus = status['transaction_status']?.toString();
      });
      
      print('Status check: $_lastResponse');

      // Check if payment is successful
      if (_lastStatus == 'settlement' || _lastStatus == 'capture') {
        _statusCheckTimer?.cancel();
        _completePayment(true);
      } else if (_lastStatus == 'deny' || _lastStatus == 'cancel' || _lastStatus == 'expire') {
        _statusCheckTimer?.cancel();
        setState(() {
          _lastError = 'Pembayaran gagal: $_lastStatus';
        });
      }
      
      // Handle API errors
      if (status['success'] == false) {
        setState(() {
          _lastError = status['message']?.toString();
        });
      }
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
      print('Error checking payment status: $e');
    }
  }

  Future<void> _completePayment(bool success) async {
    _statusCheckTimer?.cancel();
    
    // Prevent duplicate completion
    if (_paymentCompleted) {
      return;
    }
    _paymentCompleted = true;
    
    if (!success) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pembayaran dibatalkan')),
        );
        Navigator.of(context).pop(false);
      }
      return;
    }

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
        isPaid: true,
        paymentMethod: _selectedMethod == PaymentMethod.cash ? 'cash' : 'qris',
        qrisUrl: _qrisUrl,
        qrisId: _qrisId,
        paymentTimestamp: DateTime.now(),
      );

      // Update order in database
      await _dbHelper.updateOrder(updatedOrder);

      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        // Return true to indicate payment was successful
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment Details Card
            Card(
              elevation: 2,
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
                    Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Customer:', style: TextStyle(fontSize: 14)),
                        Text(
                          widget.order.customerName,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:', style: TextStyle(fontSize: 16)),
                        Text(
                          'Rp${widget.order.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 20,
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
            
            // Payment Method Selection
            Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            Card(
              elevation: 2,
              child: Column(
                children: [
                  RadioListTile<PaymentMethod>(
                    title: Row(
                      children: [
                        Icon(Icons.money, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Tunai'),
                      ],
                    ),
                    value: PaymentMethod.cash,
                    groupValue: _selectedMethod,
                    onChanged: _isProcessing ? null : (value) {
                      setState(() {
                        _selectedMethod = value!;
                      });
                    },
                  ),
                  Divider(height: 1),
                  RadioListTile<PaymentMethod>(
                    title: Row(
                      children: [
                        Icon(Icons.qr_code, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('QRIS'),
                      ],
                    ),
                    subtitle: Text('Bayar dengan scan QR', style: TextStyle(fontSize: 12)),
                    value: PaymentMethod.qris,
                    groupValue: _selectedMethod,
                    onChanged: _isProcessing ? null : (value) {
                      setState(() {
                        _selectedMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // QR Code Display
            if (_isProcessing && _selectedMethod == PaymentMethod.qris && _qrisUrl != null)
              Card(
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Scan QR untuk Membayar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // QR Code
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: QrImageView(
                          data: _qrisUrl!,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Status indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Menunggu pembayaran...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      if (_lastStatus != null) ...[
                        SizedBox(height: 8),
                        Text(
                          'Status: $_lastStatus',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      
                      SizedBox(height: 20),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (_qrisId != null) {
                                await _checkStatus(_qrisId!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Status: $_lastStatus')),
                                );
                              }
                            },
                            icon: Icon(Icons.refresh, size: 18),
                            label: Text('Cek Status'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _statusCheckTimer?.cancel();
                              _completePayment(false);
                            },
                            icon: Icon(Icons.close, size: 18),
                            label: Text('Batalkan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      
                      // Debug info (collapsible)
                      if (_lastError != null || _lastResponse != null) ...[
                        SizedBox(height: 16),
                        ExpansionTile(
                          title: Text(
                            'Debug Info',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_qrisId != null)
                                    Text('Order ID: $_qrisId', style: TextStyle(fontSize: 11)),
                                  if (_lastStatus != null)
                                    Text('Status: $_lastStatus', style: TextStyle(fontSize: 11)),
                                  if (_lastError != null)
                                    Text(
                                      'Error: $_lastError',
                                      style: TextStyle(fontSize: 11, color: Colors.red),
                                    ),
                                  if (_lastResponse != null) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      'Response: $_lastResponse',
                                      style: TextStyle(fontSize: 10),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 24),
            
            // Pay Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 56),
                backgroundColor: Colors.indigo,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Memproses...',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    )
                  : Text(
                      'Bayar Sekarang',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
            
            // Error message
            if (_lastError != null && !_isProcessing) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}