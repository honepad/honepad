import java.util.{HashMap, Map => JMap}

class KeyState(
    var limit: Int = 3,
    var window: Int = 10,
    var windowId: Integer = null,
    var used: Int = 0
)

class Simulation {
  private val keys: JMap[String, KeyState] = new HashMap[String, KeyState]()

  private def state(key: String): KeyState = {
    var item = keys.get(key)
    if (item == null) {
      item = new KeyState()
      keys.put(key, item)
    }
    item
  }

  private def usedAt(item: KeyState, timestamp: Int, persist: Boolean): Int = {
    val windowId = timestamp / item.window
    if (item.windowId == null || windowId != item.windowId.intValue) {
      if (persist) {
        item.windowId = Integer.valueOf(windowId)
        item.used = 0
      }
      return 0
    }
    item.used
  }

  def allow(key: String, timestamp: Int): String = {
    allowWeighted(key, 1, timestamp)
  }

  def configure(key: String, limit: Int, window: Int): String = {
    if (limit <= 0 || window <= 0) {
      return "invalid_request"
    }
    val item = state(key)
    item.limit = limit
    item.window = window
    item.windowId = null
    item.used = 0
    "true"
  }

  def remaining(key: String, timestamp: Int): String = {
    val item = state(key)
    val used = usedAt(item, timestamp, persist = false)
    String.valueOf(item.limit - used)
  }

  def allowWeighted(key: String, cost: Int, timestamp: Int): String = {
    if (cost <= 0) {
      return "invalid_request"
    }
    val item = state(key)
    usedAt(item, timestamp, persist = true)
    if (item.used + cost > item.limit) {
      return "false"
    }
    item.used += cost
    "true"
  }
}
