import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

class FieldVal {
    String value;
    Integer expiry;

    FieldVal(String value, Integer expiry) {
        this.value = value;
        this.expiry = expiry;
    }
}

class BackupField {
    String value;
    Integer remaining;

    BackupField(String value, Integer remaining) {
        this.value = value;
        this.remaining = remaining;
    }
}

public class InMemoryDatabase {
    private final Map<String, Map<String, FieldVal>> database = new LinkedHashMap<>();
    private final List<Integer> backupTimestamps = new ArrayList<>();
    private final List<Map<String, Map<String, BackupField>>> backupStates = new ArrayList<>();

    public InMemoryDatabase() {}

    private String setInternal(String key, String field, String value, Integer expiry) {
        database.computeIfAbsent(key, ignored -> new LinkedHashMap<>()).put(field, new FieldVal(value, expiry));
        return "";
    }

    private boolean isAlive(String key, String field, int timestamp) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null || !fields.containsKey(field)) {
            return false;
        }
        Integer expiry = fields.get(field).expiry;
        return expiry == null || timestamp < expiry;
    }

    public String set(String key, String field, String value) {
        return setInternal(key, field, value, null);
    }

    public String get(String key, String field) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null || !fields.containsKey(field)) {
            return "";
        }
        return fields.get(field).value;
    }

    public String delete(String key, String field) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null || !fields.containsKey(field)) {
            return "false";
        }
        fields.remove(field);
        return "true";
    }

    public String scan(String key) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null) {
            return "";
        }
        List<String> names = new ArrayList<>(fields.keySet());
        Collections.sort(names);
        List<String> parts = new ArrayList<>();
        for (String field : names) {
            parts.add(field + "(" + fields.get(field).value + ")");
        }
        return String.join(", ", parts);
    }

    public String scanByPrefix(String key, String prefix) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null) {
            return "";
        }
        List<String> names = new ArrayList<>();
        for (String field : fields.keySet()) {
            if (field.startsWith(prefix)) {
                names.add(field);
            }
        }
        Collections.sort(names);
        List<String> parts = new ArrayList<>();
        for (String field : names) {
            parts.add(field + "(" + fields.get(field).value + ")");
        }
        return String.join(", ", parts);
    }

    public String setAt(String key, String field, String value, int timestamp) {
        return setInternal(key, field, value, null);
    }

    public String setAtWithTtl(String key, String field, String value, int timestamp, int ttl) {
        return setInternal(key, field, value, timestamp + ttl);
    }

    public String deleteAt(String key, String field, int timestamp) {
        if (!isAlive(key, field, timestamp)) {
            return "false";
        }
        database.get(key).remove(field);
        return "true";
    }

    public String getAt(String key, String field, int timestamp) {
        if (!isAlive(key, field, timestamp)) {
            return "";
        }
        return database.get(key).get(field).value;
    }

    public String scanAt(String key, int timestamp) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null) {
            return "";
        }
        List<String> names = new ArrayList<>();
        for (String field : fields.keySet()) {
            if (isAlive(key, field, timestamp)) {
                names.add(field);
            }
        }
        Collections.sort(names);
        List<String> parts = new ArrayList<>();
        for (String field : names) {
            parts.add(field + "(" + fields.get(field).value + ")");
        }
        return String.join(", ", parts);
    }

    public String scanByPrefixAt(String key, String prefix, int timestamp) {
        Map<String, FieldVal> fields = database.get(key);
        if (fields == null) {
            return "";
        }
        List<String> names = new ArrayList<>();
        for (String field : fields.keySet()) {
            if (field.startsWith(prefix) && isAlive(key, field, timestamp)) {
                names.add(field);
            }
        }
        Collections.sort(names);
        List<String> parts = new ArrayList<>();
        for (String field : names) {
            parts.add(field + "(" + fields.get(field).value + ")");
        }
        return String.join(", ", parts);
    }

    public String backup(int timestamp) {
        Map<String, Map<String, BackupField>> state = new LinkedHashMap<>();
        for (Map.Entry<String, Map<String, FieldVal>> keyEntry : database.entrySet()) {
            String key = keyEntry.getKey();
            for (Map.Entry<String, FieldVal> fieldEntry : keyEntry.getValue().entrySet()) {
                String field = fieldEntry.getKey();
                if (isAlive(key, field, timestamp)) {
                    FieldVal pair = fieldEntry.getValue();
                    Integer remaining = pair.expiry == null ? null : pair.expiry - timestamp;
                    state.computeIfAbsent(key, ignored -> new LinkedHashMap<>())
                        .put(field, new BackupField(pair.value, remaining));
                }
            }
        }
        backupTimestamps.add(timestamp);
        backupStates.add(state);
        return String.valueOf(state.size());
    }

    public String restore(int timestamp, int timestampToRestore) {
        int idx = -1;
        for (int i = 0; i < backupTimestamps.size(); i++) {
            if (backupTimestamps.get(i) <= timestampToRestore) {
                idx = i;
            }
        }
        Map<String, Map<String, BackupField>> backup = backupStates.get(idx);
        database.clear();
        for (Map.Entry<String, Map<String, BackupField>> keyEntry : backup.entrySet()) {
            for (Map.Entry<String, BackupField> fieldEntry : keyEntry.getValue().entrySet()) {
                BackupField pair = fieldEntry.getValue();
                Integer expiry = pair.remaining == null ? null : timestamp + pair.remaining;
                setInternal(keyEntry.getKey(), fieldEntry.getKey(), pair.value, expiry);
            }
        }
        return "";
    }
}
