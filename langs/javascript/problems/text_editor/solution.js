class Simulation {
  constructor() {
    this.buf = "";
    this.pos = 0;
    this.undoStack = [];
    this.redoStack = [];
    this.sel = null;
    this.clip = "";
  }

  _push() {
    this.undoStack.push([this.buf, this.pos]);
    this.redoStack = [];
    this.sel = null;
  }

  insert(pos, text) {
    if (pos < 0 || pos > this.buf.length) return "invalid_request";
    this._push();
    this.buf = this.buf.slice(0, pos) + text + this.buf.slice(pos);
    return String(this.buf.length);
  }

  erase(pos, n) {
    if (n <= 0 || pos < 0 || pos + n > this.buf.length) return "invalid_request";
    this._push();
    const deleted = this.buf.slice(pos, pos + n);
    this.buf = this.buf.slice(0, pos) + this.buf.slice(pos + n);
    if (this.pos > this.buf.length) this.pos = this.buf.length;
    return deleted;
  }

  getText() {
    return this.buf;
  }

  length() {
    return String(this.buf.length);
  }

  move(pos) {
    if (pos < 0 || pos > this.buf.length) return "invalid_request";
    this.pos = pos;
    return "true";
  }

  typeText(text) {
    this._push();
    const at = this.pos;
    this.buf = this.buf.slice(0, at) + text + this.buf.slice(at);
    this.pos = at + text.length;
    return String(this.buf.length);
  }

  cursor() {
    return String(this.pos);
  }

  undo() {
    if (!this.undoStack.length) return "false";
    this.redoStack.push([this.buf, this.pos]);
    const snap = this.undoStack.pop();
    this.buf = snap[0];
    this.pos = snap[1];
    this.sel = null;
    return "true";
  }

  redo() {
    if (!this.redoStack.length) return "false";
    this.undoStack.push([this.buf, this.pos]);
    const snap = this.redoStack.pop();
    this.buf = snap[0];
    this.pos = snap[1];
    this.sel = null;
    return "true";
  }

  select(start, end) {
    if (start < 0 || end < 0 || start > end || end > this.buf.length) {
      return "invalid_request";
    }
    this.sel = [start, end];
    return "true";
  }

  cut() {
    if (!this.sel || this.sel[0] === this.sel[1]) return "invalid_request";
    const [start, end] = this.sel;
    const text = this.buf.slice(start, end);
    this.buf = this.buf.slice(0, start) + this.buf.slice(end);
    this.clip = text;
    this.pos = start;
    this.sel = null;
    return text;
  }

  copySel() {
    if (!this.sel || this.sel[0] === this.sel[1]) return "invalid_request";
    const [start, end] = this.sel;
    this.clip = this.buf.slice(start, end);
    return this.clip;
  }

  paste() {
    if (this.clip === "") return "invalid_request";
    const at = this.pos;
    this.buf = this.buf.slice(0, at) + this.clip + this.buf.slice(at);
    this.pos = at + this.clip.length;
    return String(this.buf.length);
  }
}

module.exports = { Simulation };
