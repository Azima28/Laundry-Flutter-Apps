import 'package:flutter/material.dart';
import '../database/models/order_model.dart';
import '../transactions/order_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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
  Map<String, int> _itemQuantities = {};
  Map<String, int> _itemRevenues = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _calculateStatistics() {
    _totalRevenue = 0;
    _itemQuantities.clear();
    _itemRevenues.clear();

    for (var order in _orders) {
      _totalRevenue += order.totalAmount;
      
      for (var item in order.items) {
        _itemQuantities[item.itemName] = (_itemQuantities[item.itemName] ?? 0) + item.quantity;
        _itemRevenues[item.itemName] = (_itemRevenues[item.itemName] ?? 0) + (item.price * item.quantity);
      }
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((order) {
          return order.customerName.toLowerCase().contains(query) ||
                 order.items.any((item) => item.itemName.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now(),
              end: DateTime.now(),
            ),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _showOnlyToday = false;
      });
      _loadOrders();
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
    _loadOrders();
  }

  Future<void> _updateOrderStatus(Order order, String newStatus) async {
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

  Future<void> _updatePaymentStatus(Order order) async {
    final success = await _repository.updateOrderPaymentStatus(order.id!, true);
    if (success) {
      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status pembayaran berhasil diperbarui')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status pembayaran')),
      );
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }
    
    final orders = await _repository.getAllOrders(userId: userId);
    // Filter out ironing orders (no kg in notes)
    final laundryOrders = orders.where((order) => 
      !order.items.any((item) => item.note?.toLowerCase().contains('kg') ?? false)
    ).toList();
    
    setState(() {
      if (_showOnlyToday) {
        final now = DateTime.now();
        _orders = laundryOrders.where((order) {
          final orderDate = order.orderDate;
          return orderDate.year == now.year &&
                 orderDate.month == now.month &&
                 orderDate.day == now.day;
        }).toList();
      } else if (_startDate != null && _endDate != null) {
        _orders = orders.where((order) {
          return order.orderDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                 order.orderDate.isBefore(_endDate!.add(Duration(days: 1)));
        }).toList();
      } else {
        _orders = orders;
      }
      _calculateStatistics();
      _filteredOrders = _orders; // Initialize filtered orders
      _filterOrders(); // Apply any existing search filter
      _isLoading = false;
    });
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nama Pemesan: ${order.customerName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text('Tanggal: ${_formatDateTime(order.orderDate)}'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${order.status}'),
                      SizedBox(height: 4),
                      Text(
                        'Pembayaran: ${order.isPaid ? "Sudah Dibayar" : "Belum Dibayar"}',
                        style: TextStyle(
                          color: order.isPaid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      if (order.status.toLowerCase() == 'pending')
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updateOrderStatus(order, 'Completed');
                          },
                          child: Text('Selesaikan'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                        ),
                      if (!order.isPaid)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updatePaymentStatus(order);
                          },
                          child: Text('Konfirmasi Pembayaran'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Divider(),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.itemName),
                          Text(
                            '${item.quantity}x @ Rp${item.price}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (item.note?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Catatan: ${item.note}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text('Rp${item.quantity * item.price}'),
                  ],
                ),
              )),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp${order.totalAmount}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
        title: Text('Statistik Pesanan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Pendapatan: Rp$_totalRevenue',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Statistik per Item:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              ...(_itemQuantities.keys.toList()..sort()).map((itemName) {
                final quantity = _itemQuantities[itemName] ?? 0;
                final revenue = _itemRevenues[itemName] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jumlah: $quantity'),
                            Text('Pendapatan: Rp$revenue'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Pesanan'),
        actions: [
          // Today filter toggle
          TextButton.icon(
            icon: Icon(
              Icons.today,
              color: _showOnlyToday ? Colors.white : Colors.white70,
            ),
            label: Text(
              'Hari Ini',
              style: TextStyle(
                color: _showOnlyToday ? Colors.white : Colors.white70,
              ),
            ),
            onPressed: _toggleTodayFilter,
          ),
          // Date range picker
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
          ),
          // Statistics
          IconButton(
            icon: Icon(Icons.analytics_outlined),
            onPressed: _showStatistics,
          ),
          // Refresh
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date filter indicator
          if (!_showOnlyToday && _startDate != null && _endDate != null)
            Container(
              color: Colors.indigo.withOpacity(0.1),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 18, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'Filter: ${_formatDateTime(_startDate!)} - ${_formatDateTime(_endDate!)}',
                    style: TextStyle(color: Colors.indigo),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _showOnlyToday = true;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadOrders();
                    },
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama atau item...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada pesanan',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredOrders.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _showOrderDetails(order),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.customerName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(order.orderDate),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          order.status,
                                          style: TextStyle(
                                            color: _getStatusColor(order.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: order.isPaid 
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          order.isPaid ? 'Sudah Bayar' : 'Belum Bayar',
                                          style: TextStyle(
                                            color: order.isPaid ? Colors.green : Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${order.items.length} item:',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  ...order.items.take(3).map((item) => Padding(
                                    padding: EdgeInsets.only(left: 8, top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.quantity}x ${item.itemName}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        if (item.note?.isNotEmpty == true)
                                          Text(
                                            'Catatan: ${item.note}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  )), // Tampilkan 3 item pertama
                                  if (order.items.length > 3)
                                    Padding(
                                      padding: EdgeInsets.only(left: 8, top: 4),
                                      child: Text(
                                        '... dan ${order.items.length - 3} item lainnya',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Total: Rp${order.totalAmount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
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
