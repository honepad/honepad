class KeyState {
  int limit = 3;
  int window = 10;
  int? windowId;
  int used = 0;
}

class Simulation {
  final Map<String, KeyState> keys = {};

  String allow(String key, int timestamp) {
    return allowWeighted(key, 1, timestamp);
  }

  String configure(String key, int limit, int window) {
    if (limit <= 0 || window <= 0) {
      return 'invalid_request';
    }
    final item = state(key);
    item.limit = limit;
    item.window = window;
    item.windowId = null;
    item.used = 0;
    return 'true';
  }

  String remaining(String key, int timestamp) {
    final item = state(key);
    final used = usedAt(item, timestamp, false);
    return '${item.limit - used}';
  }

  String allowWeighted(String key, int cost, int timestamp) {
    if (cost <= 0) {
      return 'invalid_request';
    }
    final item = state(key);
    usedAt(item, timestamp, true);
    if (item.used + cost > item.limit) {
      return 'false';
    }
    item.used += cost;
    return 'true';
  }

  KeyState state(String key) {
    return keys.putIfAbsent(key, () => KeyState());
  }

  int usedAt(KeyState item, int timestamp, bool persist) {
    final windowId = timestamp ~/ item.window;
    if (item.windowId == null || windowId != item.windowId) {
      if (persist) {
        item.windowId = windowId;
        item.used = 0;
      }
      return 0;
    }
    return item.used;
  }
}
