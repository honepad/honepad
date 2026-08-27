public class InMemoryDatabase {
    public InMemoryDatabase() {}

    public String set(String key, String field, String value) {
        return "";
    }

    public String get(String key, String field) {
        return "";
    }

    public String delete(String key, String field) {
        return "";
    }

    public String scan(String key) {
        return "";
    }

    public String scanByPrefix(String key, String prefix) {
        return "";
    }

    public String setAt(String key, String field, String value, int timestamp) {
        return "";
    }

    public String setAtWithTtl(String key, String field, String value, int timestamp, int ttl) {
        return "";
    }

    public String deleteAt(String key, String field, int timestamp) {
        return "";
    }

    public String getAt(String key, String field, int timestamp) {
        return "";
    }

    public String scanAt(String key, int timestamp) {
        return "";
    }

    public String scanByPrefixAt(String key, String prefix, int timestamp) {
        return "";
    }

    public String backup(int timestamp) {
        return "";
    }

    public String restore(int timestamp, int timestampToRestore) {
        return "";
    }
}
