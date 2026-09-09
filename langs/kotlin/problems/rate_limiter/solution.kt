class KeyState(
    var limit: Int = 3,
    var window: Int = 10,
    var windowId: Int? = null,
    var used: Int = 0,
)

class Simulation {
    private val keys = HashMap<String, KeyState>()

    private fun state(key: String): KeyState {
        return keys.getOrPut(key) { KeyState() }
    }

    private fun usedAt(item: KeyState, timestamp: Int, persist: Boolean): Int {
        val windowId = timestamp / item.window
        if (item.windowId == null || windowId != item.windowId) {
            if (persist) {
                item.windowId = windowId
                item.used = 0
            }
            return 0
        }
        return item.used
    }

    fun allow(key: String, timestamp: Int): String {
        return allowWeighted(key, 1, timestamp)
    }

    fun configure(key: String, limit: Int, window: Int): String {
        if (limit <= 0 || window <= 0) {
            return "invalid_request"
        }
        val item = state(key)
        item.limit = limit
        item.window = window
        item.windowId = null
        item.used = 0
        return "true"
    }

    fun remaining(key: String, timestamp: Int): String {
        val item = state(key)
        val used = usedAt(item, timestamp, false)
        return (item.limit - used).toString()
    }

    fun allowWeighted(key: String, cost: Int, timestamp: Int): String {
        if (cost <= 0) {
            return "invalid_request"
        }
        val item = state(key)
        usedAt(item, timestamp, true)
        if (item.used + cost > item.limit) {
            return "false"
        }
        item.used += cost
        return "true"
    }
}
