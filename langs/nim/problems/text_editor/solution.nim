type
  EditorSnap = object
    buf: string
    pos: int64

  Simulation = ref object
    buf: string
    pos: int64
    undoStack: seq[EditorSnap]
    redoStack: seq[EditorSnap]
    selStart: int64
    selEnd: int64
    clip: string

proc push(self: Simulation) =
  self.undoStack.add(EditorSnap(buf: self.buf, pos: self.pos))
  self.redoStack.setLen(0)
  self.selStart = -1
  self.selEnd = -1

proc insert(self: Simulation; at: int64; text: string): string =
  if at < 0 or at > self.buf.len:
    return "invalid_request"
  self.push()
  self.buf = self.buf[0 ..< at] & text & self.buf[at .. ^1]
  result = $self.buf.len

proc erase(self: Simulation; at, n: int64): string =
  if n <= 0 or at < 0 or at + n > self.buf.len:
    return "invalid_request"
  self.push()
  let deleted = self.buf[at ..< at + n]
  self.buf = self.buf[0 ..< at] & self.buf[at + n .. ^1]
  if self.pos > self.buf.len:
    self.pos = self.buf.len
  result = deleted

proc getText(self: Simulation): string =
  result = self.buf

proc length(self: Simulation): string =
  result = $self.buf.len

proc move(self: Simulation; at: int64): string =
  if at < 0 or at > self.buf.len:
    return "invalid_request"
  self.pos = at
  result = "true"

proc typeText(self: Simulation; text: string): string =
  self.push()
  let at = self.pos
  self.buf = self.buf[0 ..< at] & text & self.buf[at .. ^1]
  self.pos = at + text.len
  result = $self.buf.len

proc cursor(self: Simulation): string =
  result = $self.pos

proc undo(self: Simulation): string =
  if self.undoStack.len == 0:
    return "false"
  self.redoStack.add(EditorSnap(buf: self.buf, pos: self.pos))
  let snap = self.undoStack.pop()
  self.buf = snap.buf
  self.pos = snap.pos
  self.selStart = -1
  self.selEnd = -1
  result = "true"

proc redo(self: Simulation): string =
  if self.redoStack.len == 0:
    return "false"
  self.undoStack.add(EditorSnap(buf: self.buf, pos: self.pos))
  let snap = self.redoStack.pop()
  self.buf = snap.buf
  self.pos = snap.pos
  self.selStart = -1
  self.selEnd = -1
  result = "true"

proc select(self: Simulation; start, endPos: int64): string =
  if start < 0 or endPos < 0 or start > endPos or endPos > self.buf.len:
    return "invalid_request"
  self.selStart = start
  self.selEnd = endPos
  result = "true"

proc cut(self: Simulation): string =
  if self.selStart < 0 or self.selStart == self.selEnd:
    return "invalid_request"
  let text = self.buf[self.selStart ..< self.selEnd]
  self.buf = self.buf[0 ..< self.selStart] & self.buf[self.selEnd .. ^1]
  self.clip = text
  self.pos = self.selStart
  self.selStart = -1
  self.selEnd = -1
  result = text

proc copySel(self: Simulation): string =
  if self.selStart < 0 or self.selStart == self.selEnd:
    return "invalid_request"
  self.clip = self.buf[self.selStart ..< self.selEnd]
  result = self.clip

proc paste(self: Simulation): string =
  if self.clip.len == 0:
    return "invalid_request"
  let at = self.pos
  self.buf = self.buf[0 ..< at] & self.clip & self.buf[at .. ^1]
  self.pos = at + self.clip.len
  result = $self.buf.len
