class Backend(val backendId: String) {
    var health = true
    var weight = 1
    var inflight = 0
}

class Simulation {
    private val backends = ArrayList<Backend>()
    private val byId = HashMap<String, Backend>()
    private var cursor = 0
    private val stickyMap = HashMap<String, String>()
    private var useLeast = false

    fun addBackend(backendId: String): String {
        if (byId.containsKey(backendId)) {
            return "false"
        }
        val item = Backend(backendId)
        backends.add(item)
        byId[backendId] = item
        return "true"
    }

    fun setHealth(backendId: String, flag: Int): String {
        val item = byId[backendId]
        if (item == null || (flag != 0 && flag != 1)) {
            return "invalid_request"
        }
        item.health = flag == 1
        resetCycle()
        return "true"
    }

    fun setWeight(backendId: String, weight: Int): String {
        val item = byId[backendId]
        if (item == null || weight <= 0) {
            return "invalid_request"
        }
        item.weight = weight
        resetCycle()
        return "true"
    }

    private fun resetCycle() {
        cursor = 0
        useLeast = false
        for (item in backends) {
            item.inflight = 0
        }
    }

    private fun tickets(items: List<Backend>): List<Backend> {
        val out = ArrayList<Backend>()
        for (item in items) {
            repeat(item.weight) { out.add(item) }
        }
        return out
    }

    private fun pick(): Backend? {
        val healthy = ArrayList<Backend>()
        for (item in backends) {
            if (item.health) {
                healthy.add(item)
            }
        }
        if (healthy.isEmpty()) {
            return null
        }
        var pool = healthy
        if (useLeast) {
            val least = healthy.minOf { it.inflight }
            pool = ArrayList()
            for (item in healthy) {
                if (item.inflight == least) {
                    pool.add(item)
                }
            }
        }
        val ticketList = tickets(pool)
        if (ticketList.isEmpty()) {
            return null
        }
        val chosen = ticketList[cursor % ticketList.size]
        cursor += 1
        return chosen
    }

    private fun take(): String {
        val item = pick() ?: return ""
        item.inflight += 1
        return item.backendId
    }

    fun route(): String {
        return take()
    }

    fun sticky(clientId: String): String {
        val bound = stickyMap[clientId]
        val item = if (bound == null) null else byId[bound]
        if (item != null && item.health) {
            item.inflight += 1
            return item.backendId
        }
        val chosen = take()
        if (chosen.isNotEmpty()) {
            stickyMap[clientId] = chosen
        }
        return chosen
    }

    fun done(backendId: String): String {
        val item = byId[backendId]
        if (item == null || item.inflight <= 0) {
            return "invalid_request"
        }
        item.inflight -= 1
        useLeast = true
        return "true"
    }
}
