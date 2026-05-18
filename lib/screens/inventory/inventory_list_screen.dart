import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import 'product_form_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _api = ApiService();
  List<Product> _products = [];
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
      _products = await _api.getProducts();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _delete(Product p) async {
    try {
      await _api.deleteProduct(p.id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())).then((_) => _load()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _products.isEmpty
                  ? const Center(child: Text('No products'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (_, i) {
                          final p = _products[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.quantity > 0 ? Colors.green : Colors.red,
                              child: Text('${p.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            title: Text(p.name),
                            subtitle: Text('\$${p.salePrice.toStringAsFixed(2)} | Stock: ${p.quantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _delete(p),
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))).then((_) => _load()),
                          );
                        },
                      ),
                    ),
    );
  }
}
