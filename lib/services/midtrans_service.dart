import 'dart:convert';
import 'package:http/http.dart' as http;

class MidtransService {
  // Use sandbox for testing, production for live
  static const String _sandboxBaseUrl = 'https://api.sandbox.midtrans.com';
  static const String _productionBaseUrl = 'https://api.midtrans.com';
  
  // Set to true for testing, false for production
  static const bool _isSandbox = false;
  
  static String get _baseUrl => _isSandbox ? _sandboxBaseUrl : _productionBaseUrl;

  /// Create QRIS transaction using Core API v2
  /// Returns a map with qris_url or error information
  static Future<Map<String, dynamic>> createQRISTransaction({
    required String orderId,
    required double amount,
    required String customerName,
    String? overrideServerKey,
  }) async {
    try {
      final serverKey = overrideServerKey ?? '';
      
      if (serverKey.isEmpty) {
        return {
          'success': false,
          'message': 'Server key is empty',
        };
      }

      // Encode server key to base64 (serverKey:)
      final auth = base64Encode(utf8.encode('$serverKey:'));
      
      final url = Uri.parse('$_baseUrl/v2/charge');
      
      // Split customer name into first and last name
      final nameParts = customerName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : 'Customer';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final body = {
        'payment_type': 'qris',
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': amount.toInt(),
        },
        'customer_details': {
          'first_name': firstName,
          'last_name': lastName,
          'email': 'customer@example.com',
          'phone': '081234567890',
        },
        'qris': {
          'acquirer': 'gopay', // Can be 'gopay' or 'airpay shopee'
        },
      };

      print('Creating QRIS transaction...');
      print('URL: $url');
      print('Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
        body: jsonEncode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Extract QR code URL from actions array (prefer generate-qr-code-v2)
        String? qrCodeUrl;
        if (data['actions'] != null && data['actions'] is List) {
          for (var action in data['actions']) {
            if (action['name'] == 'generate-qr-code-v2') {
              qrCodeUrl = action['url'];
              break;
            }
          }
          // Fallback to generate-qr-code if v2 not found
          if (qrCodeUrl == null) {
            for (var action in data['actions']) {
              if (action['name'] == 'generate-qr-code') {
                qrCodeUrl = action['url'];
                break;
              }
            }
          }
        }

        // Use qr_string from response (it contains the actual QR code string)
        final qrisString = data['qr_string'];

        return {
          'success': true,
          'transaction_id': data['transaction_id'],
          'order_id': data['order_id'],
          'qris_url': qrisString ?? qrCodeUrl, // Use qr_string if available
          'qr_code_url': qrCodeUrl,
          'transaction_status': data['transaction_status'],
          'gross_amount': data['gross_amount'],
          'raw': data,
        };
      } else {
        // Handle error response
        final errorData = response.body.isNotEmpty 
            ? jsonDecode(response.body) 
            : {'status_message': 'Unknown error'};
        
        return {
          'success': false,
          'message': 'Failed to create QRIS: ${errorData['status_message'] ?? 'Unknown error'}',
          'statusCode': response.statusCode,
          'rawBody': response.body,
        };
      }
    } catch (e) {
      print('Exception in createQRISTransaction: $e');
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  /// Check transaction status
  static Future<Map<String, dynamic>> checkTransactionStatus(
    String orderId, {
    String? overrideServerKey,
  }) async {
    try {
      final serverKey = overrideServerKey ?? '';
      
      if (serverKey.isEmpty) {
        return {
          'success': false,
          'message': 'Server key is empty',
        };
      }

      final auth = base64Encode(utf8.encode('$serverKey:'));
      final url = Uri.parse('$_baseUrl/v2/$orderId/status');

      print('Checking transaction status for: $orderId');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );

      print('Status check response: ${response.statusCode}');
      print('Status check body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'transaction_status': data['transaction_status'],
          'order_id': data['order_id'],
          'transaction_id': data['transaction_id'],
          'gross_amount': data['gross_amount'],
          'payment_type': data['payment_type'],
          'transaction_time': data['transaction_time'],
          'fraud_status': data['fraud_status'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Transaction not found',
          'statusCode': response.statusCode,
        };
      } else {
        final errorData = response.body.isNotEmpty 
            ? jsonDecode(response.body) 
            : {'status_message': 'Unknown error'};
        
        return {
          'success': false,
          'message': errorData['status_message'] ?? 'Failed to check status',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Exception in checkTransactionStatus: $e');
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  /// Cancel transaction
  static Future<Map<String, dynamic>> cancelTransaction(
    String orderId, {
    String? overrideServerKey,
  }) async {
    try {
      final serverKey = overrideServerKey ?? '';
      
      if (serverKey.isEmpty) {
        return {
          'success': false,
          'message': 'Server key is empty',
        };
      }

      final auth = base64Encode(utf8.encode('$serverKey:'));
      final url = Uri.parse('$_baseUrl/v2/$orderId/cancel');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'transaction_status': data['transaction_status'],
          'order_id': data['order_id'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to cancel transaction',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }
}