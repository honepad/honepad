class Simulation {
    private final Map<String, List<String>> subs = new LinkedHashMap<>()
    private final Map<String, List<String>> inboxMap = new LinkedHashMap<>()
    private final Map<String, String> retained = new LinkedHashMap<>()

    String subscribe(String topic, String client) {
        List<String> clients = subs.computeIfAbsent(topic) { [] }
        if (clients.contains(client)) {
            return 'false'
        }
        clients.add(client)
        if (retained.containsKey(topic)) {
            inboxMap.computeIfAbsent(client) { [] }.add("${topic}:${retained[topic]}")
        }
        return 'true'
    }

    String unsubscribe(String topic, String client) {
        List<String> clients = subs[topic]
        if (clients == null || !clients.contains(client)) {
            return 'false'
        }
        clients.remove(client)
        if (clients.isEmpty()) {
            subs.remove(topic)
        }
        return 'true'
    }

    String publish(String topic, String message) {
        List<String> clients = subs.getOrDefault(topic, [])
        String payload = "${topic}:${message}"
        for (String client : clients) {
            inboxMap.computeIfAbsent(client) { [] }.add(payload)
        }
        return String.valueOf(clients.size())
    }

    String inbox(String client) {
        return inboxMap.getOrDefault(client, []).join(', ')
    }

    String listTopics() {
        return subs.keySet().sort().join(', ')
    }

    String subscribers(String topic) {
        return (subs.getOrDefault(topic, []) as List<String>).sort().join(', ')
    }

    String peek(String client) {
        List<String> items = inboxMap.getOrDefault(client, [])
        return items.isEmpty() ? '' : items[0]
    }

    String ack(String client, long n) {
        if (n <= 0 || !inboxMap.containsKey(client)) {
            return 'invalid_request'
        }
        List<String> items = inboxMap[client]
        if (n > items.size()) {
            return 'invalid_request'
        }
        items.subList(0, (int) n).clear()
        return String.valueOf(items.size())
    }

    String retain(String topic, String message) {
        retained[topic] = message
        return ''
    }
}
