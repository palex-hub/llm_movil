import 'package:flutter/material.dart';
import 'sales/sales_list_screen.dart';
import 'purchases/purchases_list_screen.dart';
import 'inventory/inventory_list_screen.dart';
import 'customers/customers_list_screen.dart';
import 'categories/categories_list_screen.dart';
import '../modules/ai_assistant/screens/chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MenuCard(
              icon: Icons.shopping_cart,
              title: 'Sales',
              desc: 'Manage customer sales',
              color: Colors.green,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SalesListScreen())),
            ),
            _MenuCard(
              icon: Icons.shopping_bag,
              title: 'Purchases',
              desc: 'Supplier orders',
              color: Colors.orange,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PurchasesListScreen())),
            ),
            _MenuCard(
              icon: Icons.inventory,
              title: 'Inventory',
              desc: 'Products and stock',
              color: Colors.blue,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InventoryListScreen())),
            ),
            _MenuCard(
              icon: Icons.people,
              title: 'Customers',
              desc: 'Manage customers',
              color: Colors.purple,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomersListScreen())),
            ),
            _MenuCard(
              icon: Icons.label,
              title: 'Categories',
              desc: 'Product categories',
              color: Colors.teal,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategoriesListScreen())),
            ),
            _MenuCard(
              icon: Icons.smart_toy,
              title: 'AI Assistant',
              desc: 'Local LLM chat - NeuralQwen',
              color: Colors.deepOrange,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChatScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading:
            CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
