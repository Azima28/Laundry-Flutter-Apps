import '../database/database_helper.dart';
import '../database/models/user_model.dart';

class UserRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<UserModel?> login(String username, String password) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'username = ? AND password = ? AND is_active = 1',
        whereArgs: [username, password],
      );

      if (maps.isEmpty) return null;
      return UserModel.fromMap(maps.first);
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
  }

  Future<bool> checkAdminExists() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
      );

      return maps.isNotEmpty;
    } catch (e) {
      print('Error checking admin: $e');
      return false;
    }
  }

  Future<bool> createAdmin(String username, String password) async {
    try {
      // Check if admin already exists
      final adminExists = await checkAdminExists();
      if (adminExists) {
        print('Admin already exists');
        return false;
      }

      final db = await _databaseHelper.database;
      
      // Create the admin user within a transaction
      await db.transaction((txn) async {
        final user = UserModel(
          username: username,
          password: password,
          role: 'admin',
        );
        
        final id = await txn.insert('users', user.toMap());
        if (id <= 0) throw Exception('Failed to create admin user');
      });
      
      return true;
    } catch (e) {
      print('Error creating admin: $e');
      return false;
    }
  }

  Future<bool> createUser(String username, String password) async {
    try {
      final user = UserModel(
        username: username,
        password: password,
        role: 'user',
      );
      
      final db = await _databaseHelper.database;
      final id = await db.insert('users', user.toMap());
      return id > 0;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('users');
      return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  Future<bool> changePassword(int userId, String newPassword) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.update(
        'users',
        {'password': newPassword},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  Future<UserModel?> getUserById(int userId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (maps.isEmpty) return null;
      return UserModel.fromMap(maps.first);
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
}
