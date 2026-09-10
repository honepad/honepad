import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Simulation {
    private final Map<String, List<String>> subs = new HashMap<>();
    private final Map<String, List<String>> inboxMap = new HashMap<>();
    private final Map<String, String> retained = new HashMap<>();

    public Simulation() {}

    public String subscribe(String topic, String client) {
        List<String> clients = subs.computeIfAbsent(topic, key -> new ArrayList<>());
        if (clients.contains(client)) {
            return "false";
        }
        clients.add(client);
        if (retained.containsKey(topic)) {
            inboxMap.computeIfAbsent(client, key -> new ArrayList<>())
                    .add(topic + ":" + retained.get(topic));
        }
        return "true";
    }

    public String unsubscribe(String topic, String client) {
        List<String> clients = subs.get(topic);
        if (clients == null || !clients.contains(client)) {
            return "false";
        }
        clients.remove(client);
        if (clients.isEmpty()) {
            subs.remove(topic);
        }
        return "true";
    }

    public String publish(String topic, String message) {
        List<String> clients = subs.getOrDefault(topic, Collections.emptyList());
        String payload = topic + ":" + message;
        for (String client : clients) {
            inboxMap.computeIfAbsent(client, key -> new ArrayList<>()).add(payload);
        }
        return String.valueOf(clients.size());
    }

    public String inbox(String client) {
        return String.join(", ", inboxMap.getOrDefault(client, Collections.emptyList()));
    }

    public String listTopics() {
        List<String> topics = new ArrayList<>(subs.keySet());
        Collections.sort(topics);
        return String.join(", ", topics);
    }

    public String subscribers(String topic) {
        List<String> clients = new ArrayList<>(subs.getOrDefault(topic, Collections.emptyList()));
        Collections.sort(clients);
        return String.join(", ", clients);
    }

    public String peek(String client) {
        List<String> items = inboxMap.getOrDefault(client, Collections.emptyList());
        return items.isEmpty() ? "" : items.get(0);
    }

    public String ack(String client, int n) {
        if (n <= 0 || !inboxMap.containsKey(client)) {
            return "invalid_request";
        }
        List<String> items = inboxMap.get(client);
        if (n > items.size()) {
            return "invalid_request";
        }
        items.subList(0, n).clear();
        return String.valueOf(items.size());
    }

    public String retain(String topic, String message) {
        retained.put(topic, message);
        return "";
    }
}
