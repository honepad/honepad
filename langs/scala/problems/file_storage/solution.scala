import java.util.{ArrayList, LinkedHashMap, List => JList, Map => JMap}

class StoredFile(var name: String, var size: Int, var owner: String)

class Simulation {
  private val files: JMap[String, StoredFile] = new LinkedHashMap[String, StoredFile]()
  private val capacity: JMap[String, Integer] = new LinkedHashMap[String, Integer]()
  private val backups: JMap[String, JMap[String, Integer]] =
    new LinkedHashMap[String, JMap[String, Integer]]()
  capacity.put("admin", null)

  private def used(userId: String): Int = {
    var sum = 0
    val it = files.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.owner == userId) {
        sum += item.size
      }
    }
    sum
  }

  private def remaining(userId: String): Integer = {
    if (!capacity.containsKey(userId)) {
      return null
    }
    val cap = capacity.get(userId)
    if (cap == null) {
      return null
    }
    Int.box(cap.intValue() - used(userId))
  }

  def addFile(name: String, size: Int): String = {
    if (files.containsKey(name)) {
      return "false"
    }
    files.put(name, new StoredFile(name, size, "admin"))
    "true"
  }

  def getFileSize(name: String): String = {
    val item = files.get(name)
    if (item == null) "" else String.valueOf(item.size)
  }

  def deleteFile(name: String): String = {
    val item = files.remove(name)
    if (item == null) "" else String.valueOf(item.size)
  }

  def copyFile(source: String, dest: String): String = {
    val src = files.get(source)
    if (src == null) {
      return ""
    }
    if (source == dest) {
      return String.valueOf(src.size)
    }
    val destItem = files.get(dest)
    val owner = if (destItem == null) src.owner else destItem.owner
    val extra = if (destItem == null) src.size else src.size - destItem.size
    val left = remaining(owner)
    if (left != null && extra > left.intValue()) {
      return ""
    }
    if (destItem == null) {
      files.put(dest, new StoredFile(dest, src.size, owner))
    } else {
      destItem.size = src.size
    }
    String.valueOf(src.size)
  }

  def getNLargest(prefix: String, n: Int): String = {
    val matched = new ArrayList[StoredFile]()
    val it = files.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.name.startsWith(prefix)) {
        matched.add(item)
      }
    }
    matched.sort((a: StoredFile, b: StoredFile) => {
      val d = Integer.compare(b.size, a.size)
      if (d != 0) d else a.name.compareTo(b.name)
    })
    val sliced = if (n < matched.size()) matched.subList(0, n) else matched
    val parts = new ArrayList[String]()
    val sit = sliced.iterator()
    while (sit.hasNext) {
      val item = sit.next()
      parts.add(item.name + "(" + item.size + ")")
    }
    String.join(", ", parts)
  }

  def addUser(userId: String, cap: Int): String = {
    if (capacity.containsKey(userId)) {
      return "false"
    }
    capacity.put(userId, Int.box(cap))
    "true"
  }

  def addFileBy(userId: String, name: String, size: Int): String = {
    if (!capacity.containsKey(userId) || files.containsKey(name)) {
      return ""
    }
    val left = remaining(userId)
    if (left != null && size > left.intValue()) {
      return ""
    }
    files.put(name, new StoredFile(name, size, userId))
    val after = remaining(userId)
    if (after == null) "" else String.valueOf(after)
  }

  def mergeUser(userId1: String, userId2: String): String = {
    if (userId1 == userId2) {
      return ""
    }
    if (!capacity.containsKey(userId1) || !capacity.containsKey(userId2)) {
      return ""
    }
    val cap1 = capacity.get(userId1)
    val cap2 = capacity.get(userId2)
    if (cap1 == null || cap2 == null) {
      return ""
    }
    capacity.put(userId1, Int.box(cap1.intValue() + cap2.intValue()))
    val it = files.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.owner == userId2) {
        item.owner = userId1
      }
    }
    capacity.remove(userId2)
    backups.remove(userId2)
    val left = remaining(userId1)
    if (left == null) "" else String.valueOf(left)
  }

  def backupUser(userId: String): String = {
    if (!capacity.containsKey(userId)) {
      return ""
    }
    val snap = new LinkedHashMap[String, Integer]()
    val it = files.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.owner == userId) {
        snap.put(item.name, Int.box(item.size))
      }
    }
    backups.put(userId, snap)
    String.valueOf(snap.size())
  }

  def restoreUser(userId: String): String = {
    if (!capacity.containsKey(userId)) {
      return ""
    }
    val owned = new ArrayList[String]()
    val it = files.values().iterator()
    while (it.hasNext) {
      val item = it.next()
      if (item.owner == userId) {
        owned.add(item.name)
      }
    }
    var i = 0
    while (i < owned.size()) {
      files.remove(owned.get(i))
      i += 1
    }
    val snap = backups.get(userId)
    if (snap == null) {
      return "0"
    }
    var restored = 0
    val sit = snap.entrySet().iterator()
    while (sit.hasNext) {
      val entry = sit.next()
      if (!files.containsKey(entry.getKey)) {
        val left = remaining(userId)
        if (left == null || entry.getValue.intValue() <= left.intValue()) {
          files.put(entry.getKey, new StoredFile(entry.getKey, entry.getValue.intValue(), userId))
          restored += 1
        }
      }
    }
    String.valueOf(restored)
  }
}
