import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

class Item {
    String sku;
    String name;
    int qty = 0;
    int reserved = 0;

    Item(String sku, String name) {
        this.sku = sku;
        this.name = name;
    }
}

public class Simulation {
    private final Map<String, Item> items = new LinkedHashMap<>();

    public Simulation() {}

    public String createItem(String sku, String name) {
        if (items.containsKey(sku)) {
            return "false";
        }
        items.put(sku, new Item(sku, name));
        return "true";
    }

    public String stock(String sku, int delta) {
        Item item = items.get(sku);
        if (item == null) {
            return "";
        }
        int nxt = item.qty + delta;
        if (nxt < item.reserved) {
            return "invalid_request";
        }
        item.qty = nxt;
        return String.valueOf(item.qty);
    }

    public String getQty(String sku) {
        Item item = items.get(sku);
        return item == null ? "" : String.valueOf(item.qty);
    }

    public String listLow(int threshold) {
        List<Item> matched = new ArrayList<>();
        for (Item item : items.values()) {
            if (item.qty <= threshold) {
                matched.add(item);
            }
        }
        matched.sort((a, b) -> {
            int d = Integer.compare(a.qty, b.qty);
            return d != 0 ? d : a.sku.compareTo(b.sku);
        });
        List<String> parts = new ArrayList<>();
        for (Item item : matched) {
            parts.add(item.sku + "(" + item.qty + ")");
        }
        return String.join(", ", parts);
    }

    public String reserve(String sku, int n) {
        Item item = items.get(sku);
        if (item == null || n <= 0 || item.reserved + n > item.qty) {
            return "invalid_request";
        }
        item.reserved += n;
        return "true";
    }

    public String release(String sku, int n) {
        Item item = items.get(sku);
        if (item == null || n <= 0 || n > item.reserved) {
            return "invalid_request";
        }
        item.reserved -= n;
        return "true";
    }

    public String ship(String sku, int n) {
        Item item = items.get(sku);
        if (item == null || n <= 0 || n > item.reserved) {
            return "invalid_request";
        }
        item.reserved -= n;
        item.qty -= n;
        return "true";
    }
}
