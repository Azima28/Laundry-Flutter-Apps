import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'screen/pesan.dart';
import 'screen/tambah_item.dart';
import 'screen/tambah_item_gosok.dart';
import 'screen/pesan_gosok.dart';
import 'screen/history.dart';
import 'screen/history_gosok.dart';
import 'screen/login_screen.dart';
import 'screen/admin_dashboard.dart';
import 'screen/settings_screen.dart';
import 'screen/printer_settings_screen.dart';
import 'screen/payment_settings_screen.dart';
import 'screen/check_role.dart';
import 'database/database_helper.dart';
import 'transactions/user_repository.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database (do not delete existing data)
  await DatabaseHelper.instance.database;
  
  // Check login status
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getInt('user_id');
  
  runApp(MyApp(isLoggedIn: userId != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, this.isLoggedIn = false});

  Future<bool> _checkAdminAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return false;

    final userRepo = UserRepository();
    final user = await userRepo.getUserById(userId);
    return user?.role == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry App',
      initialRoute: isLoggedIn ? '/check_role' : '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/check_role': (context) => CheckRolePage(),
        '/dashboard': (context) => DashboardPage(),
        '/admin_dashboard': (context) => AdminDashboard(),
        '/pesan': (context) => PesanPage(),
        '/pesan_gosok': (context) => PesanGosokPage(),
        '/tambah_item': (context) => FutureBuilder(
          future: _checkAdminAccess(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.data == true) {
              return TambahItemScreen();
            }
            // Redirect to dashboard if not admin
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/dashboard');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Akses ditolak: Hanya untuk admin')),
              );
            });
            return Container();
          },
        ),
        '/tambah_item_gosok': (context) => FutureBuilder(
          future: _checkAdminAccess(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.data == true) {
              return TambahItemGosokScreen();
            }
            // Redirect to dashboard if not admin
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/dashboard');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Akses ditolak: Hanya untuk admin')),
              );
            });
            return Container();
          },
        ),
        '/history': (context) => HistoryPage(),
        '/history_gosok': (context) => HistoryGosokPage(),
        '/settings': (context) => SettingsScreen(),
        '/printer_settings': (context) => PrinterSettingsScreen(),
        '/payment_settings': (context) => PaymentSettingsScreen(),
      },
    );
  }
}