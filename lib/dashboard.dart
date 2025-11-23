  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  import '../database/models/user_model.dart';

  class DashboardPage extends StatelessWidget {
    final UserModel? user;
    const DashboardPage({Key? key, this.user}) : super(key: key);

    void _navigate(BuildContext context, String route) {
      Navigator.pushNamed(context, route);
    }

    Future<void> _logout(BuildContext context) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.blueGrey[50],
        appBar: AppBar(
          title: const Text('Kasir Laundry'),
          backgroundColor: Colors.indigo,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_laundry_service, size: 80, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Selamat Datang di Kasir Laundry',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.local_laundry_service),
                        label: const Text('Pesan Laundry', style: TextStyle(fontSize: 16)),
                        onPressed: () => _navigate(context, '/pesan'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.iron),
                        label: const Text('Pesan Gosok', style: TextStyle(fontSize: 16)),
                        onPressed: () => _navigate(context, '/pesan_gosok'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (user?.role == 'admin') // Hanya tampilkan jika user adalah admin
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_circle),
                              label: const Text('Tambah Item\nLaundry', 
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              onPressed: () => _navigate(context, '/tambah_item'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_circle),
                              label: const Text('Tambah Item\nGosok', 
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              onPressed: () => _navigate(context, '/tambah_item_gosok'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.local_laundry_service),
                        label: const Text('History\nLaundry', 
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () => _navigate(context, '/history'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.iron),
                        label: const Text('History\nGosok', 
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () => _navigate(context, '/history_gosok'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }