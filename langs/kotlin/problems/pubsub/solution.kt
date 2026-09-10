class Simulation {
    private val subs = LinkedHashMap<String, ArrayList<String>>()
    private val inboxMap = LinkedHashMap<String, ArrayList<String>>()
    private val retained = LinkedHashMap<String, String>()

    fun subscribe(topic: String, client: String): String {
        val clients = subs.getOrPut(topic) { ArrayList() }
        if (clients.contains(client)) {
            return "false"
        }
        clients.add(client)
        val message = retained[topic]
        if (message != null) {
            inboxMap.getOrPut(client) { ArrayList() }.add("$topic:$message")
        }
        return "true"
    }

    fun unsubscribe(topic: String, client: String): String {
        val clients = subs[topic]
        if (clients == null || !clients.contains(client)) {
            return "false"
        }
        clients.remove(client)
        if (clients.isEmpty()) {
            subs.remove(topic)
        }
        return "true"
    }

    fun publish(topic: String, message: String): String {
        val clients = subs[topic] ?: return "0"
        val payload = "$topic:$message"
        for (client in clients) {
            inboxMap.getOrPut(client) { ArrayList() }.add(payload)
        }
        return clients.size.toString()
    }

    fun inbox(client: String): String {
        return inboxMap[client]?.joinToString(", ") ?: ""
    }

    fun listTopics(): String {
        return subs.keys.sorted().joinToString(", ")
    }

    fun subscribers(topic: String): String {
        return (subs[topic] ?: emptyList()).sorted().joinToString(", ")
    }

    fun peek(client: String): String {
        val items = inboxMap[client]
        return if (items.isNullOrEmpty()) "" else items[0]
    }

    fun ack(client: String, n: Int): String {
        val items = inboxMap[client]
        if (n <= 0 || items == null) {
            return "invalid_request"
        }
        if (n > items.size) {
            return "invalid_request"
        }
        repeat(n) { items.removeAt(0) }
        return items.size.toString()
    }

    fun retain(topic: String, message: String): String {
        retained[topic] = message
        return ""
    }
}
