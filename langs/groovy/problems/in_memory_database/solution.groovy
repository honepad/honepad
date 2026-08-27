class InMemoryDatabase {
    private final Map<String, Map<String, FieldVal>> database = new LinkedHashMap<>()
    private final List<Long> backupTimestamps = []
    private final List<Map<String, Map<String, BackupField>>> backupStates = []

    private String setInternal(String key, String field, String value, Long expiry) {
        database.computeIfAbsent(key) { new LinkedHashMap<>() }[field] = new FieldVal(value, expiry)
        return ''
    }

    private boolean isAlive(String key, String field, long timestamp) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null || !fields.containsKey(field)) {
            return false
        }
        Long expiry = fields[field].expiry
        return expiry == null || timestamp < expiry
    }

    String set(String key, String field, String value) {
        setInternal(key, field, value, null)
    }

    String get(String key, String field) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null || !fields.containsKey(field)) {
            return ''
        }
        return fields[field].value
    }

    String delete(String key, String field) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null || !fields.containsKey(field)) {
            return 'false'
        }
        fields.remove(field)
        return 'true'
    }

    private String formatFields(Map<String, FieldVal> fields, List<String> names) {
        names.sort()
        List<String> parts = []
        names.each { field ->
            parts.add("${field}(${fields[field].value})".toString())
        }
        return parts.join(', ')
    }

    String scan(String key) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null) {
            return ''
        }
        formatFields(fields, new ArrayList<>(fields.keySet()))
    }

    String scanByPrefix(String key, String prefix) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null) {
            return ''
        }
        List<String> names = new ArrayList<>()
        fields.keySet().each { field ->
            if (field.startsWith(prefix)) {
                names.add(field)
            }
        }
        formatFields(fields, names)
    }

    String setAt(String key, String field, String value, long timestamp) {
        setInternal(key, field, value, null)
    }

    String setAtWithTtl(String key, String field, String value, long timestamp, long ttl) {
        setInternal(key, field, value, timestamp + ttl)
    }

    String deleteAt(String key, String field, long timestamp) {
        if (!isAlive(key, field, timestamp)) {
            return 'false'
        }
        database[key].remove(field)
        return 'true'
    }

    String getAt(String key, String field, long timestamp) {
        if (!isAlive(key, field, timestamp)) {
            return ''
        }
        return database[key][field].value
    }

    String scanAt(String key, long timestamp) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null) {
            return ''
        }
        List<String> names = new ArrayList<>()
        fields.keySet().each { field ->
            if (isAlive(key, field, timestamp)) {
                names.add(field)
            }
        }
        formatFields(fields, names)
    }

    String scanByPrefixAt(String key, String prefix, long timestamp) {
        Map<String, FieldVal> fields = database[key]
        if (fields == null) {
            return ''
        }
        List<String> names = new ArrayList<>()
        fields.keySet().each { field ->
            if (field.startsWith(prefix) && isAlive(key, field, timestamp)) {
                names.add(field)
            }
        }
        formatFields(fields, names)
    }

    String backup(long timestamp) {
        Map<String, Map<String, BackupField>> state = new LinkedHashMap<>()
        database.each { key, fields ->
            fields.each { field, pair ->
                if (isAlive(key, field, timestamp)) {
                    Long remaining = pair.expiry == null ? null : pair.expiry - timestamp
                    state.computeIfAbsent(key) { new LinkedHashMap<>() }[field] =
                        new BackupField(pair.value, remaining)
                }
            }
        }
        backupTimestamps.add(timestamp)
        backupStates.add(state)
        return String.valueOf(state.size())
    }

    String restore(long timestamp, long timestampToRestore) {
        int idx = -1
        for (int i = 0; i < backupTimestamps.size(); i++) {
            if (backupTimestamps[i] <= timestampToRestore) {
                idx = i
            }
        }
        Map<String, Map<String, BackupField>> backup = backupStates[idx]
        database.clear()
        backup.each { key, fields ->
            fields.each { field, pair ->
                Long expiry = pair.remaining == null ? null : timestamp + pair.remaining
                setInternal(key, field, pair.value, expiry)
            }
        }
        return ''
    }
}

class FieldVal {
    String value
    Long expiry

    FieldVal(String value, Long expiry) {
        this.value = value
        this.expiry = expiry
    }
}

class BackupField {
    String value
    Long remaining

    BackupField(String value, Long remaining) {
        this.value = value
        this.remaining = remaining
    }
}
