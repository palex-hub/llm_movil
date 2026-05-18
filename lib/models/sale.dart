class SaleDetail {
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  SaleDetail({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    return SaleDetail(
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

class Sale {
  final int id;
  final String customer;
  final double total;
  final String status;
  final List<SaleDetail> products;

  Sale({
    required this.id,
    required this.customer,
    required this.total,
    required this.status,
    required this.products,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] ?? 0,
      customer: json['customer_name'] ?? json['customer'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      products: (json['details'] as List? ?? [])
          .map((e) => SaleDetail.fromJson(e))
          .toList(),
    );
  }
}
