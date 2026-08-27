class Simulation {
    private final Map<String, StoredFile> files = new LinkedHashMap<>()
    private final Map<String, Long> capacity = new LinkedHashMap<>()
    private final Map<String, Map<String, Long>> backups = new LinkedHashMap<>()

    Simulation() {
        capacity['admin'] = null
    }

    private long used(String userId) {
        long sum = 0
        files.values().each { item ->
            if (item.owner == userId) {
                sum += item.size
            }
        }
        return sum
    }

    private Long remaining(String userId) {
        if (!capacity.containsKey(userId)) {
            return null
        }
        Long cap = capacity[userId]
        if (cap == null) {
            return null
        }
        return cap - used(userId)
    }

    String addFile(String name, long size) {
        if (files.containsKey(name)) {
            return 'false'
        }
        files[name] = new StoredFile(name, size, 'admin')
        return 'true'
    }

    String getFileSize(String name) {
        StoredFile item = files[name]
        return item == null ? '' : String.valueOf(item.size)
    }

    String deleteFile(String name) {
        StoredFile item = files.remove(name)
        return item == null ? '' : String.valueOf(item.size)
    }

    String getNLargest(String prefix, long n) {
        List<StoredFile> matched = files.values().findAll { it.name.startsWith(prefix) }
        matched.sort { a, b ->
            int d = Long.compare(b.size, a.size)
            d != 0 ? d : a.name <=> b.name
        }
        int limit = Math.min(n as int, matched.size())
        matched.subList(0, limit).collect { item -> "${item.name}(${item.size})" }.join(', ')
    }

    String addUser(String userId, long cap) {
        if (capacity.containsKey(userId)) {
            return 'false'
        }
        capacity[userId] = cap
        return 'true'
    }

    String addFileBy(String userId, String name, long size) {
        if (!capacity.containsKey(userId) || files.containsKey(name)) {
            return ''
        }
        Long left = remaining(userId)
        if (left != null && size > left) {
            return ''
        }
        files[name] = new StoredFile(name, size, userId)
        Long after = remaining(userId)
        return after == null ? '' : String.valueOf(after)
    }

    String mergeUser(String userId1, String userId2) {
        if (userId1 == userId2) {
            return ''
        }
        if (!capacity.containsKey(userId1) || !capacity.containsKey(userId2)) {
            return ''
        }
        Long cap1 = capacity[userId1]
        Long cap2 = capacity[userId2]
        if (cap1 == null || cap2 == null) {
            return ''
        }
        capacity[userId1] = cap1 + cap2
        files.values().each { item ->
            if (item.owner == userId2) {
                item.owner = userId1
            }
        }
        capacity.remove(userId2)
        backups.remove(userId2)
        Long left = remaining(userId1)
        return left == null ? '' : String.valueOf(left)
    }

    String backupUser(String userId) {
        if (!capacity.containsKey(userId)) {
            return ''
        }
        Map<String, Long> snap = new LinkedHashMap<>()
        files.values().each { item ->
            if (item.owner == userId) {
                snap[item.name] = item.size
            }
        }
        backups[userId] = snap
        return String.valueOf(snap.size())
    }

    String restoreUser(String userId) {
        if (!capacity.containsKey(userId)) {
            return ''
        }
        List<String> owned = files.values().findAll { it.owner == userId }.collect { it.name }
        owned.each { files.remove(it) }
        Map<String, Long> snap = backups[userId]
        if (snap == null) {
            return '0'
        }
        int restored = 0
        snap.each { name, size ->
            if (files.containsKey(name)) {
                return
            }
            Long left = remaining(userId)
            if (left != null && size > left) {
                return
            }
            files[name] = new StoredFile(name, size, userId)
            restored += 1
        }
        return String.valueOf(restored)
    }
}

class StoredFile {
    String name
    long size
    String owner

    StoredFile(String name, long size, String owner) {
        this.name = name
        this.size = size
        this.owner = owner
    }
}
