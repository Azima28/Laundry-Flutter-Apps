import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../database/models/transaction_model.dart';
import '../database/models/order_model.dart';
import '../database/models/user_model.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 9; // Increment version for payment columns

  DatabaseHelper._init();

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'laundry.db');
    await databaseFactory.deleteDatabase(path);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('laundry.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        harga INTEGER NOT NULL,
        stock INTEGER,
        is_unlimited_stock INTEGER NOT NULL DEFAULT 0,
        type INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        is_used INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES transactions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        order_date TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        status TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        qris_url TEXT,
        qris_id TEXT,
        payment_timestamp TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price INTEGER NOT NULL,
        note TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (item_id) REFERENCES transactions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Order-related methods
  Future<int> insertOrder(Order order) async {
    final db = await database;
    int orderId = 0;
    
    await db.transaction((txn) async {
      // Insert the order first
      orderId = await txn.insert('orders', {
        'customer_name': order.customerName,
        'order_date': order.orderDate.toIso8601String(),
        'total_amount': order.totalAmount,
        'status': order.status,
        'user_id': order.userId,
        'is_paid': order.isPaid ? 1 : 0,
        'payment_method': order.paymentMethod,
        'qris_url': order.qrisUrl,
        'qris_id': order.qrisId,
        'payment_timestamp': order.paymentTimestamp?.toIso8601String(),
      });

      // Then insert all order items
      for (var item in order.items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'item_id': item.itemId,
          'item_name': item.itemName,
          'quantity': item.quantity,
          'price': item.price,
          'note': item.note,
        });
      }
    });

    return orderId;
  }

  Future<List<Order>> getAllOrders({int? userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> orderMaps = await db.query(
      'orders',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'order_date DESC',
    );

    return Future.wait(orderMaps.map((orderMap) async {
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderMap['id']],
      );

      final items = itemMaps.map((item) => OrderItem.fromMap(item)).toList();
      return Order.fromMap(orderMap, items);
    }));
  }

  Future<Order?> getOrder(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> orderMaps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (orderMaps.isEmpty) return null;

    final List<Map<String, dynamic>> itemMaps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [id],
    );

    final items = itemMaps.map((item) => OrderItem.fromMap(item)).toList();
    return Order.fromMap(orderMaps.first, items);
  }

  Future<int> updateOrderStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateOrder(Order order) async {
    if (order.id == null) return 0;

    final db = await database;
    int result = 0;

    await db.transaction((txn) async {
      // Update the order
      result = await txn.update(
        'orders',
        {
          'customer_name': order.customerName,
          'order_date': order.orderDate.toIso8601String(),
          'total_amount': order.totalAmount,
          'status': order.status,
          'user_id': order.userId,
          'is_paid': order.isPaid ? 1 : 0,
          'payment_method': order.paymentMethod,
          'qris_url': order.qrisUrl,
          'qris_id': order.qrisId,
          'payment_timestamp': order.paymentTimestamp?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // Delete all existing order items
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      // Insert new order items
      for (var item in order.items) {
        await txn.insert('order_items', {
          'order_id': order.id,
          'item_id': item.itemId,
          'item_name': item.itemName,
          'quantity': item.quantity,
          'price': item.price,
          'note': item.note,
        });
      }
    });

    return result;
  }

  Future<int> updateOrderPaymentStatus(int id, bool isPaid) async {
    final db = await database;
    return await db.update(
      'orders',
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  Future<TransactionModel?> getTransaction(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteOrder(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete order items first (due to foreign key constraint)
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      // Then delete the order
      await txn.delete(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    return 1; // Return 1 to indicate success
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 9) {
      // Add payment-related columns to orders table if they don't exist
      try {
        await db.execute('''
          ALTER TABLE orders ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash'
        ''');
        await db.execute('''
          ALTER TABLE orders ADD COLUMN qris_url TEXT
        ''');
        await db.execute('''
          ALTER TABLE orders ADD COLUMN qris_id TEXT
        ''');
        await db.execute('''
          ALTER TABLE orders ADD COLUMN payment_timestamp TEXT
        ''');
      } catch (e) {
        print('Error upgrading database: $e');
      }
    }

    if (oldVersion < 8) {
      // Previous upgrade logic for version 8
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama TEXT NOT NULL,
          harga INTEGER NOT NULL,
          stock INTEGER,
          is_unlimited_stock INTEGER NOT NULL DEFAULT 0,
          type INTEGER NOT NULL DEFAULT 0,
          parent_id INTEGER,
          is_used INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (parent_id) REFERENCES transactions (id)
        )
      ''');
    }
  }

  // Check if item has enough stock
  Future<bool> checkStock(int itemId, int quantity) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (maps.isEmpty) return false;

    final item = TransactionModel.fromMap(maps.first);
    return item.isUnlimitedStock || (item.stock ?? 0) >= quantity;
  }

  // Update stock after order
  Future<bool> updateStockAfterOrder(int itemId, int quantity) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (maps.isEmpty) return false;

    final item = TransactionModel.fromMap(maps.first);
    if (item.isUnlimitedStock) return true;

    final newStock = (item.stock ?? 0) - quantity;
    if (newStock < 0) return false;

    final rowsAffected = await db.update(
      'transactions',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [itemId],
    );

    return rowsAffected > 0;
  }
}
