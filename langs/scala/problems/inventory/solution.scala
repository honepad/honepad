import java.util.{ArrayList, LinkedHashMap, List => JList, Map => JMap}

class Item(var sku: String, var name: String, var qty: Int = 0, var reserved: Int = 0)

class Simulation {
  private val items: JMap[String, Item] = new LinkedHashMap[String, Item]()

  def createItem(sku: String, name: String): String = {
    if (items.containsKey(sku)) {
      return "false"
    }
    items.put(sku, new Item(sku, name))
    "true"
  }

  def stock(sku: String, delta: Int): String = {
    val item = items.get(sku)
    if (item == null) {
      return ""
    }
    val nxt = item.qty + delta
    if (nxt < item.reserved) {
      return "invalid_request"
    }
    item.qty = nxt
    String.valueOf(item.qty)
  }

  def getQty(sku: String): String = {
    val item = items.get(sku)
    if (item == null) "" else String.valueOf(item.qty)
  }

  def listLow(threshold: Int): String = {
    val matched = new ArrayList[Item]()
    val it = items.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.qty <= threshold) {
        matched.add(item)
      }
    }
    matched.sort((a: Item, b: Item) => {
      val d = Integer.compare(a.qty, b.qty)
      if (d != 0) d else a.sku.compareTo(b.sku)
    })
    val parts = new ArrayList[String]()
    val mit = matched.iterator()
    while (mit.hasNext) {
      val item = mit.next()
      parts.add(item.sku + "(" + item.qty + ")")
    }
    String.join(", ", parts)
  }

  def reserve(sku: String, n: Int): String = {
    val item = items.get(sku)
    if (item == null || n <= 0 || item.reserved + n > item.qty) {
      return "invalid_request"
    }
    item.reserved += n
    "true"
  }

  def release(sku: String, n: Int): String = {
    val item = items.get(sku)
    if (item == null || n <= 0 || n > item.reserved) {
      return "invalid_request"
    }
    item.reserved -= n
    "true"
  }

  def ship(sku: String, n: Int): String = {
    val item = items.get(sku)
    if (item == null || n <= 0 || n > item.reserved) {
      return "invalid_request"
    }
    item.reserved -= n
    item.qty -= n
    "true"
  }
}
