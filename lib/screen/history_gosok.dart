import 'package:flutter/material.dart';
import '../database/models/order_model.dart';
import '../transactions/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryGosokPage extends StatefulWidget {
  @override
  _HistoryGosokPageState createState() => _HistoryGosokPageState();
}

class _HistoryGosokPageState extends State<HistoryGosokPage> {
  final OrderRepository _repository = OrderRepository();
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showOnlyToday = true;
  final TextEditingController _searchController = TextEditingController();
  
  // For statistics
  int _totalRevenue = 0;
  Map<String, double> _totalWeight = {};
  Map<String, int> _itemRevenues = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _calculateStatistics() {
    _totalRevenue = 0;
    _totalWeight.clear();
    _itemRevenues.clear();

    for (var order in _filteredOrders) {
      _totalRevenue += order.totalAmount;
      for (var item in order.items) {
        // Extract weight from note (format: "2.5 kg - Additional note")
        String weightStr = item.note?.split(' ').first ?? '0';
        double weight = double.tryParse(weightStr) ?? 0;
        
        _totalWeight[item.itemName] = (_totalWeight[item.itemName] ?? 0) + weight;
        _itemRevenues[item.itemName] = (_itemRevenues[item.itemName] ?? 0) + item.price;
      }
    }
  }

  void _filterOrders() {
    setState(() {
      // Start with all orders
      var filtered = _orders;

      // Apply date filter
      if (_showOnlyToday) {
        final today = DateTime.now();
        filtered = filtered.where((order) => 
          order.orderDate.year == today.year &&
          order.orderDate.month == today.month &&
          order.orderDate.day == today.day
        ).toList();
      } else if (_startDate != null && _endDate != null) {
        filtered = filtered.where((order) =>
          order.orderDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
          order.orderDate.isBefore(_endDate!.add(Duration(days: 1)))
        ).toList();
      }

      // Apply search filter if any
      if (_searchController.text.isNotEmpty) {
        String query = _searchController.text.toLowerCase();
        filtered = filtered.where((order) =>
          order.customerName.toLowerCase().contains(query) ||
          order.items.any((item) => item.itemName.toLowerCase().contains(query))
        ).toList();
      }

      // Sort by date, newest first
      filtered.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      
      _filteredOrders = filtered;
      _calculateStatistics();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    try {
      final now = DateTime.now();
      final lastMonth = now.subtract(Duration(days: 30));
      
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: _startDate ?? lastMonth,
          end: _endDate ?? now,
        ),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Colors.indigo,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _startDate = DateTime(
            picked.start.year, 
            picked.start.month, 
            picked.start.day,
            0, 0, 0
          );
          _endDate = DateTime(
            picked.end.year, 
            picked.end.month, 
            picked.end.day, 
            23, 59, 59
          );
          _showOnlyToday = false;
        });
        
        // Ensure we have the correct date range before filtering
        print('Date Range Selected: ${_startDate!.toIso8601String()} to ${_endDate!.toIso8601String()}');
        await _loadOrders();
      }
    } catch (e) {
      print('Error selecting date range: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih tanggal. Silakan coba lagi.')),
      );
    }
  }

  void _toggleTodayFilter() {
    setState(() {
      _showOnlyToday = !_showOnlyToday;
      if (_showOnlyToday) {
        _startDate = null;
        _endDate = null;
      }
    });
    _loadOrders(); // Reload the orders with the new filter
  }

  Future<void> _updatePaymentStatus(Order order) async {
    final success = await _repository.updateOrderPaymentStatus(order.id!, !order.isPaid);
    if (success) {
      _loadOrders();
    }
  }

  Future<void> _updateOrderStatus(Order order) async {
    // Toggle between 'pending' and 'completed'
    final String newStatus = order.status == 'completed' ? 'pending' : 'completed';
    final success = await _repository.updateOrderStatus(order.id!, newStatus);
    if (success) {
      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status pesanan berhasil diperbarui')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status pesanan')),
      );
    }
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId == null) {
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      // Get all orders
      final orders = await _repository.getAllOrders(userId: userId);
      
      // First filter for ironing orders (has kg in notes)
      var filteredOrders = orders.where((order) => 
        order.items.any((item) => item.note?.toLowerCase().contains('kg') ?? false)
      ).toList();

      // Then apply date filters
      if (_showOnlyToday) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(Duration(days: 1));
        
        filteredOrders = filteredOrders.where((order) {
          return order.orderDate.isAfter(today.subtract(Duration(seconds: 1))) && 
                 order.orderDate.isBefore(tomorrow);
        }).toList();
      } else if (_startDate != null && _endDate != null) {
        filteredOrders = filteredOrders.where((order) {
          return order.orderDate.isAfter(_startDate!.subtract(Duration(seconds: 1))) && 
                 order.orderDate.isBefore(_endDate!.add(Duration(seconds: 1)));
        }).toList();
      }

      // Sort by date, newest first
      filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      setState(() {
        _orders = filteredOrders;
        _filteredOrders = filteredOrders;
        _isLoading = false;
      });

      _calculateStatistics();

      // Debug log
      print('Loaded ${filteredOrders.length} orders');
      if (_startDate != null && _endDate != null) {
        print('Date range: ${_startDate!.toIso8601String()} to ${_endDate!.toIso8601String()}');
      }
      
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: $e')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Pesanan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${order.customerName}'),
              Text('Tanggal: ${_formatDateTime(order.orderDate)}'),
              Divider(),
              ...order.items.map((item) {
                // Extract weight and note
                String weightStr = item.note?.split(' ').first ?? '0';
                String? additionalNote = item.note?.contains(' - ') ?? false
                    ? item.note?.split(' - ').last
                    : null;
                
                return ListTile(
                  title: Text(item.itemName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Berat: $weightStr kg'),
                      if (additionalNote != null)
                        Text('Catatan: $additionalNote'),
                      Text('Harga: Rp${item.price}'),
                    ],
                  ),
                );
              }),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Rp${order.totalAmount}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status Pembayaran:'),
                  Row(
                    children: [
                      Icon(
                        order.isPaid ? Icons.check_circle : Icons.pending,
                        color: order.isPaid ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        order.isPaid ? 'Lunas' : 'Belum Lunas',
                        style: TextStyle(
                          color: order.isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status Pengerjaan:'),
                  Row(
                    children: [
                      Icon(
                        order.status == 'completed' ? Icons.check_circle : Icons.pending,
                        color: order.status == 'completed' ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        order.status == 'completed' ? 'Selesai' : 'Dalam Proses',
                        style: TextStyle(
                          color: order.status == 'completed' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Statistik'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Pendapatan: Rp$_totalRevenue',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Divider(),
              Text('Total Berat per Item:'),
              ..._totalWeight.entries.map((e) => Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('${e.key}: ${e.value.toStringAsFixed(1)} kg'),
              )),
              Divider(),
              Text('Total Pendapatan per Item:'),
              ..._itemRevenues.entries.map((e) => Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('${e.key}: Rp${e.value}'),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Gosok'),
        backgroundColor: Colors.indigo,
        actions: [
          // Today filter button
          TextButton.icon(
            icon: Icon(
              _showOnlyToday ? Icons.today : Icons.date_range,
              color: Colors.white,
            ),
            label: Text(
              _showOnlyToday ? 'Hari Ini' : 'Semua',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: _toggleTodayFilter,
          ),
          // Date range picker button
          TextButton.icon(
            icon: Icon(Icons.calendar_month, color: Colors.white),
            label: Text(
              'Pilih Tanggal',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _showStatistics,
            tooltip: 'Tampilkan Statistik',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari nama pelanggan',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => _filterOrders(),
                  ),
                ),
                if (_startDate != null && _endDate != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text('Filter: '),
                        Text(
                          '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - '
                          '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada data',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: ListTile(
                                title: Text(order.customerName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatDateTime(order.orderDate)),
                                    Text('Total: Rp${order.totalAmount}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Payment status
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          order.isPaid ? Icons.payment : Icons.money_off,
                                          color: order.isPaid ? Colors.green : Colors.orange,
                                          size: 20,
                                        ),
                                        Switch(
                                          value: order.isPaid,
                                          onChanged: (value) => _updatePaymentStatus(order),
                                        ),
                                      ],
                                    ),
                                    // Completion status
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          order.status == 'completed' ? Icons.check_circle : Icons.pending,
                                          color: order.status == 'completed' ? Colors.green : Colors.orange,
                                          size: 20,
                                        ),
                                        Switch(
                                          value: order.status == 'completed',
                                          activeColor: Colors.green,
                                          onChanged: (value) => _updateOrderStatus(order),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.info_outline),
                                      onPressed: () => _showOrderDetails(order),
                                    ),
                                  ],
                                ),
                                onTap: () => _showOrderDetails(order),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
