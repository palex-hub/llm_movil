import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class PurchaseCreateScreen extends StatefulWidget {
  const PurchaseCreateScreen({super.key});

  @override
  State<PurchaseCreateScreen> createState() => _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends State<PurchaseCreateScreen> {
  final _api = ApiService();
  bool _saving = false;
  final List<Map<String, dynamic>> _products = [];

  void _addProduct() {
    final prodCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '5.0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: prodCtrl,
                decoration: const InputDecoration(labelText: 'Product')),
            TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number),
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Unit Price'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _products.add({
                  'product': prodCtrl.text,
                  'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                  'unit_price': double.tryParse(priceCtrl.text) ?? 5.0,
                });
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
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product')));
      return;
    }
    setState(() { _saving = true; });
    try {
      await _api.createPurchase({
        'products': _products.map((p) => {
          'product_name': p['product'],
          'quantity': p['quantity'],
          'unit_price': p['unit_price'],
        }).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() { _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add')),
            ],
          ),
          ..._products.map((p) => ListTile(
                title: Text(p['product']),
                subtitle: Text('\$${p['unit_price']} x ${p['quantity']}'),
                trailing: Text(
                    '\$${(p['quantity'] * p['unit_price']).toStringAsFixed(2)}'),
              )),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : const Text('Register Purchase'),
          ),
        ],
      ),
    );
  }
}
