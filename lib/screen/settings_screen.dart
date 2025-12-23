import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Profile'),
            subtitle: Text('Edit profile and account details'),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            subtitle: Text('Manage notification preferences'),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Privacy & Security'),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            subtitle: Text('App version and licenses'),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.print),
            title: Text('Printer Settings'),
            subtitle: Text('Configure printer options'),
            onTap: () => Navigator.pushNamed(context, '/printer_settings'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.payment),
            title: Text('Payment Settings'),
            subtitle: Text('Configure payment options'),
            onTap: () => Navigator.pushNamed(context, '/payment_settings'),
          ),
          Divider(),
        ],
      ),
    );
  }
}
