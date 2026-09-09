class Backend {
    String backendId
    boolean health = true
    long weight = 1
    long inflight = 0
}

class Simulation {
    private final List<Backend> backends = []
    private final Map<String, Backend> byId = new LinkedHashMap<>()
    private long cursor = 0
    private final Map<String, String> stickyMap = new LinkedHashMap<>()
    private boolean useLeast = false

    String addBackend(String backendId) {
        if (byId.containsKey(backendId)) {
            return 'false'
        }
        Backend item = new Backend(backendId: backendId)
        backends.add(item)
        byId[backendId] = item
        return 'true'
    }

    String setHealth(String backendId, long flag) {
        Backend item = byId[backendId]
        if (item == null || (flag != 0 && flag != 1)) {
            return 'invalid_request'
        }
        item.health = flag == 1
        resetCycle()
        return 'true'
    }

    String setWeight(String backendId, long weight) {
        Backend item = byId[backendId]
        if (item == null || weight <= 0) {
            return 'invalid_request'
        }
        item.weight = weight
        resetCycle()
        return 'true'
    }

    String route() {
        return take()
    }

    String sticky(String clientId) {
        String bound = stickyMap[clientId]
        Backend item = bound == null ? null : byId[bound]
        if (item != null && item.health) {
            item.inflight += 1
            return item.backendId
        }
        String chosen = take()
        if (chosen != '') {
            stickyMap[clientId] = chosen
        }
        return chosen
    }

    String done(String backendId) {
        Backend item = byId[backendId]
        if (item == null || item.inflight <= 0) {
            return 'invalid_request'
        }
        item.inflight -= 1
        useLeast = true
        return 'true'
    }

    private void resetCycle() {
        cursor = 0
        useLeast = false
        backends.each { it.inflight = 0 }
    }

    private List<Backend> tickets(List<Backend> items) {
        List<Backend> out = []
        items.each { item ->
            item.weight.times { out.add(item) }
        }
        return out
    }

    private Backend pick() {
        List<Backend> healthy = backends.findAll { it.health }
        if (healthy.isEmpty()) {
            return null
        }
        List<Backend> pool = healthy
        if (useLeast) {
            long least = healthy.collect { it.inflight }.min()
            pool = healthy.findAll { it.inflight == least }
        }
        List<Backend> tix = tickets(pool)
        if (tix.isEmpty()) {
            return null
        }
        Backend chosen = tix[(int) (cursor % tix.size())]
        cursor += 1
        return chosen
    }

    private String take() {
        Backend item = pick()
        if (item == null) {
            return ''
        }
        item.inflight += 1
        return item.backendId
    }
}
