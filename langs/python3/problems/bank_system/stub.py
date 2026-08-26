class Simulation:
    def __init__(self):
        pass

    def create_account(self, timestamp, account_id):
        raise NotImplementedError

    def deposit(self, timestamp, account_id, amount):
        raise NotImplementedError

    def transfer(self, timestamp, source_account_id, target_account_id, amount):
        raise NotImplementedError

    def top_spenders(self, timestamp, n):
        raise NotImplementedError

    def pay(self, timestamp, account_id, amount):
        raise NotImplementedError

    def get_payment_status(self, timestamp, account_id, payment):
        raise NotImplementedError

    def merge_accounts(self, timestamp, account_id_1, account_id_2):
        raise NotImplementedError

    def get_balance(self, timestamp, account_id, time_at):
        raise NotImplementedError
