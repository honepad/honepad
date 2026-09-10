import java.util.ArrayList;
import java.util.List;

class EditorSnap {
    final String buf;
    final int pos;

    EditorSnap(String buf, int pos) {
        this.buf = buf;
        this.pos = pos;
    }
}

public class Simulation {
    private String buf = "";
    private int pos = 0;
    private final List<EditorSnap> undoStack = new ArrayList<>();
    private final List<EditorSnap> redoStack = new ArrayList<>();
    private int selStart = -1;
    private int selEnd = -1;
    private String clip = "";

    public Simulation() {}

    private void push() {
        undoStack.add(new EditorSnap(buf, pos));
        redoStack.clear();
        selStart = -1;
        selEnd = -1;
    }

    public String insert(int at, String text) {
        if (at < 0 || at > buf.length()) {
            return "invalid_request";
        }
        push();
        buf = buf.substring(0, at) + text + buf.substring(at);
        return String.valueOf(buf.length());
    }

    public String erase(int at, int n) {
        if (n <= 0 || at < 0 || at + n > buf.length()) {
            return "invalid_request";
        }
        push();
        String deleted = buf.substring(at, at + n);
        buf = buf.substring(0, at) + buf.substring(at + n);
        if (pos > buf.length()) {
            pos = buf.length();
        }
        return deleted;
    }

    public String getText() {
        return buf;
    }

    public String length() {
        return String.valueOf(buf.length());
    }

    public String move(int at) {
        if (at < 0 || at > buf.length()) {
            return "invalid_request";
        }
        pos = at;
        return "true";
    }

    public String typeText(String text) {
        push();
        int at = pos;
        buf = buf.substring(0, at) + text + buf.substring(at);
        pos = at + text.length();
        return String.valueOf(buf.length());
    }

    public String cursor() {
        return String.valueOf(pos);
    }

    public String undo() {
        if (undoStack.isEmpty()) {
            return "false";
        }
        redoStack.add(new EditorSnap(buf, pos));
        EditorSnap snap = undoStack.remove(undoStack.size() - 1);
        buf = snap.buf;
        pos = snap.pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    public String redo() {
        if (redoStack.isEmpty()) {
            return "false";
        }
        undoStack.add(new EditorSnap(buf, pos));
        EditorSnap snap = redoStack.remove(redoStack.size() - 1);
        buf = snap.buf;
        pos = snap.pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    public String select(int start, int end) {
        if (start < 0 || end < 0 || start > end || end > buf.length()) {
            return "invalid_request";
        }
        selStart = start;
        selEnd = end;
        return "true";
    }

    public String cut() {
        if (selStart < 0 || selStart == selEnd) {
            return "invalid_request";
        }
        String text = buf.substring(selStart, selEnd);
        buf = buf.substring(0, selStart) + buf.substring(selEnd);
        clip = text;
        pos = selStart;
        selStart = -1;
        selEnd = -1;
        return text;
    }

    public String copySel() {
        if (selStart < 0 || selStart == selEnd) {
            return "invalid_request";
        }
        clip = buf.substring(selStart, selEnd);
        return clip;
    }

    public String paste() {
        if (clip.isEmpty()) {
            return "invalid_request";
        }
        int at = pos;
        buf = buf.substring(0, at) + clip + buf.substring(at);
        pos = at + clip.length();
        return String.valueOf(buf.length());
    }
}
