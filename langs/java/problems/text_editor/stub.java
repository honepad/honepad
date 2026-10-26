public class Simulation {
    public Simulation() {}

    /**
     * Insert at pos. Does not move the cursor. New length, or
     * {@code invalid_request}.
     */
    public String insert(int pos, String text) {
        return "";
    }

    /**
     * Deleted substring. Cursor stays unless it is past the new end.
     * Or {@code invalid_request}.
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
     * Revert last insert, erase, or typeText, and the cursor.
     * {@code "true"} or {@code "false"}.
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
     * Mark {@code [start, end)}. Does not move the cursor.
     * {@code "true"} or {@code invalid_request}.
     */
    public String select(int start, int end) {
        return "";
    }

    /**
     * Delete the selection onto the clipboard, move the cursor to its start,
     * and clear the selection. Not undoable. Empty or missing selection is
     * {@code invalid_request}.
     */
    public String cut() {
        return "";
    }

    /**
     * Copy the selection. Does not move the cursor or clear it.
     * Or {@code invalid_request}.
     */
    public String copySel() {
        return "";
    }

    /**
     * Insert the clipboard at the cursor and advance. Not undoable.
     * New length, or {@code invalid_request}.
     */
    public String paste() {
        return "";
    }
}
