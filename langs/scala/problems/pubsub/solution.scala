import java.util.{ArrayList, Collections, LinkedHashMap, List => JList, Map => JMap}

class Simulation {
  private val subs: JMap[String, JList[String]] = new LinkedHashMap[String, JList[String]]()
  private val inboxMap: JMap[String, JList[String]] = new LinkedHashMap[String, JList[String]]()
  private val retained: JMap[String, String] = new LinkedHashMap[String, String]()

  def subscribe(topic: String, client: String): String = {
    var clients = subs.get(topic)
    if (clients == null) {
      clients = new ArrayList[String]()
      subs.put(topic, clients)
    }
    if (clients.contains(client)) {
      return "false"
    }
    clients.add(client)
    val message = retained.get(topic)
    if (message != null) {
      var items = inboxMap.get(client)
      if (items == null) {
        items = new ArrayList[String]()
        inboxMap.put(client, items)
      }
      items.add(topic + ":" + message)
    }
    "true"
  }

  def unsubscribe(topic: String, client: String): String = {
    val clients = subs.get(topic)
    if (clients == null || !clients.contains(client)) {
      return "false"
    }
    clients.remove(client)
    if (clients.isEmpty) {
      subs.remove(topic)
    }
    "true"
  }

  def publish(topic: String, message: String): String = {
    val clients = subs.get(topic)
    if (clients == null) {
      return "0"
    }
    val payload = topic + ":" + message
    val it = clients.iterator()
    while (it.hasNext) {
      val client = it.next()
      var items = inboxMap.get(client)
      if (items == null) {
        items = new ArrayList[String]()
        inboxMap.put(client, items)
      }
      items.add(payload)
    }
    String.valueOf(clients.size())
  }

  def inbox(client: String): String = {
    val items = inboxMap.get(client)
    if (items == null) "" else String.join(", ", items)
  }

  def listTopics(): String = {
    val topics = new ArrayList[String](subs.keySet())
    Collections.sort(topics)
    String.join(", ", topics)
  }

  def subscribers(topic: String): String = {
    val clients = subs.get(topic)
    if (clients == null) {
      return ""
    }
    val ordered = new ArrayList[String](clients)
    Collections.sort(ordered)
    String.join(", ", ordered)
  }

  def peek(client: String): String = {
    val items = inboxMap.get(client)
    if (items == null || items.isEmpty) "" else items.get(0)
  }

  def ack(client: String, n: Int): String = {
    val items = inboxMap.get(client)
    if (n <= 0 || items == null) {
      return "invalid_request"
    }
    if (n > items.size()) {
      return "invalid_request"
    }
    items.subList(0, n).clear()
    String.valueOf(items.size())
  }

  def retain(topic: String, message: String): String = {
    retained.put(topic, message)
    ""
  }
}
