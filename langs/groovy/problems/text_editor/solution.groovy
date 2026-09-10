class EditorSnap {
    final String buf
    final int pos

    EditorSnap(String buf, int pos) {
        this.buf = buf
        this.pos = pos
    }
}

class Simulation {
    private String buf = ''
    private int pos = 0
    private final List<EditorSnap> undoStack = []
    private final List<EditorSnap> redoStack = []
    private int selStart = -1
    private int selEnd = -1
    private String clip = ''

    private void push() {
        undoStack.add(new EditorSnap(buf, pos))
        redoStack.clear()
        selStart = -1
        selEnd = -1
    }

    String insert(long at, String text) {
        if (at < 0 || at > buf.length()) {
            return 'invalid_request'
        }
        push()
        int posAt = (int) at
        buf = buf.substring(0, posAt) + text + buf.substring(posAt)
        return String.valueOf(buf.length())
    }

    String erase(long at, long n) {
        if (n <= 0 || at < 0 || at + n > buf.length()) {
            return 'invalid_request'
        }
        push()
        int posAt = (int) at
        int count = (int) n
        String deleted = buf.substring(posAt, posAt + count)
        buf = buf.substring(0, posAt) + buf.substring(posAt + count)
        if (pos > buf.length()) {
            pos = buf.length()
        }
        return deleted
    }

    String getText() {
        return buf
    }

    String length() {
        return String.valueOf(buf.length())
    }

    String move(long at) {
        if (at < 0 || at > buf.length()) {
            return 'invalid_request'
        }
        pos = (int) at
        return 'true'
    }

    String typeText(String text) {
        push()
        int at = pos
        buf = buf.substring(0, at) + text + buf.substring(at)
        pos = at + text.length()
        return String.valueOf(buf.length())
    }

    String cursor() {
        return String.valueOf(pos)
    }

    String undo() {
        if (undoStack.isEmpty()) {
            return 'false'
        }
        redoStack.add(new EditorSnap(buf, pos))
        EditorSnap snap = undoStack.remove(undoStack.size() - 1)
        buf = snap.buf
        pos = snap.pos
        selStart = -1
        selEnd = -1
        return 'true'
    }

    String redo() {
        if (redoStack.isEmpty()) {
            return 'false'
        }
        undoStack.add(new EditorSnap(buf, pos))
        EditorSnap snap = redoStack.remove(redoStack.size() - 1)
        buf = snap.buf
        pos = snap.pos
        selStart = -1
        selEnd = -1
        return 'true'
    }

    String select(long start, long end) {
        if (start < 0 || end < 0 || start > end || end > buf.length()) {
            return 'invalid_request'
        }
        selStart = (int) start
        selEnd = (int) end
        return 'true'
    }

    String cut() {
        if (selStart < 0 || selStart == selEnd) {
            return 'invalid_request'
        }
        String text = buf.substring(selStart, selEnd)
        buf = buf.substring(0, selStart) + buf.substring(selEnd)
        clip = text
        pos = selStart
        selStart = -1
        selEnd = -1
        return text
    }

    String copySel() {
        if (selStart < 0 || selStart == selEnd) {
            return 'invalid_request'
        }
        clip = buf.substring(selStart, selEnd)
        return clip
    }

    String paste() {
        if (clip.isEmpty()) {
            return 'invalid_request'
        }
        int at = pos
        buf = buf.substring(0, at) + clip + buf.substring(at)
        pos = at + clip.length()
        return String.valueOf(buf.length())
    }
}
