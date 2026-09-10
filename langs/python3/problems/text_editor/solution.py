"""Reference text buffer."""

from __future__ import annotations


class Simulation:
    def __init__(self) -> None:
        self.buf = ""
        self.pos = 0
        self.undo_stack: list[tuple[str, int]] = []
        self.redo_stack: list[tuple[str, int]] = []
        self.sel: tuple[int, int] | None = None
        self.clip = ""

    def _push(self) -> None:
        self.undo_stack.append((self.buf, self.pos))
        self.redo_stack.clear()
        self.sel = None

    def insert(self, pos: int, text: str) -> str:
        if pos < 0 or pos > len(self.buf):
            return "invalid_request"
        self._push()
        self.buf = self.buf[:pos] + text + self.buf[pos:]
        return str(len(self.buf))

    def erase(self, pos: int, n: int) -> str:
        if n <= 0 or pos < 0 or pos + n > len(self.buf):
            return "invalid_request"
        self._push()
        deleted = self.buf[pos : pos + n]
        self.buf = self.buf[:pos] + self.buf[pos + n :]
        if self.pos > len(self.buf):
            self.pos = len(self.buf)
        return deleted

    def get_text(self) -> str:
        return self.buf

    def length(self) -> str:
        return str(len(self.buf))

    def move(self, pos: int) -> str:
        if pos < 0 or pos > len(self.buf):
            return "invalid_request"
        self.pos = pos
        return "true"

    def type_text(self, text: str) -> str:
        self._push()
        at = self.pos
        self.buf = self.buf[:at] + text + self.buf[at:]
        self.pos = at + len(text)
        return str(len(self.buf))

    def cursor(self) -> str:
        return str(self.pos)

    def undo(self) -> str:
        if not self.undo_stack:
            return "false"
        self.redo_stack.append((self.buf, self.pos))
        self.buf, self.pos = self.undo_stack.pop()
        self.sel = None
        return "true"

    def redo(self) -> str:
        if not self.redo_stack:
            return "false"
        self.undo_stack.append((self.buf, self.pos))
        self.buf, self.pos = self.redo_stack.pop()
        self.sel = None
        return "true"

    def select(self, start: int, end: int) -> str:
        if start < 0 or end < 0 or start > end or end > len(self.buf):
            return "invalid_request"
        self.sel = (start, end)
        return "true"

    def cut(self) -> str:
        if self.sel is None or self.sel[0] == self.sel[1]:
            return "invalid_request"
        start, end = self.sel
        text = self.buf[start:end]
        self.buf = self.buf[:start] + self.buf[end:]
        self.clip = text
        self.pos = start
        self.sel = None
        return text

    def copy_sel(self) -> str:
        if self.sel is None or self.sel[0] == self.sel[1]:
            return "invalid_request"
        start, end = self.sel
        self.clip = self.buf[start:end]
        return self.clip

    def paste(self) -> str:
        if self.clip == "":
            return "invalid_request"
        at = self.pos
        self.buf = self.buf[:at] + self.clip + self.buf[at:]
        self.pos = at + len(self.clip)
        return str(len(self.buf))
