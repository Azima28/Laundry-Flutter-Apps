import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class MidtransService {
  static const String _baseUrl = 'https://api.sandbox.midtrans.com/v2'; // Change to production URL for live
  static const String _serverKey = 'YOUR_SERVER_KEY'; // Replace with your Midtrans Server Key
  static const String _clientKey = 'YOUR_CLIENT_KEY'; // Replace with your Midtrans Client Key
  
  static String get serverKey => _serverKey;
  static String get clientKey => _clientKey;

  static Future<Map<String, dynamic>> createQRISTransaction({
    required String orderId,
    required int amount,
    required String customerName,
  }) async {
    try {
      final auth = base64Encode(utf8.encode('$_serverKey:'));
      final response = await http.post(
        Uri.parse('$_baseUrl/qris/create'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
        body: jsonEncode({
          'payment_type': 'qris',
          'transaction_details': {
            'order_id': orderId,
            'gross_amount': amount,
          },
          'customer_details': {
            'first_name': customerName,
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'qris_url': responseData['qr_string'],
          'qris_id': responseData['transaction_id'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create QRIS transaction: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating QRIS transaction: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
    try {
      final auth = base64Encode(utf8.encode('$_serverKey:'));
      final response = await http.get(
        Uri.parse('$_baseUrl/status/$orderId'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'transaction_status': responseData['transaction_status'],
          'status_code': responseData['status_code'],
          'settlement_time': responseData['settlement_time'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to check transaction status: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error checking transaction status: $e',
      };
    }
  }
}