class Simulation:
    def __init__(self):
        pass

    def add_file(self, name, size):
        """Admin add. "true" if created, "false" if the name exists."""
        raise NotImplementedError

    def get_file_size(self, name):
        """Size as a string, or "" if missing."""
        raise NotImplementedError

    def delete_file(self, name):
        """Deleted size as a string, or "" if missing."""
        raise NotImplementedError

    def copy_file(self, source, dest):
        """Copy size to dest. Dest size, or "" if missing or over capacity."""
        raise NotImplementedError

    def get_n_largest(self, prefix, n):
        """Up to n files as name(size), ... Empty string if none.

        Example: "/dir/file2(20), /dir/deeper/file3.mov(9)".
        """
        raise NotImplementedError

    def add_user(self, user_id, capacity):
        """Create a user. "true", or "false" if the id exists."""
        raise NotImplementedError

    def add_file_by(self, user_id, name, size):
        """Store as that user. Remaining capacity, or ""."""
        raise NotImplementedError

    def merge_user(self, user_id1, user_id2):
        """Merge user_id2 into user_id1, then delete user_id2.

        Remaining capacity of user_id1, or "".
        """
        raise NotImplementedError

    def backup_user(self, user_id):
        """Snapshot that user's files. File count, or "" if missing."""
        raise NotImplementedError

    def restore_user(self, user_id):
        """Restore latest backup. Count, "0" if none, or "" if missing."""
        raise NotImplementedError
