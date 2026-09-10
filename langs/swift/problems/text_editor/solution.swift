import Foundation

struct EditorSnap {
  var buf: String
  var pos: Int
}

final class Simulation: Harness {
  private var buf = ""
  private var pos = 0
  private var undoStack: [EditorSnap] = []
  private var redoStack: [EditorSnap] = []
  private var selStart = -1
  private var selEnd = -1
  private var clip = ""

  private func push() {
    undoStack.append(EditorSnap(buf: buf, pos: pos))
    redoStack.removeAll()
    selStart = -1
    selEnd = -1
  }

  private func insert(_ at: Int64, _ text: String) -> String {
    let idx = Int(at)
    if at < 0 || idx > buf.count {
      return "invalid_request"
    }
    push()
    let start = buf.index(buf.startIndex, offsetBy: idx)
    buf.insert(contentsOf: text, at: start)
    return String(buf.count)
  }

  private func erase(_ at: Int64, _ n: Int64) -> String {
    let startOff = Int(at)
    let count = Int(n)
    if n <= 0 || at < 0 || startOff + count > buf.count {
      return "invalid_request"
    }
    push()
    let start = buf.index(buf.startIndex, offsetBy: startOff)
    let end = buf.index(start, offsetBy: count)
    let deleted = String(buf[start..<end])
    buf.removeSubrange(start..<end)
    if pos > buf.count {
      pos = buf.count
    }
    return deleted
  }

  private func getText() -> String { buf }

  private func length() -> String { String(buf.count) }

  private func move(_ at: Int64) -> String {
    let idx = Int(at)
    if at < 0 || idx > buf.count {
      return "invalid_request"
    }
    pos = idx
    return "true"
  }

  private func typeText(_ text: String) -> String {
    push()
    let at = pos
    let start = buf.index(buf.startIndex, offsetBy: at)
    buf.insert(contentsOf: text, at: start)
    pos = at + text.count
    return String(buf.count)
  }

  private func cursor() -> String { String(pos) }

  private func undo() -> String {
    guard let snap = undoStack.popLast() else {
      return "false"
    }
    redoStack.append(EditorSnap(buf: buf, pos: pos))
    buf = snap.buf
    pos = snap.pos
    selStart = -1
    selEnd = -1
    return "true"
  }

  private func redo() -> String {
    guard let snap = redoStack.popLast() else {
      return "false"
    }
    undoStack.append(EditorSnap(buf: buf, pos: pos))
    buf = snap.buf
    pos = snap.pos
    selStart = -1
    selEnd = -1
    return "true"
  }

  private func select(_ start: Int64, _ end: Int64) -> String {
    if start < 0 || end < 0 || start > end || Int(end) > buf.count {
      return "invalid_request"
    }
    selStart = Int(start)
    selEnd = Int(end)
    return "true"
  }

  private func cut() -> String {
    if selStart < 0 || selStart == selEnd {
      return "invalid_request"
    }
    let start = buf.index(buf.startIndex, offsetBy: selStart)
    let end = buf.index(buf.startIndex, offsetBy: selEnd)
    let text = String(buf[start..<end])
    buf.removeSubrange(start..<end)
    clip = text
    pos = selStart
    selStart = -1
    selEnd = -1
    return text
  }

  private func copySel() -> String {
    if selStart < 0 || selStart == selEnd {
      return "invalid_request"
    }
    let start = buf.index(buf.startIndex, offsetBy: selStart)
    let end = buf.index(buf.startIndex, offsetBy: selEnd)
    clip = String(buf[start..<end])
    return clip
  }

  private func paste() -> String {
    if clip.isEmpty {
      return "invalid_request"
    }
    let at = pos
    let start = buf.index(buf.startIndex, offsetBy: at)
    buf.insert(contentsOf: clip, at: start)
    pos = at + clip.count
    return String(buf.count)
  }

  func call(_ method: String, _ args: [Any]) throws -> Any {
    let text: String
    switch method {
    case "insert":
      text = try insert(argI64(args, 0), argStr(args, 1))
    case "erase":
      text = try erase(argI64(args, 0), argI64(args, 1))
    case "getText":
      text = getText()
    case "length":
      text = length()
    case "move":
      text = try move(argI64(args, 0))
    case "typeText":
      text = try typeText(argStr(args, 0))
    case "cursor":
      text = cursor()
    case "undo":
      text = undo()
    case "redo":
      text = redo()
    case "select":
      text = try select(argI64(args, 0), argI64(args, 1))
    case "cut":
      text = cut()
    case "copySel":
      text = copySel()
    case "paste":
      text = paste()
    default:
      throw HarnessError.missingMethod(method)
    }
    return text
  }
}
