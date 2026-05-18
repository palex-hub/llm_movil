import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SaleCreateScreen extends StatefulWidget {
  const SaleCreateScreen({super.key});

  @override
  State<SaleCreateScreen> createState() => _SaleCreateScreenState();
}

class _SaleCreateScreenState extends State<SaleCreateScreen> {
  final _customerCtrl = TextEditingController();
  final _api = ApiService();
  bool _saving = false;
  final List<Map<String, dynamic>> _products = [];

  void _addProduct() {
    final prodCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: prodCtrl, decoration: const InputDecoration(labelText: 'Product')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _products.add({'product': prodCtrl.text, 'quantity': int.tryParse(qtyCtrl.text) ?? 1});
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_customerCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the customer name')));
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one product')));
      return;
    }
    setState(() { _saving = true; });
    try {
      await _api.createSale({
        'customer_name': _customerCtrl.text,
        'products': _products.map((p) => {
          'product_name': p['product'],
          'quantity': p['quantity'],
        }).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() { _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: 'Customer name')),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add')),
            ],
          ),
          ..._products.map((p) => ListTile(
            title: Text(p['product']),
            trailing: Text('x${p['quantity']}'),
          )),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Register Sale'),
          ),
        ],
      ),
    );
  }
}
