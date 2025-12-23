import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  String _selectedProvider = 'midtrans';
  bool _isLoading = true;
  
  // Midtrans controllers
  late TextEditingController _midtransMerchantIdController;
  late TextEditingController _midtransClientKeyController;
  late TextEditingController _midtransServerKeyController;
  
  // Xendit controllers
  late TextEditingController _xenditApiKeyController;
  late TextEditingController _xenditSecretKeyController;

  @override
  void initState() {
    super.initState();
    _midtransMerchantIdController = TextEditingController();
    _midtransClientKeyController = TextEditingController();
    _midtransServerKeyController = TextEditingController();
    _xenditApiKeyController = TextEditingController();
    _xenditSecretKeyController = TextEditingController();
    
    _loadSettings();
  }

  @override
  void dispose() {
    _midtransMerchantIdController.dispose();
    _midtransClientKeyController.dispose();
    _midtransServerKeyController.dispose();
    _xenditApiKeyController.dispose();
    _xenditSecretKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _selectedProvider = prefs.getString('payment_provider') ?? 'midtrans';
        _midtransMerchantIdController.text = prefs.getString('midtrans_merchant_id') ?? '';
        _midtransClientKeyController.text = prefs.getString('midtrans_client_key') ?? '';
        _midtransServerKeyController.text = prefs.getString('midtrans_server_key') ?? '';
        _xenditApiKeyController.text = prefs.getString('xendit_api_key') ?? '';
        _xenditSecretKeyController.text = prefs.getString('xendit_secret_key') ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('payment_provider', _selectedProvider);
      await prefs.setString('midtrans_merchant_id', _midtransMerchantIdController.text);
      await prefs.setString('midtrans_client_key', _midtransClientKeyController.text);
      await prefs.setString('midtrans_server_key', _midtransServerKeyController.text);
      await prefs.setString('xendit_api_key', _xenditApiKeyController.text);
      await prefs.setString('xendit_secret_key', _xenditSecretKeyController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment Settings'),
          backgroundColor: Colors.indigo,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Settings'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Payment Provider',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            Card(
              elevation: 2,
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Midtrans'),
                    subtitle: const Text('QRIS, Card, Bank Transfer, E-wallet'),
                    value: 'midtrans',
                    groupValue: _selectedProvider,
                    onChanged: (value) {
                      setState(() {
                        _selectedProvider = value!;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('Xendit'),
                    subtitle: const Text('Invoice, Card, Virtual Account'),
                    value: 'xendit',
                    groupValue: _selectedProvider,
                    onChanged: (value) {
                      setState(() {
                        _selectedProvider = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (_selectedProvider == 'midtrans') ...[
              Text(
                'Midtrans Credentials',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _midtransMerchantIdController,
                        decoration: InputDecoration(
                          labelText: 'Merchant ID',
                          hintText: 'e.g., G776779987',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _midtransClientKeyController,
                        decoration: InputDecoration(
                          labelText: 'Client Key',
                          hintText: 'e.g., Mid-client-...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _midtransServerKeyController,
                        decoration: InputDecoration(
                          labelText: 'Server Key',
                          hintText: 'e.g., Mid-server-...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                        obscureText: true,
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Get your keys from Midtrans Dashboard:\nSettings > Access Keys',
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (_selectedProvider == 'xendit') ...[
              Text(
                'Xendit Credentials',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _xenditApiKeyController,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: 'e.g., xnd_...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _xenditSecretKeyController,
                        decoration: InputDecoration(
                          labelText: 'Secret Key',
                          hintText: 'e.g., xnd_...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                        obscureText: true,
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Get your keys from Xendit Dashboard:\nSettings > API Keys',
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save Settings', style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
