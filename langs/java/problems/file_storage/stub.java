public class Simulation {
    public Simulation() {}

    /**
     * Admin add. Returns {@code "true"} if created, {@code "false"} if
     * the name exists.
     */
    public String addFile(String name, int size) {
        return "";
    }

    /**
     * Returns the size as a string, or {@code ""} if missing.
     */
    public String getFileSize(String name) {
        return "";
    }

    /**
     * Returns the deleted size as a string, or {@code ""} if missing.
     */
    public String deleteFile(String name) {
        return "";
    }

    /**
     * Copy size to dest. Returns dest size, or {@code ""} if source is
     * missing or the dest owner is over capacity.
     */
    public String copyFile(String source, String dest) {
        return "";
    }

    /**
     * Up to n files as {@code name(size), ...}. Empty string if none.
     * Example: {@code "/dir/file2(20), /dir/deeper/file3.mov(9)"}.
     */
    public String getNLargest(String prefix, int n) {
        return "";
    }

    /**
     * Create a user. Returns {@code "true"}, or {@code "false"} if the
     * id exists.
     */
    public String addUser(String userId, int capacity) {
        return "";
    }

    /**
     * Store a file as that user. Returns remaining capacity, or
     * {@code ""} if missing, name taken, or over capacity.
     */
    public String addFileBy(String userId, String name, int size) {
        return "";
    }

    /**
     * Merge {@code userId2} into {@code userId1}, then delete
     * {@code userId2}. Returns remaining capacity of {@code userId1},
     * or {@code ""}.
     */
    public String mergeUser(String userId1, String userId2) {
        return "";
    }

    /**
     * Snapshot that user's files. Returns the file count, or {@code ""}
     * if missing.
     */
    public String backupUser(String userId) {
        return "";
    }

    /**
     * Restore the latest backup. Returns the count, {@code "0"} if none,
     * or {@code ""} if missing.
     */
    public String restoreUser(String userId) {
        return "";
    }
}
