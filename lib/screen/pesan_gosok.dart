import 'package:flutter/material.dart';
import '../database/models/transaction_model.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/order_repository.dart';
import '../database/models/order_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PesanGosokPage extends StatefulWidget {
  @override
  _PesanGosokPageState createState() => _PesanGosokPageState();
}

class _PesanGosokPageState extends State<PesanGosokPage> {
  final TransactionRepository _repository = TransactionRepository();
  final OrderRepository _orderRepository = OrderRepository();
  List<TransactionModel> _items = [];
  Map<int, double> _weights = {};
  Map<int, String> _notes = {};
  bool _isLoading = true;
  final TextEditingController _customerNameController = TextEditingController();
  bool _isPaid = false;

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
      _items = items.where((item) => item.type == TransactionType.iron).toList();
      _isLoading = false;
    });
  }

  Future<void> _showNoteDialog(int itemId) async {
    final controller = TextEditingController(text: _notes[itemId] ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah Catatan'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Masukkan catatan...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notes[itemId] = controller.text;
              });
              Navigator.pop(context);
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateWeight(int itemId) async {
    final controller = TextEditingController(
      text: _weights[itemId]?.toString() ?? '',
    );
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Masukkan Berat'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Berat dalam kg',
            border: OutlineInputBorder(),
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                setState(() {
                  _weights[itemId] = weight;
                });
                Navigator.pop(context);
              }
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  int _calculateTotal() {
    return _items.fold(0, (total, item) {
      final weight = _weights[item.id] ?? 0;
      return total + (item.harga * weight).round();
    });
  }

  Future<void> _submitOrder() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama pelanggan harus diisi')),
      );
      return;
    }

    if (_weights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Belum ada item yang dipilih')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesi telah berakhir, silakan login kembali')),
      );
      return;
    }

    // Create order items
    final orderItems = _items
        .where((item) => _weights[item.id] != null && _weights[item.id]! > 0)
        .map((item) => OrderItem(
              itemId: item.id!,
              itemName: item.nama,
              quantity: 1,
              price: (item.harga * (_weights[item.id] ?? 0)).round(),
              note: '${_weights[item.id]} kg${_notes[item.id] != null ? ' - ${_notes[item.id]}' : ''}',
            ))
        .toList();

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada item yang dipilih')),
      );
      return;
    }

    final totalAmount = _calculateTotal();
    final orderId = await _orderRepository.createOrder(
      _customerNameController.text,
      orderItems,
      totalAmount,
      userId,
    );

    if (orderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan berhasil dibuat')),
      );
      _customerNameController.clear();
      setState(() {
        _weights.clear();
        _notes.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat pesanan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pesan Gosok'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final weight = _weights[item.id] ?? 0;
                      final hasNote = _notes[item.id]?.isNotEmpty ?? false;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          title: Text(item.nama),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rp ${item.harga}/kg'),
                              if (weight > 0)
                                Text(
                                  'Total: Rp ${(item.harga * weight).round()} (${weight}kg)',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              if (hasNote)
                                Text(
                                  'Catatan: ${_notes[item.id]}',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_note),
                                onPressed: () => _showNoteDialog(item.id!),
                              ),
                              TextButton(
                                onPressed: () => _updateWeight(item.id!),
                                child: Text(
                                  weight > 0 ? '${weight}kg' : 'Set Berat',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Rp${_calculateTotal()}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _weights.isNotEmpty ? _submitOrder : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          'Proses Pesanan',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Status Pembayaran:'),
                          SizedBox(width: 8),
                          Switch(
                            value: _isPaid,
                            onChanged: (value) {
                              setState(() {
                                _isPaid = value;
                              });
                            },
                          ),
                          Text(_isPaid ? 'Lunas' : 'Belum Lunas'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
