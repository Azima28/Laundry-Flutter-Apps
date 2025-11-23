import 'package:flutter/material.dart';
import '../transactions/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckRolePage extends StatefulWidget {
  @override
  _CheckRolePageState createState() => _CheckRolePageState();
}

class _CheckRolePageState extends State<CheckRolePage> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final userRepository = UserRepository();
    final user = await userRepository.getUserById(userId);
    
    if (user == null) {
      // User not found or deleted
      await prefs.remove('user_id');
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    // Navigate based on user role
    if (user.role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
