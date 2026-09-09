class Item {
  Item(this.sku, this.name);

  final String sku;
  final String name;
  int qty = 0;
  int reserved = 0;
}

class Simulation {
  final Map<String, Item> items = {};

  String createItem(String sku, String name) {
    if (items.containsKey(sku)) {
      return 'false';
    }
    items[sku] = Item(sku, name);
    return 'true';
  }

  String stock(String sku, int delta) {
    final item = items[sku];
    if (item == null) {
      return '';
    }
    final nxt = item.qty + delta;
    if (nxt < item.reserved) {
      return 'invalid_request';
    }
    item.qty = nxt;
    return '${item.qty}';
  }

  String getQty(String sku) {
    final item = items[sku];
    if (item == null) {
      return '';
    }
    return '${item.qty}';
  }

  String listLow(int threshold) {
    final matched = [
      for (final item in items.values)
        if (item.qty <= threshold) item,
    ];
    matched.sort((a, b) {
      final d = a.qty.compareTo(b.qty);
      return d != 0 ? d : a.sku.compareTo(b.sku);
    });
    return matched.map((item) => '${item.sku}(${item.qty})').join(', ');
  }

  String reserve(String sku, int n) {
    final item = items[sku];
    if (item == null || n <= 0 || item.reserved + n > item.qty) {
      return 'invalid_request';
    }
    item.reserved += n;
    return 'true';
  }

  String release(String sku, int n) {
    final item = items[sku];
    if (item == null || n <= 0 || n > item.reserved) {
      return 'invalid_request';
    }
    item.reserved -= n;
    return 'true';
  }

  String ship(String sku, int n) {
    final item = items[sku];
    if (item == null || n <= 0 || n > item.reserved) {
      return 'invalid_request';
    }
    item.reserved -= n;
    item.qty -= n;
    return 'true';
  }
}
