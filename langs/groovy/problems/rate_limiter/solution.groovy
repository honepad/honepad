class Simulation {
    private final Map<String, KeyState> keys = new LinkedHashMap<>()

    String allow(String key, long timestamp) {
        return allowWeighted(key, 1, timestamp)
    }

    String configure(String key, long limit, long window) {
        if (limit <= 0 || window <= 0) {
            return 'invalid_request'
        }
        KeyState item = state(key)
        item.limit = limit
        item.window = window
        item.windowId = null
        item.used = 0
        return 'true'
    }

    String remaining(String key, long timestamp) {
        KeyState item = state(key)
        long used = usedAt(item, timestamp, false)
        return String.valueOf(item.limit - used)
    }

    String allowWeighted(String key, long cost, long timestamp) {
        if (cost <= 0) {
            return 'invalid_request'
        }
        KeyState item = state(key)
        usedAt(item, timestamp, true)
        if (item.used + cost > item.limit) {
            return 'false'
        }
        item.used += cost
        return 'true'
    }

    private KeyState state(String key) {
        KeyState item = keys[key]
        if (item == null) {
            item = new KeyState()
            keys[key] = item
        }
        return item
    }

    private long usedAt(KeyState item, long timestamp, boolean persist) {
        long windowId = Math.floorDiv(timestamp, item.window)
        if (item.windowId == null || windowId != item.windowId) {
            if (persist) {
                item.windowId = windowId
                item.used = 0
            }
            return 0
        }
        return item.used
    }
}

class KeyState {
    long limit = 3
    long window = 10
    Long windowId = null
    long used = 0
}
