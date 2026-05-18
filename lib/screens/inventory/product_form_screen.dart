import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _api = ApiService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _codeCtrl.text = widget.product!.code ?? '';
      _descCtrl.text = widget.product!.description ?? '';
      _quantityCtrl.text = widget.product!.quantity.toString();
      _salePriceCtrl.text = widget.product!.salePrice.toString();
      _purchasePriceCtrl.text = widget.product!.purchasePrice?.toString() ?? '';
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; });
    try {
      final data = {
        'name': _nameCtrl.text,
        'code': _codeCtrl.text,
        'description': _descCtrl.text,
        'quantity': int.tryParse(_quantityCtrl.text) ?? 0,
        'sale_price': double.tryParse(_salePriceCtrl.text) ?? 0,
        'purchase_price': double.tryParse(_purchasePriceCtrl.text) ?? 0,
      };
      if (widget.product == null) {
        await _api.createProduct(data);
      } else {
        await _api.updateProduct(widget.product!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() { _saving = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'New Product' : 'Edit Product')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
            TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            TextFormField(controller: _quantityCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            TextFormField(controller: _salePriceCtrl, decoration: const InputDecoration(labelText: 'Sale Price'), keyboardType: TextInputType.number),
            TextFormField(controller: _purchasePriceCtrl, decoration: const InputDecoration(labelText: 'Purchase Price'), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
