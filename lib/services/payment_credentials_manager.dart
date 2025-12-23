import 'package:shared_preferences/shared_preferences.dart';

class PaymentCredentialsManager {
  static const String _paymentProviderKey = 'payment_provider';
  static const String _midtransMerchantIdKey = 'midtrans_merchant_id';
  static const String _midtransClientKeyKey = 'midtrans_client_key';
  static const String _midtransServerKeyKey = 'midtrans_server_key';
  static const String _xenditApiKeyKey = 'xendit_api_key';
  static const String _xenditSecretKeyKey = 'xendit_secret_key';

  /// Load payment provider
  static Future<String> getPaymentProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_paymentProviderKey) ?? 'midtrans';
  }

  /// Load Midtrans credentials
  static Future<Map<String, String>> getMidtransCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'merchant_id': prefs.getString(_midtransMerchantIdKey) ?? '',
      'client_key': prefs.getString(_midtransClientKeyKey) ?? '',
      'server_key': prefs.getString(_midtransServerKeyKey) ?? '',
    };
  }

  /// Load Xendit credentials
  static Future<Map<String, String>> getXenditCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'api_key': prefs.getString(_xenditApiKeyKey) ?? '',
      'secret_key': prefs.getString(_xenditSecretKeyKey) ?? '',
    };
  }

  /// Get current server key based on selected provider
  static Future<String?> getActiveServerKey() async {
    final provider = await getPaymentProvider();
    
    if (provider == 'midtrans') {
      final creds = await getMidtransCredentials();
      return creds['server_key'];
    } else if (provider == 'xendit') {
      final creds = await getXenditCredentials();
      return creds['api_key'];
    }
    
    return null;
  }

  /// Check if payment credentials are configured
  static Future<bool> isConfigured() async {
    final provider = await getPaymentProvider();
    
    if (provider == 'midtrans') {
      final creds = await getMidtransCredentials();
      return (creds['server_key'] ?? '').isNotEmpty;
    } else if (provider == 'xendit') {
      final creds = await getXenditCredentials();
      return (creds['api_key'] ?? '').isNotEmpty;
    }
    
    return false;
  }
}
