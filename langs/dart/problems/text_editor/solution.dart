class EditorSnap {
  EditorSnap(this.buf, this.pos);

  final String buf;
  final int pos;
}

class Simulation {
  String buf = '';
  int pos = 0;
  final List<EditorSnap> undoStack = [];
  final List<EditorSnap> redoStack = [];
  int selStart = -1;
  int selEnd = -1;
  String clip = '';

  void _push() {
    undoStack.add(EditorSnap(buf, pos));
    redoStack.clear();
    selStart = -1;
    selEnd = -1;
  }

  String insert(int at, String text) {
    if (at < 0 || at > buf.length) {
      return 'invalid_request';
    }
    _push();
    buf = buf.substring(0, at) + text + buf.substring(at);
    return '${buf.length}';
  }

  String erase(int at, int n) {
    if (n <= 0 || at < 0 || at + n > buf.length) {
      return 'invalid_request';
    }
    _push();
    final deleted = buf.substring(at, at + n);
    buf = buf.substring(0, at) + buf.substring(at + n);
    if (pos > buf.length) {
      pos = buf.length;
    }
    return deleted;
  }

  String getText() {
    return buf;
  }

  String length() {
    return '${buf.length}';
  }

  String move(int at) {
    if (at < 0 || at > buf.length) {
      return 'invalid_request';
    }
    pos = at;
    return 'true';
  }

  String typeText(String text) {
    _push();
    final at = pos;
    buf = buf.substring(0, at) + text + buf.substring(at);
    pos = at + text.length;
    return '${buf.length}';
  }

  String cursor() {
    return '$pos';
  }

  String undo() {
    if (undoStack.isEmpty) {
      return 'false';
    }
    redoStack.add(EditorSnap(buf, pos));
    final snap = undoStack.removeLast();
    buf = snap.buf;
    pos = snap.pos;
    selStart = -1;
    selEnd = -1;
    return 'true';
  }

  String redo() {
    if (redoStack.isEmpty) {
      return 'false';
    }
    undoStack.add(EditorSnap(buf, pos));
    final snap = redoStack.removeLast();
    buf = snap.buf;
    pos = snap.pos;
    selStart = -1;
    selEnd = -1;
    return 'true';
  }

  String select(int start, int end) {
    if (start < 0 || end < 0 || start > end || end > buf.length) {
      return 'invalid_request';
    }
    selStart = start;
    selEnd = end;
    return 'true';
  }

  String cut() {
    if (selStart < 0 || selStart == selEnd) {
      return 'invalid_request';
    }
    final text = buf.substring(selStart, selEnd);
    buf = buf.substring(0, selStart) + buf.substring(selEnd);
    clip = text;
    pos = selStart;
    selStart = -1;
    selEnd = -1;
    return text;
  }

  String copySel() {
    if (selStart < 0 || selStart == selEnd) {
      return 'invalid_request';
    }
    clip = buf.substring(selStart, selEnd);
    return clip;
  }

  String paste() {
    if (clip.isEmpty) {
      return 'invalid_request';
    }
    final at = pos;
    buf = buf.substring(0, at) + clip + buf.substring(at);
    pos = at + clip.length;
    return '${buf.length}';
  }
}
