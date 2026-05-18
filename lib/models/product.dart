class Product {
  final int id;
  final String name;
  final int quantity;
  final double salePrice;
  final double? purchasePrice;
  final String? code;
  final String? description;
  final bool active;

  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.salePrice,
    this.purchasePrice,
    this.code,
    this.description,
    this.active = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      salePrice: (json['sale_price'] ?? 0).toDouble(),
      purchasePrice: (json['purchase_price'] ?? 0).toDouble(),
      code: json['code'],
      description: json['description'],
      active: json['active'] ?? true,
    );
  }
}
