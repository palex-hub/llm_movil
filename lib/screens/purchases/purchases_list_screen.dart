import 'package:flutter/material.dart';
import '../../models/purchase.dart';
import '../../services/api_service.dart';
import '../../services/product_name_cache.dart';
import 'purchase_create_screen.dart';

class PurchasesListScreen extends StatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  final _api = ApiService();
  List<Purchase> _purchases = [];
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
      _purchases = await _api.getPurchases();
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

  Future<void> _toggleStatus(Purchase purchase) async {
    final nextStatus = purchase.status == 'pending'
        ? 'completed'
        : purchase.status == 'completed'
            ? 'cancelled'
            : 'pending';
    try {
      await _api.updatePurchase(purchase.id, {'status': nextStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(Purchase purchase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete purchase'),
        content:
            Text('Delete purchase #${purchase.id} (${purchase.supplier})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deletePurchase(purchase.id);
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
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PurchaseCreateScreen()))
            .then((_) => _load()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _purchases.isEmpty
                  ? const Center(child: Text('No purchases'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _purchases.length,
                        itemBuilder: (_, i) {
                          final c = _purchases[i];
                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(c.status),
                              child: Text('#${c.id}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            title: Text(c.supplier),
                            subtitle: Text(
                                '\$${c.total.toStringAsFixed(2)} | ${c.status}'),
                            children: [
                              ...c.products.map((d) => ListTile(
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
                                    onPressed: () => _toggleStatus(c),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    label: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () => _delete(c),
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
