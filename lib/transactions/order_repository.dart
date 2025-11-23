import '../database/database_helper.dart';
import '../database/models/order_model.dart';

class OrderRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  
  Future<int?> getLatestOrderId() async {
    try {
      final orders = await _databaseHelper.getAllOrders();
      if (orders.isEmpty) return null;
      return orders.first.id;
    } catch (e) {
      print('Error getting latest order id: $e');
      return null;
    }
  }

  Future<int?> createOrder(String customerName, List<OrderItem> items, int totalAmount, int userId) async {
    try {
      final order = Order(
        customerName: customerName,
        orderDate: DateTime.now(),
        totalAmount: totalAmount,
        items: items,
        status: 'Pending', // Initial status
        userId: userId,
        isPaid: false, // Default payment status
      );
      
      final id = await _databaseHelper.insertOrder(order);
      return id > 0 ? id : null;
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  Future<List<Order>> getAllOrders({int? userId}) async {
    try {
      return await _databaseHelper.getAllOrders(userId: userId);
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  Future<Order?> getOrder(int id) async {
    try {
      return await _databaseHelper.getOrder(id);
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  Future<bool> updateOrderStatus(int id, String status) async {
    try {
      final rowsAffected = await _databaseHelper.updateOrderStatus(id, status);
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  Future<bool> updateOrderPaymentStatus(int id, bool isPaid) async {
    try {
      final rowsAffected = await _databaseHelper.updateOrderPaymentStatus(id, isPaid);
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating payment status: $e');
      return false;
    }
  }

  Future<bool> deleteOrder(int id) async {
    try {
      final rowsAffected = await _databaseHelper.deleteOrder(id);
      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting order: $e');
      return false;
    }
  }
}
