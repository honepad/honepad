class Item(val sku: String, val name: String, var qty: Int = 0, var reserved: Int = 0)

class Simulation {
    private val items = LinkedHashMap<String, Item>()

    fun createItem(sku: String, name: String): String {
        if (items.containsKey(sku)) {
            return "false"
        }
        items[sku] = Item(sku, name)
        return "true"
    }

    fun stock(sku: String, delta: Int): String {
        val item = items[sku] ?: return ""
        val nxt = item.qty + delta
        if (nxt < item.reserved) {
            return "invalid_request"
        }
        item.qty = nxt
        return item.qty.toString()
    }

    fun getQty(sku: String): String {
        val item = items[sku] ?: return ""
        return item.qty.toString()
    }

    fun listLow(threshold: Int): String {
        val matched = ArrayList<Item>()
        for (item in items.values) {
            if (item.qty <= threshold) {
                matched.add(item)
            }
        }
        matched.sortWith { a, b ->
            val d = a.qty.compareTo(b.qty)
            if (d != 0) d else a.sku.compareTo(b.sku)
        }
        val parts = ArrayList<String>()
        for (item in matched) {
            parts.add("${item.sku}(${item.qty})")
        }
        return parts.joinToString(", ")
    }

    fun reserve(sku: String, n: Int): String {
        val item = items[sku]
        if (item == null || n <= 0 || item.reserved + n > item.qty) {
            return "invalid_request"
        }
        item.reserved += n
        return "true"
    }

    fun release(sku: String, n: Int): String {
        val item = items[sku]
        if (item == null || n <= 0 || n > item.reserved) {
            return "invalid_request"
        }
        item.reserved -= n
        return "true"
    }

    fun ship(sku: String, n: Int): String {
        val item = items[sku]
        if (item == null || n <= 0 || n > item.reserved) {
            return "invalid_request"
        }
        item.reserved -= n
        item.qty -= n
        return "true"
    }
}
