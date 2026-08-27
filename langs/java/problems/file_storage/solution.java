import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

class StoredFile {
    String name;
    int size;
    String owner;

    StoredFile(String name, int size, String owner) {
        this.name = name;
        this.size = size;
        this.owner = owner;
    }
}

public class Simulation {
    private final Map<String, StoredFile> files = new LinkedHashMap<>();
    private final Map<String, Integer> capacity = new LinkedHashMap<>();
    private final Map<String, Map<String, Integer>> backups = new LinkedHashMap<>();

    public Simulation() {
        capacity.put("admin", null);
    }

    private int used(String userId) {
        int sum = 0;
        for (StoredFile item : files.values()) {
            if (item.owner.equals(userId)) {
                sum += item.size;
            }
        }
        return sum;
    }

    private Integer remaining(String userId) {
        if (!capacity.containsKey(userId)) {
            return null;
        }
        Integer cap = capacity.get(userId);
        if (cap == null) {
            return null;
        }
        return cap - used(userId);
    }

    public String addFile(String name, int size) {
        if (files.containsKey(name)) {
            return "false";
        }
        files.put(name, new StoredFile(name, size, "admin"));
        return "true";
    }

    public String getFileSize(String name) {
        StoredFile item = files.get(name);
        return item == null ? "" : String.valueOf(item.size);
    }

    public String deleteFile(String name) {
        StoredFile item = files.remove(name);
        return item == null ? "" : String.valueOf(item.size);
    }

    public String getNLargest(String prefix, int n) {
        List<StoredFile> matched = new ArrayList<>();
        for (StoredFile item : files.values()) {
            if (item.name.startsWith(prefix)) {
                matched.add(item);
            }
        }
        matched.sort((a, b) -> {
            int d = Integer.compare(b.size, a.size);
            return d != 0 ? d : a.name.compareTo(b.name);
        });
        if (n < matched.size()) {
            matched = matched.subList(0, n);
        }
        List<String> parts = new ArrayList<>();
        for (StoredFile item : matched) {
            parts.add(item.name + "(" + item.size + ")");
        }
        return String.join(", ", parts);
    }

    public String addUser(String userId, int cap) {
        if (capacity.containsKey(userId)) {
            return "false";
        }
        capacity.put(userId, cap);
        return "true";
    }

    public String addFileBy(String userId, String name, int size) {
        if (!capacity.containsKey(userId) || files.containsKey(name)) {
            return "";
        }
        Integer left = remaining(userId);
        if (left != null && size > left) {
            return "";
        }
        files.put(name, new StoredFile(name, size, userId));
        Integer after = remaining(userId);
        return after == null ? "" : String.valueOf(after);
    }

    public String mergeUser(String userId1, String userId2) {
        if (userId1.equals(userId2)) {
            return "";
        }
        if (!capacity.containsKey(userId1) || !capacity.containsKey(userId2)) {
            return "";
        }
        Integer cap1 = capacity.get(userId1);
        Integer cap2 = capacity.get(userId2);
        if (cap1 == null || cap2 == null) {
            return "";
        }
        capacity.put(userId1, cap1 + cap2);
        for (StoredFile item : files.values()) {
            if (item.owner.equals(userId2)) {
                item.owner = userId1;
            }
        }
        capacity.remove(userId2);
        backups.remove(userId2);
        Integer left = remaining(userId1);
        return left == null ? "" : String.valueOf(left);
    }

    public String backupUser(String userId) {
        if (!capacity.containsKey(userId)) {
            return "";
        }
        Map<String, Integer> snap = new LinkedHashMap<>();
        for (StoredFile item : files.values()) {
            if (item.owner.equals(userId)) {
                snap.put(item.name, item.size);
            }
        }
        backups.put(userId, snap);
        return String.valueOf(snap.size());
    }

    public String restoreUser(String userId) {
        if (!capacity.containsKey(userId)) {
            return "";
        }
        List<String> owned = new ArrayList<>();
        for (StoredFile item : files.values()) {
            if (item.owner.equals(userId)) {
                owned.add(item.name);
            }
        }
        for (String name : owned) {
            files.remove(name);
        }
        Map<String, Integer> snap = backups.get(userId);
        if (snap == null) {
            return "0";
        }
        int restored = 0;
        for (Map.Entry<String, Integer> entry : snap.entrySet()) {
            if (files.containsKey(entry.getKey())) {
                continue;
            }
            Integer left = remaining(userId);
            if (left != null && entry.getValue() > left) {
                continue;
            }
            files.put(entry.getKey(), new StoredFile(entry.getKey(), entry.getValue(), userId));
            restored += 1;
        }
        return String.valueOf(restored);
    }
}
