import 'package:flutter/material.dart';
import '../transactions/transaction_repository.dart';
import '../database/models/transaction_model.dart';

class TambahItemScreen extends StatefulWidget {
  @override
  _TambahItemScreenState createState() => _TambahItemScreenState();
}

class _TambahItemScreenState extends State<TambahItemScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> _items = [];
  bool _isUnlimitedStock = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await _repository.getAllTransactions();
    setState(() {
      _items = items;
    });
  }

  Future<void> _tambahItem() async {
    final String nama = _namaController.text.trim();
    final String hargaText = _hargaController.text.trim();
    final String stockText = _stockController.text.trim();
    
    if (nama.isEmpty || hargaText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama dan harga harus diisi')),
      );
      return;
    }

    final int? harga = int.tryParse(hargaText);
    if (harga == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Harga harus berupa angka')),
      );
      return;
    }

    int? stock;
    if (!_isUnlimitedStock) {
      stock = int.tryParse(stockText);
      if (stock == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok harus berupa angka')),
        );
        return;
      }
    }

    final item = TransactionModel(
      nama: nama,
      harga: harga,
      stock: stock,
      isUnlimitedStock: _isUnlimitedStock,
      type: TransactionType.item,
      createdAt: DateTime.now(),
    );
    
    final success = await _repository.insertTransaction(item);
    
    if (success > 0) {
      _namaController.clear();
      _hargaController.clear();
      _stockController.clear();
      setState(() {
        _isUnlimitedStock = false;
      });
      _loadItems();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item berhasil ditambahkan')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan item')),
      );
    }
  }

  Future<void> _updateStock(TransactionModel item) async {
    TextEditingController stockUpdateController = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stok ${item.nama}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stok saat ini: ${item.isUnlimitedStock ? "Unlimited" : item.stock}'),
            SizedBox(height: 16),
            if (!item.isUnlimitedStock) TextField(
              controller: stockUpdateController,
              decoration: InputDecoration(
                labelText: 'Jumlah perubahan stok',
                hintText: '+5 untuk tambah, -3 untuk kurangi',
              ),
              keyboardType: TextInputType.numberWithOptions(signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Update'),
          ),
        ],
      ),
    );

    if (result == true && !item.isUnlimitedStock) {
      int? change = int.tryParse(stockUpdateController.text);
      if (change != null) {
        int newStock = (item.stock ?? 0) + change;
        if (newStock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok tidak boleh kurang dari 0')),
          );
          return;
        }
        
        final success = await _repository.updateTransaction(
          item.copyWith(stock: newStock),
        );
        
        if (success) {
          _loadItems();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok berhasil diupdate')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengupdate stok')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Item', style: TextStyle(color: Colors.white)), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _namaController,
              decoration: InputDecoration(
                labelText: 'Nama Item',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _hargaController,
              decoration: InputDecoration(
                labelText: 'Harga',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isUnlimitedStock,
                  onChanged: (value) {
                    setState(() {
                      _isUnlimitedStock = value ?? false;
                      if (_isUnlimitedStock) {
                        _stockController.clear();
                      }
                    });
                  },
                ),
                Text('Stok Unlimited'),
              ],
            ),
            if (!_isUnlimitedStock) ...[
              SizedBox(height: 16),
              TextField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Jumlah Stok',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            SizedBox(height: 16),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _tambahItem,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.indigo,
              ),
              child: Text('Tambah Item', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: ListView.builder(
                itemCount: _items.where((item) => item.type == TransactionType.item).length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: ListTile(
                      title: Text(item.nama),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Harga: Rp${item.harga}'),
                          Text(
                            'Stok: ${item.isUnlimitedStock ? "Unlimited" : (item.stock ?? 0)}',
                            style: TextStyle(
                              color: item.isUnlimitedStock || (item.stock ?? 0) > 0
                                ? Colors.green
                                : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!item.isUnlimitedStock)
                            IconButton(
                              icon: Icon(Icons.inventory, color: Colors.indigo),
                              onPressed: () => _updateStock(item),
                            ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Hapus Item'),
                                  content: Text('Apakah Anda yakin ingin menghapus "${item.nama}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Hapus', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                final success = await _repository.deleteTransaction(item.id!);
                                if (success) {
                                  setState(() {
                                    _items.remove(item);
                                  });
                                  _loadItems();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Item berhasil dihapus')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal menghapus item')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
