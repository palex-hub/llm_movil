import 'api_service.dart';

class ProductNameCache {
  static final ProductNameCache _instance = ProductNameCache._();
  factory ProductNameCache() => _instance;
  ProductNameCache._();

  final Map<int, String> _cache = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final api = ApiService();
    final products = await api.getProducts();
    for (final p in products) {
      _cache[p.id] = p.name;
    }
    _loaded = true;
  }

  String resolve(int productId) => _cache[productId] ?? 'Product #$productId';

  void invalidate() {
    _cache.clear();
    _loaded = false;
  }
}
