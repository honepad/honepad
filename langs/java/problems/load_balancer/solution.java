import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class Backend {
    String backendId;
    boolean health = true;
    int weight = 1;
    int inflight = 0;

    Backend(String backendId) {
        this.backendId = backendId;
    }
}

public class Simulation {
    private final List<Backend> backends = new ArrayList<>();
    private final Map<String, Backend> byId = new HashMap<>();
    private int cursor = 0;
    private final Map<String, String> stickyMap = new HashMap<>();
    private boolean useLeast = false;

    public Simulation() {}

    public String addBackend(String backendId) {
        if (byId.containsKey(backendId)) {
            return "false";
        }
        Backend item = new Backend(backendId);
        backends.add(item);
        byId.put(backendId, item);
        return "true";
    }

    public String setHealth(String backendId, int flag) {
        Backend item = byId.get(backendId);
        if (item == null || (flag != 0 && flag != 1)) {
            return "invalid_request";
        }
        item.health = flag == 1;
        resetCycle();
        return "true";
    }

    public String setWeight(String backendId, int weight) {
        Backend item = byId.get(backendId);
        if (item == null || weight <= 0) {
            return "invalid_request";
        }
        item.weight = weight;
        resetCycle();
        return "true";
    }

    private void resetCycle() {
        cursor = 0;
        useLeast = false;
        for (Backend item : backends) {
            item.inflight = 0;
        }
    }

    private List<Backend> tickets(List<Backend> items) {
        List<Backend> out = new ArrayList<>();
        for (Backend item : items) {
            for (int i = 0; i < item.weight; i++) {
                out.add(item);
            }
        }
        return out;
    }

    private Backend pick() {
        List<Backend> healthy = new ArrayList<>();
        for (Backend item : backends) {
            if (item.health) {
                healthy.add(item);
            }
        }
        if (healthy.isEmpty()) {
            return null;
        }
        List<Backend> pool = healthy;
        if (useLeast) {
            int least = healthy.get(0).inflight;
            for (int i = 1; i < healthy.size(); i++) {
                if (healthy.get(i).inflight < least) {
                    least = healthy.get(i).inflight;
                }
            }
            pool = new ArrayList<>();
            for (Backend item : healthy) {
                if (item.inflight == least) {
                    pool.add(item);
                }
            }
        }
        List<Backend> tickets = tickets(pool);
        if (tickets.isEmpty()) {
            return null;
        }
        Backend chosen = tickets.get(cursor % tickets.size());
        cursor += 1;
        return chosen;
    }

    private String take() {
        Backend item = pick();
        if (item == null) {
            return "";
        }
        item.inflight += 1;
        return item.backendId;
    }

    public String route() {
        return take();
    }

    public String sticky(String clientId) {
        String bound = stickyMap.get(clientId);
        Backend item = bound == null ? null : byId.get(bound);
        if (item != null && item.health) {
            item.inflight += 1;
            return item.backendId;
        }
        String chosen = take();
        if (!chosen.isEmpty()) {
            stickyMap.put(clientId, chosen);
        }
        return chosen;
    }

    public String done(String backendId) {
        Backend item = byId.get(backendId);
        if (item == null || item.inflight <= 0) {
            return "invalid_request";
        }
        item.inflight -= 1;
        useLeast = true;
        return "true";
    }
}
