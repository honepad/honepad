class Simulation {
  final Map<String, List<String>> subs = {};
  final Map<String, List<String>> inboxMap = {};
  final Map<String, String> retained = {};

  String subscribe(String topic, String client) {
    final clients = subs.putIfAbsent(topic, () => <String>[]);
    if (clients.contains(client)) {
      return 'false';
    }
    clients.add(client);
    if (retained.containsKey(topic)) {
      inboxMap.putIfAbsent(client, () => <String>[]).add('$topic:${retained[topic]}');
    }
    return 'true';
  }

  String unsubscribe(String topic, String client) {
    final clients = subs[topic];
    if (clients == null || !clients.contains(client)) {
      return 'false';
    }
    clients.remove(client);
    if (clients.isEmpty) {
      subs.remove(topic);
    }
    return 'true';
  }

  String publish(String topic, String message) {
    final clients = subs[topic] ?? const <String>[];
    final payload = '$topic:$message';
    for (final client in clients) {
      inboxMap.putIfAbsent(client, () => <String>[]).add(payload);
    }
    return '${clients.length}';
  }

  String inbox(String client) {
    return (inboxMap[client] ?? const <String>[]).join(', ');
  }

  String listTopics() {
    final topics = subs.keys.toList()..sort();
    return topics.join(', ');
  }

  String subscribers(String topic) {
    final clients = List<String>.from(subs[topic] ?? const <String>[]);
    clients.sort();
    return clients.join(', ');
  }

  String peek(String client) {
    final items = inboxMap[client] ?? const <String>[];
    return items.isEmpty ? '' : items.first;
  }

  String ack(String client, int n) {
    if (n <= 0 || !inboxMap.containsKey(client)) {
      return 'invalid_request';
    }
    final items = inboxMap[client]!;
    if (n > items.length) {
      return 'invalid_request';
    }
    items.removeRange(0, n);
    return '${items.length}';
  }

  String retain(String topic, String message) {
    retained[topic] = message;
    return '';
  }
}
