class FieldVal(val value: String, val expiry: Int?)

class BackupField(val value: String, val remaining: Int?)

class InMemoryDatabase {
    private val database = LinkedHashMap<String, LinkedHashMap<String, FieldVal>>()
    private val backupTimestamps = ArrayList<Int>()
    private val backupStates = ArrayList<LinkedHashMap<String, LinkedHashMap<String, BackupField>>>()

    private fun setInternal(key: String, field: String, value: String, expiry: Int?): String {
        database.getOrPut(key) { LinkedHashMap() }[field] = FieldVal(value, expiry)
        return ""
    }

    private fun isAlive(key: String, field: String, timestamp: Int): Boolean {
        val fields = database[key] ?: return false
        val pair = fields[field] ?: return false
        val expiry = pair.expiry
        return expiry == null || timestamp < expiry
    }

    fun set(key: String, field: String, value: String): String {
        return setInternal(key, field, value, null)
    }

    fun get(key: String, field: String): String {
        val fields = database[key] ?: return ""
        val pair = fields[field] ?: return ""
        return pair.value
    }

    fun delete(key: String, field: String): String {
        val fields = database[key] ?: return "false"
        if (!fields.containsKey(field)) {
            return "false"
        }
        fields.remove(field)
        return "true"
    }

    fun scan(key: String): String {
        val fields = database[key] ?: return ""
        val names = ArrayList(fields.keys)
        names.sort()
        val parts = ArrayList<String>()
        for (field in names) {
            parts.add(field + "(" + fields[field]!!.value + ")")
        }
        return parts.joinToString(", ")
    }

    fun scanByPrefix(key: String, prefix: String): String {
        val fields = database[key] ?: return ""
        val names = ArrayList<String>()
        for (field in fields.keys) {
            if (field.startsWith(prefix)) {
                names.add(field)
            }
        }
        names.sort()
        val parts = ArrayList<String>()
        for (field in names) {
            parts.add(field + "(" + fields[field]!!.value + ")")
        }
        return parts.joinToString(", ")
    }

    fun setAt(key: String, field: String, value: String, timestamp: Int): String {
        return setInternal(key, field, value, null)
    }

    fun setAtWithTtl(key: String, field: String, value: String, timestamp: Int, ttl: Int): String {
        return setInternal(key, field, value, timestamp + ttl)
    }

    fun deleteAt(key: String, field: String, timestamp: Int): String {
        if (!isAlive(key, field, timestamp)) {
            return "false"
        }
        database[key]!!.remove(field)
        return "true"
    }

    fun getAt(key: String, field: String, timestamp: Int): String {
        if (!isAlive(key, field, timestamp)) {
            return ""
        }
        return database[key]!![field]!!.value
    }

    fun scanAt(key: String, timestamp: Int): String {
        val fields = database[key] ?: return ""
        val names = ArrayList<String>()
        for (field in fields.keys) {
            if (isAlive(key, field, timestamp)) {
                names.add(field)
            }
        }
        names.sort()
        val parts = ArrayList<String>()
        for (field in names) {
            parts.add(field + "(" + fields[field]!!.value + ")")
        }
        return parts.joinToString(", ")
    }

    fun scanByPrefixAt(key: String, prefix: String, timestamp: Int): String {
        val fields = database[key] ?: return ""
        val names = ArrayList<String>()
        for (field in fields.keys) {
            if (field.startsWith(prefix) && isAlive(key, field, timestamp)) {
                names.add(field)
            }
        }
        names.sort()
        val parts = ArrayList<String>()
        for (field in names) {
            parts.add(field + "(" + fields[field]!!.value + ")")
        }
        return parts.joinToString(", ")
    }

    fun backup(timestamp: Int): String {
        val state = LinkedHashMap<String, LinkedHashMap<String, BackupField>>()
        for ((key, fields) in database) {
            for ((field, pair) in fields) {
                if (isAlive(key, field, timestamp)) {
                    val remaining = if (pair.expiry == null) null else pair.expiry - timestamp
                    state.getOrPut(key) { LinkedHashMap() }[field] = BackupField(pair.value, remaining)
                }
            }
        }
        backupTimestamps.add(timestamp)
        backupStates.add(state)
        return state.size.toString()
    }

    fun restore(timestamp: Int, timestampToRestore: Int): String {
        var idx = -1
        for (i in backupTimestamps.indices) {
            if (backupTimestamps[i] <= timestampToRestore) {
                idx = i
            }
        }
        val backup = backupStates[idx]
        database.clear()
        for ((key, fields) in backup) {
            for ((field, pair) in fields) {
                val expiry = if (pair.remaining == null) null else timestamp + pair.remaining
                setInternal(key, field, pair.value, expiry)
            }
        }
        return ""
    }
}
