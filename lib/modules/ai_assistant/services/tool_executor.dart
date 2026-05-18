import '../../../services/api_service.dart';

class ToolExecutor {
  final _api = ApiService();

  Future<String> execute(String tool, Map<String, dynamic> args) async {
    try {
      switch (tool) {
        case 'get_products':
          final items = await _api.getProducts();
          if (items.isEmpty) return 'No hay productos';
          return items
              .map((p) =>
                  '${p.name} (\$${p.salePrice.toStringAsFixed(2)}, stock ${p.quantity})')
              .join(', ');

        case 'get_product':
          final id = args['id'] as int;
          final items = await _api.getProducts();
          final p = items.firstWhere(
            (p) => p.id == id,
            orElse: () => throw Exception('Producto $id no encontrado'),
          );
          return '${p.name}: stock ${p.quantity}, precio \$${p.salePrice.toStringAsFixed(2)}${p.code != null ? ", codigo ${p.code}" : ""}';

        case 'create_product':
          final prodName = args['name'] as String?;
          if (prodName != null) {
            final prods = await _api.getProducts();
            final match = prods.where(
              (p) => p.name.toLowerCase() == prodName.toLowerCase(),
            );
            if (match.isNotEmpty) {
              return '[COMPLETADO] Producto "$prodName" ya existe (ID ${match.first.id})';
            }
          }
          final mapped = Map<String, dynamic>.from(args);
          if (mapped.containsKey('price') && !mapped.containsKey('sale_price')) {
            mapped['sale_price'] = mapped.remove('price');
          }
          if (mapped.containsKey('name')) {
            mapped['name'] = (mapped['name'] as String).toLowerCase();
          }
          final created = await _api.createProduct(mapped);
          return '[COMPLETADO] Producto "${created.name}" - precio \$${created.salePrice.toStringAsFixed(2)}, stock ${created.quantity}';

        case 'get_customers':
          final items = await _api.getCustomers();
          if (items.isEmpty) return 'No hay clientes';
          return items
              .map((c) =>
                  '${c.name}${c.email != null ? " (${c.email})" : ""}${c.phone != null ? " tel:${c.phone}" : ""}')
              .join(', ');

        case 'get_customer':
          final id = args['id'] as int;
          final items = await _api.getCustomers();
          final c = items.firstWhere(
            (c) => c.id == id,
            orElse: () => throw Exception('Cliente $id no encontrado'),
          );
          return '${c.name}, email: ${c.email ?? "N/A"}, telefono: ${c.phone ?? "N/A"}, direccion: ${c.address ?? "N/A"}';

        case 'create_customer':
          final name = args['name'] as String?;
          if (name != null) {
            final customers = await _api.getCustomers();
            final match = customers.where(
              (c) => c.name.toLowerCase() == name.toLowerCase(),
            );
            if (match.isNotEmpty) {
              return '[COMPLETADO] Cliente "$name" ya existe (ID ${match.first.id})';
            }
          }
          final data = Map<String, dynamic>.from(args);
          if (data.containsKey('name')) {
            data['name'] = (data['name'] as String).toLowerCase();
          }
          final created = await _api.createCustomer(data);
          return '[COMPLETADO] Cliente "${created.name}" creado con ID ${created.id}';


        case 'get_sales':
          final items = await _api.getSales();
          if (items.isEmpty) return 'No hay ventas';
          return items
              .map((s) =>
                  '#${s.id}: ${s.customer} - \$${s.total.toStringAsFixed(2)} (${s.status})')
              .join(', ');

        case 'get_sales_by_customer':
          final name = args['customer_name'] as String;
          final all = await _api.getSales();
          final filtered = all.where((s) =>
              s.customer.toLowerCase().contains(name.toLowerCase()));
          if (filtered.isEmpty) return 'No hay ventas para "$name"';
          return filtered
              .map((s) =>
                  '#${s.id}: \$${s.total.toStringAsFixed(2)} (${s.status})')
              .join(', ');

        case 'create_sale':
          final created = await _api.createSale({
            'customer_name': (args['customer_name'] as String).toLowerCase(),
            'products': (args['products'] as List).map((p) => {
              'product_name': (p['product_name'] as String).toLowerCase(),
              'quantity': p['quantity'],
            }).toList(),
          });
          final saleItems = (args['products'] as List);
          final saleParts = <String>[];
          for (var i = 0; i < created.products.length; i++) {
            final p = saleItems[i];
            final d = created.products[i];
            saleParts.add('${p['product_name']} x${d.quantity} (\$${d.unitPrice})');
          }
          return '[COMPLETADO] Venta #${created.id}: ${created.customer} compro ${saleParts.join(", ")}. Total \$${created.total.toStringAsFixed(2)}';

        case 'get_purchases':
          final items = await _api.getPurchases();
          if (items.isEmpty) return 'No hay compras';
          return items
              .map((p) =>
                  '#${p.id}: ${p.supplier} - \$${p.total.toStringAsFixed(2)} (${p.status})')
              .join(', ');

        case 'create_purchase':
          final created = await _api.createPurchase({
            'products': (args['products'] as List).map((p) => {
              'product_name': (p['product_name'] as String).toLowerCase(),
              'quantity': p['quantity'] ?? 1,
              'unit_price': p['unit_price'] ?? 0.0,
            }).toList(),
          });
          final purchaseItems = (args['products'] as List);
          final purchaseParts = <String>[];
          for (var i = 0; i < created.products.length; i++) {
            final p = purchaseItems[i];
            final d = created.products[i];
            purchaseParts.add('${p['product_name']} x${d.quantity} (\$${d.unitPrice})');
          }
          return '[COMPLETADO] Compra #${created.id}: ${purchaseParts.join(", ")}. Total \$${created.total.toStringAsFixed(2)}';

        case 'get_categories':
          final items = await _api.getCategories();
          if (items.isEmpty) return 'No hay categorias';
          return items.map((c) => '${c.id}: ${c.name}').join(', ');

        case 'create_category':
          final catName = args['name'] as String?;
          if (catName != null) {
            final cats = await _api.getCategories();
            final match = cats.where(
              (c) => c.name.toLowerCase() == catName.toLowerCase(),
            );
            if (match.isNotEmpty) {
              return '[COMPLETADO] Categoria "$catName" ya existe (ID ${match.first.id})';
            }
          }
          final data = Map<String, dynamic>.from(args);
          if (data.containsKey('name')) {
            data['name'] = (data['name'] as String).toLowerCase();
          }
          final created = await _api.createCategory(data);
          return '[COMPLETADO] Categoria "${created.name}" creada con ID ${created.id}';

        default:
          throw Exception('Herramienta desconocida: $tool');
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
