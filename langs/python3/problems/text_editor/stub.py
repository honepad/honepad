class Simulation:
    def __init__(self):
        pass

    def insert(self, pos, text):
        """Insert at pos. Does not move the cursor. New length, or invalid_request."""
        raise NotImplementedError

    def erase(self, pos, n):
        """Deleted substring, or invalid_request. Cursor stays unless past the new end."""
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
        """Revert last insert, erase, or type_text, and the cursor. "true" or "false"."""
        raise NotImplementedError

    def redo(self):
        """Reapply an undone op. "true" or "false"."""
        raise NotImplementedError

    def select(self, start, end):
        """Mark [start, end). Does not move the cursor. "true" or invalid_request."""
        raise NotImplementedError

    def cut(self):
        """Delete the selection onto the clipboard, move the cursor to its start, and clear it.

        Not undoable. Empty or missing selection is invalid_request.
        """
        raise NotImplementedError

    def copy_sel(self):
        """Copy the selection. Does not move the cursor or clear it. Or invalid_request."""
        raise NotImplementedError

    def paste(self):
        """Insert the clipboard at the cursor and advance. Not undoable.

        New length, or invalid_request.
        """
        raise NotImplementedError
