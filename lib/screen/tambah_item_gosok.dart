import 'package:flutter/material.dart';
import '../transactions/transaction_repository.dart';
import '../database/models/transaction_model.dart';

class TambahItemGosokScreen extends StatefulWidget {
  @override
  _TambahItemGosokScreenState createState() => _TambahItemGosokScreenState();
}

class _TambahItemGosokScreenState extends State<TambahItemGosokScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hargaPerKiloController = TextEditingController();
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaPerKiloController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await _repository.getAllTransactions();
    setState(() {
      _items = items.where((item) => item.type == TransactionType.iron).toList();
    });
  }

  Future<void> _tambahItem() async {
    final String nama = _namaController.text.trim();
    final String hargaText = _hargaPerKiloController.text.trim();
    
    if (nama.isEmpty || hargaText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama dan harga harus diisi')),
      );
      return;
    }

    final int? harga = int.tryParse(hargaText);
    if (harga == null || harga <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Harga tidak valid')),
      );
      return;
    }

    final transaction = TransactionModel(
      nama: nama,
      harga: harga,
      isUnlimitedStock: true, // Ironing service doesn't need stock
      type: TransactionType.iron,
      createdAt: DateTime.now(),
    );

    try {
      final success = await _repository.insertTransaction(transaction);
      if (success > 0) {
        _namaController.clear();
        _hargaPerKiloController.clear();
        _loadItems();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item berhasil ditambahkan')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan item')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Item Gosok'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tambah Item Gosok Baru',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: _namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama Item',
                        border: OutlineInputBorder(),
                        hintText: 'Contoh: Gosok Express',
                      ),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: _hargaPerKiloController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga per Kilo',
                        border: OutlineInputBorder(),
                        hintText: 'Contoh: 7000',
                        prefixText: 'Rp ',
                      ),
                    ),
                    SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _tambahItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: Text('Tambah Item'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(item.nama),
                      subtitle: Text('Rp ${item.harga}/kg'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          final success = await _repository.deleteTransaction(item.id!);
                          if (success) {
                            _loadItems();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Item berhasil dihapus')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
