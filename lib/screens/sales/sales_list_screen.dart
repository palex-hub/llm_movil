import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../../services/api_service.dart';
import '../../services/product_name_cache.dart';
import 'sale_create_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final _api = ApiService();
  List<Sale> _sales = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ProductNameCache().ensureLoaded();
      _sales = await _api.getSales();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() { _loading = false; });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _toggleStatus(Sale sale) async {
    final nextStatus = sale.status == 'pending'
        ? 'completed'
        : sale.status == 'completed'
            ? 'cancelled'
            : 'pending';
    try {
      await _api.updateSale(sale.id, {'status': nextStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(Sale sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sale'),
        content: Text('Delete sale #${sale.id} (${sale.customer})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteSale(sale.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SaleCreateScreen()))
            .then((_) => _load()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _sales.isEmpty
                  ? const Center(child: Text('No sales'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _sales.length,
                        itemBuilder: (_, i) {
                          final v = _sales[i];
                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(v.status),
                              child: Text('#${v.id}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            title: Text(v.customer),
                            subtitle: Text(
                                '\$${v.total.toStringAsFixed(2)} | ${v.status}'),
                            children: [
                              ...v.products.map((d) => ListTile(
                                    dense: true,
                                    title: Text(
                                        '${ProductNameCache().resolve(d.productId)} x${d.quantity}'),
                                    trailing: Text(
                                        '\$${d.subtotal.toStringAsFixed(2)}'),
                                  )),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.swap_horiz,
                                        size: 18),
                                    label: const Text('Change status'),
                                    onPressed: () => _toggleStatus(v),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    label: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () => _delete(v),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
