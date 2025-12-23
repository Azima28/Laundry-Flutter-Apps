import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

const MethodChannel _platform = MethodChannel('com.azima/printer');

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceAddressController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _businessPhoneController = TextEditingController();
  final TextEditingController _receiptWidthController = TextEditingController();
  bool _autoConnect = false;
  // scanning functionality removed (plugin not installed). Use manual address entry.

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _businessNameController.text = prefs.getString('business_name') ?? 'Laundry App';
      _businessAddressController.text = prefs.getString('business_address') ?? '';
      _businessPhoneController.text = prefs.getString('business_phone') ?? '';
      _deviceNameController.text = prefs.getString('printer_bt_name') ?? '';
      _deviceAddressController.text = prefs.getString('printer_bt_address') ?? '';
      _receiptWidthController.text = (prefs.getInt('printer_receipt_width_mm') ?? 58).toString();
      _autoConnect = prefs.getBool('printer_auto_connect') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_name', _businessNameController.text);
    await prefs.setString('business_address', _businessAddressController.text);
    await prefs.setString('business_phone', _businessPhoneController.text);
    await prefs.setString('printer_bt_name', _deviceNameController.text);
    await prefs.setString('printer_bt_address', _deviceAddressController.text);
    final width = int.tryParse(_receiptWidthController.text) ?? 58;
    await prefs.setInt('printer_receipt_width_mm', width);
    await prefs.setBool('printer_auto_connect', _autoConnect);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer settings saved')),
    );
  }
  Future<void> _testPrint() async {
    final address = _deviceAddressController.text.trim();
    final width = int.tryParse(_receiptWidthController.text.trim()) ?? 58;

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth address belum diisi')),
      );
      return;
    }

    if (!_validateReceiptWidth(_receiptWidthController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt width harus angka antara 40-120')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Print'),
        content: Text('Kirim test print ke printer $address ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Batal')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Print')),
        ],
      ),
    );
    if (confirm != true) return;

    // Fire the print request asynchronously so UI isn't blocked. Show immediate feedback.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mencetak...')));
    _platform.invokeMethod('printTest', {
      'address': address,
      'width': width,
      'businessName': _businessNameController.text,
      'businessAddress': _businessAddressController.text,
      'businessPhone': _businessPhoneController.text,
    }).then((res) {
      if (res == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test print berhasil')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test print selesai dengan status: $res')));
      }
    }).onError((error, stack) {
      if (error is MissingPluginException) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Native plugin belum tersedia — restart app setelah rebuild.')));
      } else if (error is PlatformException) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal print: ${error.message}')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal print: ${error.toString()}')));
      }
      return null;
    });
  }

  Future<void> _enterBtAddressManually() async {
    final controller = TextEditingController(text: _deviceAddressController.text);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Bluetooth Address'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'e.g. 00:11:22:33:44:55'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Save')),
        ],
      ),
    );
    if (result != null) {
      setState(() => _deviceAddressController.text = result);
    }
  }

  Future<void> _showPairedDevicesDialog() async {
    try {
      final List<dynamic> devices = await _platform.invokeMethod('getBondedDevices');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Paired Bluetooth Devices'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: devices.isEmpty
                ? Center(child: Text('No paired devices found'))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final d = devices[index] as Map<dynamic, dynamic>;
                      final name = d['name'] ?? '';
                      final address = d['address'] ?? '';
                      return ListTile(
                        title: Text(name.toString()),
                        subtitle: Text(address.toString()),
                        onTap: () {
                          setState(() {
                            _deviceNameController.text = name.toString();
                            _deviceAddressController.text = address.toString();
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
        ),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error retrieving paired devices: ${e.message}')),
      );
    }
  }

  bool _validateMac(String mac) {
    final reg = RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$');
    return reg.hasMatch(mac);
  }

  bool _validateReceiptWidth(String v) {
    final n = int.tryParse(v);
    if (n == null) return false;
    return n >= 40 && n <= 120; // reasonable bounds
  }

  // scanning functionality removed (plugin not installed). Use manual address entry.

  @override
  void dispose() {
    _deviceNameController.dispose();
    _deviceAddressController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _receiptWidthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings (Bluetooth)'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _deviceNameController,
              decoration: InputDecoration(
                labelText: 'Device Name (Bluetooth)',
                prefixIcon: Icon(Icons.bluetooth),
                hintText: 'Optional friendly name',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _businessNameController,
              decoration: InputDecoration(
                labelText: 'Business Name',
                prefixIcon: Icon(Icons.store),
                hintText: 'Laundry App',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _businessAddressController,
              decoration: InputDecoration(
                labelText: 'Business Address',
                prefixIcon: Icon(Icons.location_on),
                hintText: 'Street, City',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _businessPhoneController,
              decoration: InputDecoration(
                labelText: 'Business Phone',
                prefixIcon: Icon(Icons.phone),
                hintText: '+62 812 3456 7890',
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _deviceAddressController,
              decoration: InputDecoration(
                labelText: 'Bluetooth Address (MAC)',
                prefixIcon: Icon(Icons.link),
                hintText: 'e.g. 00:11:22:33:44:55',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: _showPairedDevicesDialog,
                      tooltip: 'Search paired devices',
                    ),
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: _enterBtAddressManually,
                      tooltip: 'Enter address manually',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _receiptWidthController,
              decoration: InputDecoration(
                labelText: 'Receipt Width (mm)',
                prefixIcon: Icon(Icons.straighten),
                hintText: 'Common: 58 or 80',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text('Auto connect on startup'),
              value: _autoConnect,
              onChanged: (v) => setState(() => _autoConnect = v),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    onPressed: () {
                      final mac = _deviceAddressController.text.trim();
                      final width = _receiptWidthController.text.trim();
                      if (mac.isNotEmpty && !_validateMac(mac)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Format MAC tidak valid')),
                        );
                        return;
                      }
                      if (!_validateReceiptWidth(width)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Receipt width harus angka antara 40-120')),
                        );
                        return;
                      }
                      _saveSettings();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.print),
                    label: Text('Test Print'),
                    onPressed: _testPrint,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Note: Bluetooth scanning/connection requires adding a platform plugin (example: flutter_bluetooth_serial or blue_thermal_printer) and runtime permissions. This screen only stores settings; integrate a Bluetooth plugin to scan/pair/connect.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
