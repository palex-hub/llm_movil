class PurchaseDetail {
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  PurchaseDetail({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) {
    return PurchaseDetail(
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

class Purchase {
  final int id;
  final String supplier;
  final double total;
  final String status;
  final List<PurchaseDetail> products;

  Purchase({
    required this.id,
    required this.supplier,
    required this.total,
    required this.status,
    required this.products,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] ?? 0,
      supplier: json['supplier'] ?? 'General',
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      products: (json['details'] as List? ?? [])
          .map((e) => PurchaseDetail.fromJson(e))
          .toList(),
    );
  }
}
