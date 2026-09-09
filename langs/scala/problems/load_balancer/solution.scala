import java.util.{ArrayList, HashMap, Map => JMap}

class Backend(val backendId: String) {
  var health = true
  var weight = 1
  var inflight = 0
}

class Simulation {
  private val backends = new ArrayList[Backend]()
  private val byId: JMap[String, Backend] = new HashMap[String, Backend]()
  private var cursor = 0
  private val stickyMap: JMap[String, String] = new HashMap[String, String]()
  private var useLeast = false

  def addBackend(backendId: String): String = {
    if (byId.containsKey(backendId)) {
      return "false"
    }
    val item = new Backend(backendId)
    backends.add(item)
    byId.put(backendId, item)
    "true"
  }

  def setHealth(backendId: String, flag: Int): String = {
    val item = byId.get(backendId)
    if (item == null || (flag != 0 && flag != 1)) {
      return "invalid_request"
    }
    item.health = flag == 1
    resetCycle()
    "true"
  }

  def setWeight(backendId: String, weight: Int): String = {
    val item = byId.get(backendId)
    if (item == null || weight <= 0) {
      return "invalid_request"
    }
    item.weight = weight
    resetCycle()
    "true"
  }

  private def resetCycle(): Unit = {
    cursor = 0
    useLeast = false
    var i = 0
    while (i < backends.size()) {
      backends.get(i).inflight = 0
      i += 1
    }
  }

  private def tickets(items: ArrayList[Backend]): ArrayList[Backend] = {
    val out = new ArrayList[Backend]()
    var i = 0
    while (i < items.size()) {
      val item = items.get(i)
      var n = 0
      while (n < item.weight) {
        out.add(item)
        n += 1
      }
      i += 1
    }
    out
  }

  private def pick(): Backend = {
    val healthy = new ArrayList[Backend]()
    var i = 0
    while (i < backends.size()) {
      val item = backends.get(i)
      if (item.health) {
        healthy.add(item)
      }
      i += 1
    }
    if (healthy.isEmpty) {
      return null
    }
    var pool = healthy
    if (useLeast) {
      var least = healthy.get(0).inflight
      i = 1
      while (i < healthy.size()) {
        if (healthy.get(i).inflight < least) {
          least = healthy.get(i).inflight
        }
        i += 1
      }
      pool = new ArrayList[Backend]()
      i = 0
      while (i < healthy.size()) {
        val item = healthy.get(i)
        if (item.inflight == least) {
          pool.add(item)
        }
        i += 1
      }
    }
    val ticketList = tickets(pool)
    if (ticketList.isEmpty) {
      return null
    }
    val chosen = ticketList.get(cursor % ticketList.size())
    cursor += 1
    chosen
  }

  private def take(): String = {
    val item = pick()
    if (item == null) {
      return ""
    }
    item.inflight += 1
    item.backendId
  }

  def route(): String = take()

  def sticky(clientId: String): String = {
    val bound = stickyMap.get(clientId)
    val item = if (bound == null) null else byId.get(bound)
    if (item != null && item.health) {
      item.inflight += 1
      return item.backendId
    }
    val chosen = take()
    if (chosen.nonEmpty) {
      stickyMap.put(clientId, chosen)
    }
    chosen
  }

  def done(backendId: String): String = {
    val item = byId.get(backendId)
    if (item == null || item.inflight <= 0) {
      return "invalid_request"
    }
    item.inflight -= 1
    useLeast = true
    "true"
  }
}
