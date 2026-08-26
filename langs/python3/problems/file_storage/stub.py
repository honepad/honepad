class Simulation:
    def __init__(self):
        pass

    def add_file(self, name, size):
        raise NotImplementedError

    def get_file_size(self, name):
        raise NotImplementedError

    def delete_file(self, name):
        raise NotImplementedError

    def get_n_largest(self, prefix, n):
        raise NotImplementedError

    def add_user(self, user_id, capacity):
        raise NotImplementedError

    def add_file_by(self, user_id, name, size):
        raise NotImplementedError

    def merge_user(self, user_id1, user_id2):
        raise NotImplementedError

    def backup_user(self, user_id):
        raise NotImplementedError

    def restore_user(self, user_id):
        raise NotImplementedError
