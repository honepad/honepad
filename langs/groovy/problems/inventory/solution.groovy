class Simulation {
    private final Map<String, Item> items = new LinkedHashMap<>()

    String createItem(String sku, String name) {
        if (items.containsKey(sku)) {
            return 'false'
        }
        items[sku] = new Item(sku, name)
        return 'true'
    }

    String stock(String sku, long delta) {
        Item item = items[sku]
        if (item == null) {
            return ''
        }
        long nxt = item.qty + delta
        if (nxt < item.reserved) {
            return 'invalid_request'
        }
        item.qty = nxt
        return String.valueOf(item.qty)
    }

    String getQty(String sku) {
        Item item = items[sku]
        if (item == null) {
            return ''
        }
        return String.valueOf(item.qty)
    }

    String listLow(long threshold) {
        List<Item> matched = items.values().findAll { it.qty <= threshold }
        matched.sort { a, b ->
            int d = Long.compare(a.qty, b.qty)
            d != 0 ? d : a.sku <=> b.sku
        }
        matched.collect { item ->
            "${item.sku}(${item.qty})"
        }.join(', ')
    }

    String reserve(String sku, long n) {
        Item item = items[sku]
        if (item == null || n <= 0 || item.reserved + n > item.qty) {
            return 'invalid_request'
        }
        item.reserved += n
        return 'true'
    }

    String release(String sku, long n) {
        Item item = items[sku]
        if (item == null || n <= 0 || n > item.reserved) {
            return 'invalid_request'
        }
        item.reserved -= n
        return 'true'
    }

    String ship(String sku, long n) {
        Item item = items[sku]
        if (item == null || n <= 0 || n > item.reserved) {
            return 'invalid_request'
        }
        item.reserved -= n
        item.qty -= n
        return 'true'
    }
}

class Item {
    String sku
    String name
    long qty = 0
    long reserved = 0

    Item(String sku, String name) {
        this.sku = sku
        this.name = name
    }
}
