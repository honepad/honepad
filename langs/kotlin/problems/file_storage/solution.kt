class StoredFile(val name: String, val size: Int, var owner: String)

class Simulation {
    private val files = LinkedHashMap<String, StoredFile>()
    private val capacity = LinkedHashMap<String, Int?>()
    private val backups = LinkedHashMap<String, LinkedHashMap<String, Int>>()

    init {
        capacity["admin"] = null
    }

    private fun used(userId: String): Int {
        var sum = 0
        for (item in files.values) {
            if (item.owner == userId) {
                sum += item.size
            }
        }
        return sum
    }

    private fun remaining(userId: String): Int? {
        if (!capacity.containsKey(userId)) {
            return null
        }
        val cap = capacity[userId] ?: return null
        return cap - used(userId)
    }

    fun addFile(name: String, size: Int): String {
        if (files.containsKey(name)) {
            return "false"
        }
        files[name] = StoredFile(name, size, "admin")
        return "true"
    }

    fun getFileSize(name: String): String {
        val item = files[name] ?: return ""
        return item.size.toString()
    }

    fun deleteFile(name: String): String {
        val item = files.remove(name) ?: return ""
        return item.size.toString()
    }

    fun copyFile(source: String, dest: String): String {
        val src = files[source] ?: return ""
        if (source == dest) {
            return src.size.toString()
        }
        val destItem = files[dest]
        val owner = if (destItem == null) src.owner else destItem.owner
        val extra = if (destItem == null) src.size else src.size - destItem.size
        val left = remaining(owner)
        if (left != null && extra > left) {
            return ""
        }
        if (destItem == null) {
            files[dest] = StoredFile(dest, src.size, owner)
        } else {
            files[dest] = StoredFile(dest, src.size, destItem.owner)
        }
        return src.size.toString()
    }

    fun getNLargest(prefix: String, n: Int): String {
        val matched = ArrayList<StoredFile>()
        for (item in files.values) {
            if (item.name.startsWith(prefix)) {
                matched.add(item)
            }
        }
        matched.sortWith { a, b ->
            val d = b.size.compareTo(a.size)
            if (d != 0) d else a.name.compareTo(b.name)
        }
        val cut = if (n < matched.size) matched.subList(0, n) else matched
        val parts = ArrayList<String>()
        for (item in cut) {
            parts.add(item.name + "(" + item.size + ")")
        }
        return parts.joinToString(", ")
    }

    fun addUser(userId: String, cap: Int): String {
        if (capacity.containsKey(userId)) {
            return "false"
        }
        capacity[userId] = cap
        return "true"
    }

    fun addFileBy(userId: String, name: String, size: Int): String {
        if (!capacity.containsKey(userId) || files.containsKey(name)) {
            return ""
        }
        val left = remaining(userId)
        if (left != null && size > left) {
            return ""
        }
        files[name] = StoredFile(name, size, userId)
        val after = remaining(userId)
        return after?.toString() ?: ""
    }

    fun mergeUser(userId1: String, userId2: String): String {
        if (userId1 == userId2) {
            return ""
        }
        if (!capacity.containsKey(userId1) || !capacity.containsKey(userId2)) {
            return ""
        }
        val cap1 = capacity[userId1]
        val cap2 = capacity[userId2]
        if (cap1 == null || cap2 == null) {
            return ""
        }
        capacity[userId1] = cap1 + cap2
        for (item in files.values) {
            if (item.owner == userId2) {
                item.owner = userId1
            }
        }
        capacity.remove(userId2)
        backups.remove(userId2)
        val left = remaining(userId1)
        return left?.toString() ?: ""
    }

    fun backupUser(userId: String): String {
        if (!capacity.containsKey(userId)) {
            return ""
        }
        val snap = LinkedHashMap<String, Int>()
        for (item in files.values) {
            if (item.owner == userId) {
                snap[item.name] = item.size
            }
        }
        backups[userId] = snap
        return snap.size.toString()
    }

    fun restoreUser(userId: String): String {
        if (!capacity.containsKey(userId)) {
            return ""
        }
        val owned = ArrayList<String>()
        for (item in files.values) {
            if (item.owner == userId) {
                owned.add(item.name)
            }
        }
        for (name in owned) {
            files.remove(name)
        }
        val snap = backups[userId] ?: return "0"
        var restored = 0
        for ((name, size) in snap) {
            if (files.containsKey(name)) {
                continue
            }
            val left = remaining(userId)
            if (left != null && size > left) {
                continue
            }
            files[name] = StoredFile(name, size, userId)
            restored += 1
        }
        return restored.toString()
    }
}
