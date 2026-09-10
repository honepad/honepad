class EditorSnap(val buf: String, val pos: Int)

class Simulation {
    private var buf = ""
    private var pos = 0
    private val undoStack = ArrayList<EditorSnap>()
    private val redoStack = ArrayList<EditorSnap>()
    private var selStart = -1
    private var selEnd = -1
    private var clip = ""

    private fun push() {
        undoStack.add(EditorSnap(buf, pos))
        redoStack.clear()
        selStart = -1
        selEnd = -1
    }

    fun insert(at: Int, text: String): String {
        if (at < 0 || at > buf.length) {
            return "invalid_request"
        }
        push()
        buf = buf.substring(0, at) + text + buf.substring(at)
        return buf.length.toString()
    }

    fun erase(at: Int, n: Int): String {
        if (n <= 0 || at < 0 || at + n > buf.length) {
            return "invalid_request"
        }
        push()
        val deleted = buf.substring(at, at + n)
        buf = buf.substring(0, at) + buf.substring(at + n)
        if (pos > buf.length) {
            pos = buf.length
        }
        return deleted
    }

    fun getText(): String = buf

    fun length(): String = buf.length.toString()

    fun move(at: Int): String {
        if (at < 0 || at > buf.length) {
            return "invalid_request"
        }
        pos = at
        return "true"
    }

    fun typeText(text: String): String {
        push()
        val at = pos
        buf = buf.substring(0, at) + text + buf.substring(at)
        pos = at + text.length
        return buf.length.toString()
    }

    fun cursor(): String = pos.toString()

    fun undo(): String {
        if (undoStack.isEmpty()) {
            return "false"
        }
        redoStack.add(EditorSnap(buf, pos))
        val snap = undoStack.removeAt(undoStack.size - 1)
        buf = snap.buf
        pos = snap.pos
        selStart = -1
        selEnd = -1
        return "true"
    }

    fun redo(): String {
        if (redoStack.isEmpty()) {
            return "false"
        }
        undoStack.add(EditorSnap(buf, pos))
        val snap = redoStack.removeAt(redoStack.size - 1)
        buf = snap.buf
        pos = snap.pos
        selStart = -1
        selEnd = -1
        return "true"
    }

    fun select(start: Int, end: Int): String {
        if (start < 0 || end < 0 || start > end || end > buf.length) {
            return "invalid_request"
        }
        selStart = start
        selEnd = end
        return "true"
    }

    fun cut(): String {
        if (selStart < 0 || selStart == selEnd) {
            return "invalid_request"
        }
        val text = buf.substring(selStart, selEnd)
        buf = buf.substring(0, selStart) + buf.substring(selEnd)
        clip = text
        pos = selStart
        selStart = -1
        selEnd = -1
        return text
    }

    fun copySel(): String {
        if (selStart < 0 || selStart == selEnd) {
            return "invalid_request"
        }
        clip = buf.substring(selStart, selEnd)
        return clip
    }

    fun paste(): String {
        if (clip.isEmpty()) {
            return "invalid_request"
        }
        val at = pos
        buf = buf.substring(0, at) + clip + buf.substring(at)
        pos = at + clip.length
        return buf.length.toString()
    }
}
