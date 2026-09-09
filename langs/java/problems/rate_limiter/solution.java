import java.util.HashMap;
import java.util.Map;

class KeyState {
    int limit = 3;
    int window = 10;
    Integer windowId = null;
    int used = 0;
}

public class Simulation {
    private final Map<String, KeyState> keys = new HashMap<>();

    public Simulation() {}

    private KeyState state(String key) {
        KeyState item = keys.get(key);
        if (item == null) {
            item = new KeyState();
            keys.put(key, item);
        }
        return item;
    }

    private int usedAt(KeyState item, int timestamp, boolean persist) {
        int windowId = timestamp / item.window;
        if (item.windowId == null || windowId != item.windowId) {
            if (persist) {
                item.windowId = windowId;
                item.used = 0;
            }
            return 0;
        }
        return item.used;
    }

    public String allow(String key, int timestamp) {
        return allowWeighted(key, 1, timestamp);
    }

    public String configure(String key, int limit, int window) {
        if (limit <= 0 || window <= 0) {
            return "invalid_request";
        }
        KeyState item = state(key);
        item.limit = limit;
        item.window = window;
        item.windowId = null;
        item.used = 0;
        return "true";
    }

    public String remaining(String key, int timestamp) {
        KeyState item = state(key);
        int used = usedAt(item, timestamp, false);
        return String.valueOf(item.limit - used);
    }

    public String allowWeighted(String key, int cost, int timestamp) {
        if (cost <= 0) {
            return "invalid_request";
        }
        KeyState item = state(key);
        usedAt(item, timestamp, true);
        if (item.used + cost > item.limit) {
            return "false";
        }
        item.used += cost;
        return "true";
    }
}
