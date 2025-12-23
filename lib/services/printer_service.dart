import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/models/order_model.dart';

class PrinterService {
  static const MethodChannel _channel = MethodChannel('com.azima/printer');

  /// Prints an order using native printOrder method.
  /// Returns true on success.
  static Future<bool> printOrder(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('printer_bt_address') ?? '';
    final width = prefs.getInt('printer_receipt_width_mm') ?? 58;
    final businessName = prefs.getString('business_name') ?? 'Laundry App';
    final businessAddress = prefs.getString('business_address') ?? '';
    final businessPhone = prefs.getString('business_phone') ?? '';

    if (address.isEmpty) return Future.value(false);

    final orderMap = {
      'id': order.id,
      'customerName': order.customerName,
      'orderDate': order.orderDate.toIso8601String(),
      'totalAmount': order.totalAmount,
      'paymentMethod': order.paymentMethod,
      'items': order.items.map((it) => {
        'itemId': it.itemId,
        'itemName': it.itemName,
        'quantity': it.quantity,
        'price': it.price,
        'note': it.note,
      }).toList(),
    };

    try {
      final res = await _channel.invokeMethod('printOrder', {
        'address': address,
        'width': width,
        'businessName': businessName,
        'businessAddress': businessAddress,
        'businessPhone': businessPhone,
        'order': orderMap,
      });
      return res == true;
    } on PlatformException catch (e) {
      print('PrinterService: PlatformException: ${e.message}');
      return false;
    } catch (e) {
      print('PrinterService: Exception: $e');
      return false;
    }
  }
}
