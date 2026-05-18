import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sale.dart';
import '../models/purchase.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/category.dart';

class ApiService {
  static const String baseUrl =
      'https://spkvgkwbfi.execute-api.us-east-1.amazonaws.com/dev';

  // --- CUSTOMERS ---
  Future<List<Customer>> getCustomers() async {
    final res = await http.get(Uri.parse('$baseUrl/customers'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Customer.fromJson(e)).toList();
    }
    throw Exception('Error fetching customers: ${res.statusCode}');
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Customer.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error creating customer: ${res.statusCode}');
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/customers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Customer.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error updating customer: ${res.statusCode}');
  }

  Future<void> deleteCustomer(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/customers/$id'));
    if (res.statusCode != 204) {
      throw Exception('Error deleting customer: ${res.statusCode}');
    }
  }

  // --- INVENTORY ---
  Future<List<Product>> getProducts() async {
    final res = await http.get(Uri.parse('$baseUrl/inventory/products'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Product.fromJson(e)).toList();
    }
    throw Exception('Error fetching products: ${res.statusCode}');
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/inventory/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Product.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error creating product: ${res.statusCode}');
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/inventory/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Product.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error updating product: ${res.statusCode}');
  }

  Future<void> deleteProduct(int id) async {
    final res =
        await http.delete(Uri.parse('$baseUrl/inventory/products/$id'));
    if (res.statusCode != 204) {
      throw Exception('Error deleting product: ${res.statusCode}');
    }
  }

  // --- CATEGORIES ---
  Future<List<Category>> getCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/inventory/categories'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Category.fromJson(e)).toList();
    }
    throw Exception('Error fetching categories: ${res.statusCode}');
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/inventory/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Category.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error creating category: ${res.statusCode}');
  }

  Future<Category> updateCategory(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/inventory/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Category.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error updating category: ${res.statusCode}');
  }

  Future<void> deleteCategory(int id) async {
    final res =
        await http.delete(Uri.parse('$baseUrl/inventory/categories/$id'));
    if (res.statusCode != 204) {
      throw Exception('Error deleting category: ${res.statusCode}');
    }
  }

  // --- SALES ---
  Future<List<Sale>> getSales() async {
    final res = await http.get(Uri.parse('$baseUrl/sales'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Sale.fromJson(e)).toList();
    }
    throw Exception('Error fetching sales: ${res.statusCode}');
  }

  Future<Sale> createSale(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sales'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Sale.fromJson(jsonDecode(res.body));
    }
    final body = jsonDecode(res.body);
    throw Exception(body['detail'] ?? 'Error creating sale');
  }

  Future<Sale> updateSale(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/sales/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Sale.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error updating sale: ${res.statusCode}');
  }

  Future<void> deleteSale(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/sales/$id'));
    if (res.statusCode != 204) {
      throw Exception('Error deleting sale: ${res.statusCode}');
    }
  }

  // --- PURCHASES ---
  Future<List<Purchase>> getPurchases() async {
    final res = await http.get(Uri.parse('$baseUrl/purchases'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => Purchase.fromJson(e)).toList();
    }
    throw Exception('Error fetching purchases: ${res.statusCode}');
  }

  Future<Purchase> createPurchase(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/purchases'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Purchase.fromJson(jsonDecode(res.body));
    }
    final body = jsonDecode(res.body);
    throw Exception(body['detail'] ?? 'Error creating purchase');
  }

  Future<Purchase> updatePurchase(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/purchases/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Purchase.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error updating purchase: ${res.statusCode}');
  }

  Future<void> deletePurchase(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/purchases/$id'));
    if (res.statusCode != 204) {
      throw Exception('Error deleting purchase: ${res.statusCode}');
    }
  }
}
