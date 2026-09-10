import java.util.{ArrayList, List => JList}

class EditorSnap(val buf: String, val pos: Int)

class Simulation {
  private var buf = ""
  private var pos = 0
  private val undoStack: JList[EditorSnap] = new ArrayList[EditorSnap]()
  private val redoStack: JList[EditorSnap] = new ArrayList[EditorSnap]()
  private var selStart = -1
  private var selEnd = -1
  private var clip = ""

  private def push(): Unit = {
    undoStack.add(new EditorSnap(buf, pos))
    redoStack.clear()
    selStart = -1
    selEnd = -1
  }

  def insert(at: Int, text: String): String = {
    if (at < 0 || at > buf.length) {
      return "invalid_request"
    }
    push()
    buf = buf.substring(0, at) + text + buf.substring(at)
    String.valueOf(buf.length)
  }

  def erase(at: Int, n: Int): String = {
    if (n <= 0 || at < 0 || at + n > buf.length) {
      return "invalid_request"
    }
    push()
    val deleted = buf.substring(at, at + n)
    buf = buf.substring(0, at) + buf.substring(at + n)
    if (pos > buf.length) {
      pos = buf.length
    }
    deleted
  }

  def getText(): String = buf

  def length(): String = String.valueOf(buf.length)

  def move(at: Int): String = {
    if (at < 0 || at > buf.length) {
      return "invalid_request"
    }
    pos = at
    "true"
  }

  def typeText(text: String): String = {
    push()
    val at = pos
    buf = buf.substring(0, at) + text + buf.substring(at)
    pos = at + text.length
    String.valueOf(buf.length)
  }

  def cursor(): String = String.valueOf(pos)

  def undo(): String = {
    if (undoStack.isEmpty) {
      return "false"
    }
    redoStack.add(new EditorSnap(buf, pos))
    val snap = undoStack.remove(undoStack.size() - 1)
    buf = snap.buf
    pos = snap.pos
    selStart = -1
    selEnd = -1
    "true"
  }

  def redo(): String = {
    if (redoStack.isEmpty) {
      return "false"
    }
    undoStack.add(new EditorSnap(buf, pos))
    val snap = redoStack.remove(redoStack.size() - 1)
    buf = snap.buf
    pos = snap.pos
    selStart = -1
    selEnd = -1
    "true"
  }

  def select(start: Int, end: Int): String = {
    if (start < 0 || end < 0 || start > end || end > buf.length) {
      return "invalid_request"
    }
    selStart = start
    selEnd = end
    "true"
  }

  def cut(): String = {
    if (selStart < 0 || selStart == selEnd) {
      return "invalid_request"
    }
    val text = buf.substring(selStart, selEnd)
    buf = buf.substring(0, selStart) + buf.substring(selEnd)
    clip = text
    pos = selStart
    selStart = -1
    selEnd = -1
    text
  }

  def copySel(): String = {
    if (selStart < 0 || selStart == selEnd) {
      return "invalid_request"
    }
    clip = buf.substring(selStart, selEnd)
    clip
  }

  def paste(): String = {
    if (clip.isEmpty) {
      return "invalid_request"
    }
    val at = pos
    buf = buf.substring(0, at) + clip + buf.substring(at)
    pos = at + clip.length
    String.valueOf(buf.length)
  }
}
