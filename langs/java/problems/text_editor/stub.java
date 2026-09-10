public class Simulation {
    public Simulation() {}

    /**
     * Insert at pos. New length, or {@code invalid_request}.
     */
    public String insert(int pos, String text) {
        return "";
    }

    /**
     * Deleted substring, or {@code invalid_request}.
     */
    public String erase(int pos, int n) {
        return "";
    }

    /**
     * Full buffer.
     */
    public String getText() {
        return "";
    }

    /**
     * Length as a string.
     */
    public String length() {
        return "";
    }

    /**
     * Set cursor. {@code "true"} or {@code invalid_request}.
     */
    public String move(int pos) {
        return "";
    }

    /**
     * Insert at cursor and advance. New length.
     */
    public String typeText(String text) {
        return "";
    }

    /**
     * Current position as a string.
     */
    public String cursor() {
        return "";
    }

    /**
     * Revert last insert/erase/typeText. {@code "true"} or {@code "false"}.
     */
    public String undo() {
        return "";
    }

    /**
     * Reapply an undone op. {@code "true"} or {@code "false"}.
     */
    public String redo() {
        return "";
    }

    /**
     * Mark {@code [start, end)}. {@code "true"} or {@code invalid_request}.
     */
    public String select(int start, int end) {
        return "";
    }

    /**
     * Delete selection onto clipboard, or {@code invalid_request}.
     */
    public String cut() {
        return "";
    }

    /**
     * Copy selection onto clipboard, or {@code invalid_request}.
     */
    public String copySel() {
        return "";
    }

    /**
     * Insert clipboard at cursor. New length, or {@code invalid_request}.
     */
    public String paste() {
        return "";
    }
}
