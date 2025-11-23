import 'package:flutter/material.dart';
import '../database/models/transaction_model.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/order_repository.dart';
import '../database/models/order_model.dart';
import '../models/payment_model.dart';
import '../screen/payment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PesanPage extends StatefulWidget {
  @override
  _PesanPageState createState() => _PesanPageState();
}

class _PesanPageState extends State<PesanPage> {
  final TransactionRepository _repository = TransactionRepository();
  final OrderRepository _orderRepository = OrderRepository();
  List<TransactionModel> _items = [];
  Map<int, int> _quantities = {};
  Map<int, String> _notes = {};
  bool _isLoading = true;
  final TextEditingController _customerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });
    
    final items = await _repository.getAllTransactions();
    setState(() {
      // Only show laundry items (type == item)
      _items = items.where((item) => item.type == TransactionType.item).toList();
      // Initialize quantities to 0 for each item
      for (var item in _items) {
        _quantities[item.id ?? 0] = 0;
      }
      _isLoading = false;
    });
  }

  Future<void> _showNoteDialog(int itemId) async {
    final TextEditingController noteController = TextEditingController(text: _notes[itemId] ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah Catatan'),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: 'Masukkan catatan...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (noteController.text.trim().isEmpty) {
                  _notes.remove(itemId);
                } else {
                  _notes[itemId] = noteController.text.trim();
                }
              });
              Navigator.of(context).pop();
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(int? itemId, bool increment) async {
    if (itemId == null) return;
    
    if (increment) {
      // Check stock before incrementing
      final TransactionModel? item = _items.firstWhere((item) => item.id == itemId);
      if (item == null) return;

      if (!item.isUnlimitedStock && (item.stock ?? 0) <= (_quantities[itemId] ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok tidak mencukupi')),
        );
        return;
      }
    }

    setState(() {
      if (increment) {
        _quantities[itemId] = (_quantities[itemId] ?? 0) + 1;
      } else if ((_quantities[itemId] ?? 0) > 0) {
        _quantities[itemId] = (_quantities[itemId] ?? 0) - 1;
        if (_quantities[itemId] == 0) {
          _notes.remove(itemId); // Remove note when quantity becomes 0
        }
      }
    });
  }

  int _calculateTotal() {
    int total = 0;
    for (var item in _items) {
      total += (item.harga * (_quantities[item.id ?? 0] ?? 0));
    }
    return total;
  }

  int _calculateTotalItems() {
    return _quantities.values.fold(0, (sum, quantity) => sum + quantity);
  }

  Future<void> _submitOrder() async {
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mohon isi nama pemesan')),
      );
      return;
    }
    
    // Check stock availability for all items
    for (var item in _items) {
      final quantity = _quantities[item.id ?? 0] ?? 0;
      if (quantity > 0 && !item.isUnlimitedStock) {
        if ((item.stock ?? 0) < quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stok ${item.nama} tidak mencukupi (Tersedia: ${item.stock}, Diminta: $quantity)'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
    }

    final total = _calculateTotal();
    final items = _quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
          final item = _items.firstWhere((item) => item.id == entry.key);
          return OrderItem(
            itemId: entry.key,
            itemName: item.nama,
            quantity: entry.value,
            price: item.harga,
            note: _notes[entry.key],
          );
        })
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    // Create initial order
    final orderId = await _orderRepository.createOrder(
      _customerNameController.text.trim(),
      items,
      total,
      userId,
    );

    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pesanan')),
      );
      return;
    }

    // Get the created order
    final order = await _orderRepository.getOrder(orderId);
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan detail pesanan')),
      );
      return;
    }

    // Show payment screen
    final paymentSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          order: order,
        ),
      ),
    );

    if (paymentSuccess != true) {
      // Payment was cancelled or failed
      await _orderRepository.deleteOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pembayaran dibatalkan')),
        );
      }
      return;
    }

    // Update stocks for all items
    bool allStocksUpdated = true;
    for (var entry in _quantities.entries.where((e) => e.value > 0)) {
      final success = await _repository.decreaseStock(entry.key, entry.value);
      if (!success) {
        allStocksUpdated = false;
        break;
      }
    }

    if (!allStocksUpdated) {
      await _orderRepository.deleteOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui stok. Pesanan dibatalkan.')),
        );
      }
      return;
    }

    // Show success dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Order Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total pembayaran: Rp$total'),
              Text('Total item: ${items.length}'),
              Text('Status: Sudah Bayar'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to dashboard
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
    final totalItems = _calculateTotalItems();

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Nyuci'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Pemesan',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final quantity = _quantities[item.id ?? 0] ?? 0;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(item.nama),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Harga: Rp${item.harga}'),
                                  if (_notes[item.id]?.isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Catatan: ${_notes[item.id]}',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (quantity > 0)
                                    IconButton(
                                      icon: Icon(Icons.note_add),
                                      onPressed: () => _showNoteDialog(item.id ?? 0),
                                      tooltip: 'Tambah Catatan',
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: () => _updateQuantity(item.id, false),
                                  ),
                                  Text('$quantity'),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () => _updateQuantity(item.id, true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Items:',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            '$totalItems pcs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Harga:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Rp$total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: totalItems > 0 ? _submitOrder : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.indigo,
                        ),
                        child: Text(
                          'Pesan Sekarang',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}