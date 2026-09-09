class Backend {
  String backendId;
  bool health = true;
  int weight = 1;
  int inflight = 0;

  Backend(this.backendId);
}

class Simulation {
  final List<Backend> backends = [];
  final Map<String, Backend> byId = {};
  int cursor = 0;
  final Map<String, String> stickyMap = {};
  bool useLeast = false;

  String addBackend(String backendId) {
    if (byId.containsKey(backendId)) {
      return 'false';
    }
    final item = Backend(backendId);
    backends.add(item);
    byId[backendId] = item;
    return 'true';
  }

  String setHealth(String backendId, int flag) {
    final item = byId[backendId];
    if (item == null || (flag != 0 && flag != 1)) {
      return 'invalid_request';
    }
    item.health = flag == 1;
    resetCycle();
    return 'true';
  }

  String setWeight(String backendId, int weight) {
    final item = byId[backendId];
    if (item == null || weight <= 0) {
      return 'invalid_request';
    }
    item.weight = weight;
    resetCycle();
    return 'true';
  }

  String route() {
    return take();
  }

  String sticky(String clientId) {
    final bound = stickyMap[clientId];
    final item = bound == null ? null : byId[bound];
    if (item != null && item.health) {
      item.inflight += 1;
      return item.backendId;
    }
    final chosen = take();
    if (chosen.isNotEmpty) {
      stickyMap[clientId] = chosen;
    }
    return chosen;
  }

  String done(String backendId) {
    final item = byId[backendId];
    if (item == null || item.inflight <= 0) {
      return 'invalid_request';
    }
    item.inflight -= 1;
    useLeast = true;
    return 'true';
  }

  void resetCycle() {
    cursor = 0;
    useLeast = false;
    for (final item in backends) {
      item.inflight = 0;
    }
  }

  List<Backend> tickets(List<Backend> items) {
    final out = <Backend>[];
    for (final item in items) {
      for (var i = 0; i < item.weight; i++) {
        out.add(item);
      }
    }
    return out;
  }

  Backend? pick() {
    final healthy = backends.where((item) => item.health).toList();
    if (healthy.isEmpty) {
      return null;
    }
    var pool = healthy;
    if (useLeast) {
      final least = healthy.map((item) => item.inflight).reduce((a, b) => a < b ? a : b);
      pool = healthy.where((item) => item.inflight == least).toList();
    }
    final tix = tickets(pool);
    if (tix.isEmpty) {
      return null;
    }
    final chosen = tix[cursor % tix.length];
    cursor += 1;
    return chosen;
  }

  String take() {
    final item = pick();
    if (item == null) {
      return '';
    }
    item.inflight += 1;
    return item.backendId;
  }
}
