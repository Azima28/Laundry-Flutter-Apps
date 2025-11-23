import '../database/database_helper.dart';
import '../database/models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int?> getLatestTransactionId() async {
    try {
      final transactions = await getAllTransactions();
      if (transactions.isEmpty) return null;
      return transactions.first.id;
    } catch (e) {
      print('Error getting latest transaction id: $e');
      return null;
    }
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    try {
      return await _databaseHelper.insertTransaction(transaction);
    } catch (e) {
      print('Error inserting transaction: $e');
      return -1;
    }
  }

  Future<bool> addTransaction(
    String nama,
    int harga, {
    int? stock,
    bool isUnlimitedStock = false,
  }) async {
    try {
      final transaction = TransactionModel(
        nama: nama,
        harga: harga,
        stock: stock,
        isUnlimitedStock: isUnlimitedStock,
        type: TransactionType.item,
        createdAt: DateTime.now(),
      );
      
      final id = await _databaseHelper.insertTransaction(transaction);
      return id > 0;
    } catch (e) {
      print('Error adding transaction: $e');
      return false;
    }
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      return await _databaseHelper.getAllTransactions();
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  Future<TransactionModel?> getTransaction(int id) async {
    try {
      return await _databaseHelper.getTransaction(id);
    } catch (e) {
      print('Error getting transaction: $e');
      return null;
    }
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      final rowsAffected = await _databaseHelper.updateTransaction(transaction);
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final rowsAffected = await _databaseHelper.deleteTransaction(id);
      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  Future<bool> decreaseStock(int id, int quantity) async {
    try {
      final transaction = await getTransaction(id);
      if (transaction == null || transaction.isUnlimitedStock) {
        return true;
      }

      final currentStock = transaction.stock ?? 0;
      if (currentStock < quantity) {
        return false;
      }

      final updatedTransaction = transaction.copyWith(
        stock: currentStock - quantity,
      );

      return await updateTransaction(updatedTransaction);
    } catch (e) {
      print('Error decreasing stock: $e');
      return false;
    }
  }
}
