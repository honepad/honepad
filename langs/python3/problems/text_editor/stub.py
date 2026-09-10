class Simulation:
    def __init__(self):
        pass

    def insert(self, pos, text):
        """Insert at pos. New length, or invalid_request."""
        raise NotImplementedError

    def erase(self, pos, n):
        """Deleted substring, or invalid_request."""
        raise NotImplementedError

    def get_text(self):
        """Full buffer."""
        raise NotImplementedError

    def length(self):
        """Length as a string."""
        raise NotImplementedError

    def move(self, pos):
        """Set cursor. "true" or invalid_request."""
        raise NotImplementedError

    def type_text(self, text):
        """Insert at cursor and advance. New length."""
        raise NotImplementedError

    def cursor(self):
        """Current position as a string."""
        raise NotImplementedError

    def undo(self):
        """Revert last insert/erase/type_text. "true" or "false"."""
        raise NotImplementedError

    def redo(self):
        """Reapply an undone op. "true" or "false"."""
        raise NotImplementedError

    def select(self, start, end):
        """Mark [start, end). "true" or invalid_request."""
        raise NotImplementedError

    def cut(self):
        """Delete selection onto clipboard, or invalid_request."""
        raise NotImplementedError

    def copy_sel(self):
        """Copy selection onto clipboard, or invalid_request."""
        raise NotImplementedError

    def paste(self):
        """Insert clipboard at cursor. New length, or invalid_request."""
        raise NotImplementedError
