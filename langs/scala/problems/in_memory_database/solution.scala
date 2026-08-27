import java.util.{ArrayList, Collections, LinkedHashMap, List => JList, Map => JMap}

class FieldVal(var value: String, var expiry: Integer)

class BackupField(var value: String, var remaining: Integer)

class InMemoryDatabase {
  private val database: JMap[String, JMap[String, FieldVal]] =
    new LinkedHashMap[String, JMap[String, FieldVal]]()
  private val backupTimestamps: JList[Integer] = new ArrayList[Integer]()
  private val backupStates: JList[JMap[String, JMap[String, BackupField]]] =
    new ArrayList[JMap[String, JMap[String, BackupField]]]()

  private def setInternal(key: String, field: String, value: String, expiry: Integer): String = {
    var fields = database.get(key)
    if (fields == null) {
      fields = new LinkedHashMap[String, FieldVal]()
      database.put(key, fields)
    }
    fields.put(field, new FieldVal(value, expiry))
    ""
  }

  private def isAlive(key: String, field: String, timestamp: Int): Boolean = {
    val fields = database.get(key)
    if (fields == null || !fields.containsKey(field)) {
      return false
    }
    val expiry = fields.get(field).expiry
    expiry == null || timestamp < expiry.intValue()
  }

  def set(key: String, field: String, value: String): String = {
    setInternal(key, field, value, null)
  }

  def get(key: String, field: String): String = {
    val fields = database.get(key)
    if (fields == null || !fields.containsKey(field)) {
      return ""
    }
    fields.get(field).value
  }

  def delete(key: String, field: String): String = {
    val fields = database.get(key)
    if (fields == null || !fields.containsKey(field)) {
      return "false"
    }
    fields.remove(field)
    "true"
  }

  def scan(key: String): String = {
    val fields = database.get(key)
    if (fields == null) {
      return ""
    }
    val names = new ArrayList[String](fields.keySet())
    Collections.sort(names)
    val parts = new ArrayList[String]()
    var i = 0
    while (i < names.size()) {
      val field = names.get(i)
      parts.add(field + "(" + fields.get(field).value + ")")
      i += 1
    }
    String.join(", ", parts)
  }

  def scanByPrefix(key: String, prefix: String): String = {
    val fields = database.get(key)
    if (fields == null) {
      return ""
    }
    val names = new ArrayList[String]()
    val it = fields.keySet().iterator()
    while (it.hasNext) {
      val field = it.next()
      if (field.startsWith(prefix)) {
        names.add(field)
      }
    }
    Collections.sort(names)
    val parts = new ArrayList[String]()
    var i = 0
    while (i < names.size()) {
      val field = names.get(i)
      parts.add(field + "(" + fields.get(field).value + ")")
      i += 1
    }
    String.join(", ", parts)
  }

  def setAt(key: String, field: String, value: String, timestamp: Int): String = {
    setInternal(key, field, value, null)
  }

  def setAtWithTtl(key: String, field: String, value: String, timestamp: Int, ttl: Int): String = {
    setInternal(key, field, value, Int.box(timestamp + ttl))
  }

  def deleteAt(key: String, field: String, timestamp: Int): String = {
    if (!isAlive(key, field, timestamp)) {
      return "false"
    }
    database.get(key).remove(field)
    "true"
  }

  def getAt(key: String, field: String, timestamp: Int): String = {
    if (!isAlive(key, field, timestamp)) {
      return ""
    }
    database.get(key).get(field).value
  }

  def scanAt(key: String, timestamp: Int): String = {
    val fields = database.get(key)
    if (fields == null) {
      return ""
    }
    val names = new ArrayList[String]()
    val it = fields.keySet().iterator()
    while (it.hasNext) {
      val field = it.next()
      if (isAlive(key, field, timestamp)) {
        names.add(field)
      }
    }
    Collections.sort(names)
    val parts = new ArrayList[String]()
    var i = 0
    while (i < names.size()) {
      val field = names.get(i)
      parts.add(field + "(" + fields.get(field).value + ")")
      i += 1
    }
    String.join(", ", parts)
  }

  def scanByPrefixAt(key: String, prefix: String, timestamp: Int): String = {
    val fields = database.get(key)
    if (fields == null) {
      return ""
    }
    val names = new ArrayList[String]()
    val it = fields.keySet().iterator()
    while (it.hasNext) {
      val field = it.next()
      if (field.startsWith(prefix) && isAlive(key, field, timestamp)) {
        names.add(field)
      }
    }
    Collections.sort(names)
    val parts = new ArrayList[String]()
    var i = 0
    while (i < names.size()) {
      val field = names.get(i)
      parts.add(field + "(" + fields.get(field).value + ")")
      i += 1
    }
    String.join(", ", parts)
  }

  def backup(timestamp: Int): String = {
    val state = new LinkedHashMap[String, JMap[String, BackupField]]()
    val keyIt = database.entrySet().iterator()
    while (keyIt.hasNext) {
      val keyEntry = keyIt.next()
      val key = keyEntry.getKey
      val fieldIt = keyEntry.getValue.entrySet().iterator()
      while (fieldIt.hasNext) {
        val fieldEntry = fieldIt.next()
        val field = fieldEntry.getKey
        if (isAlive(key, field, timestamp)) {
          val pair = fieldEntry.getValue
          val remaining = if (pair.expiry == null) null else Int.box(pair.expiry.intValue() - timestamp)
          var fields = state.get(key)
          if (fields == null) {
            fields = new LinkedHashMap[String, BackupField]()
            state.put(key, fields)
          }
          fields.put(field, new BackupField(pair.value, remaining))
        }
      }
    }
    backupTimestamps.add(Int.box(timestamp))
    backupStates.add(state)
    String.valueOf(state.size())
  }

  def restore(timestamp: Int, timestampToRestore: Int): String = {
    var idx = -1
    var i = 0
    while (i < backupTimestamps.size()) {
      if (backupTimestamps.get(i).intValue() <= timestampToRestore) {
        idx = i
      }
      i += 1
    }
    val backup = backupStates.get(idx)
    database.clear()
    val keyIt = backup.entrySet().iterator()
    while (keyIt.hasNext) {
      val keyEntry = keyIt.next()
      val fieldIt = keyEntry.getValue.entrySet().iterator()
      while (fieldIt.hasNext) {
        val fieldEntry = fieldIt.next()
        val pair = fieldEntry.getValue
        val expiry = if (pair.remaining == null) null else Int.box(timestamp + pair.remaining.intValue())
        setInternal(keyEntry.getKey, fieldEntry.getKey, pair.value, expiry)
      }
    }
    ""
  }
}
