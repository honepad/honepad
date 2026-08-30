class Simulation:
    def __init__(self):
        pass

    def create_account(self, timestamp, account_id):
        """Create an account. True if created, false if the id exists."""
        raise NotImplementedError

    def deposit(self, timestamp, account_id, amount):
        """Add funds. New balance, or None if the account is missing."""
        raise NotImplementedError

    def transfer(self, timestamp, source_account_id, target_account_id, amount):
        """Move funds. Source balance, or None if missing, same, or broke."""
        raise NotImplementedError

    def top_spenders(self, timestamp, n):
        """Top accounts as id(outgoing). Incoming does not count.

        Example: ["acc1(500)", "acc2(0)"].
        """
        raise NotImplementedError

    def pay(self, timestamp, account_id, amount):
        """Withdraw now. Returns paymentN, or None.

        Example: "payment1".
        """
        raise NotImplementedError

    def get_payment_status(self, timestamp, account_id, payment):
        """IN_PROGRESS or CASHBACK_RECEIVED, or None if wrong."""
        raise NotImplementedError

    def merge_accounts(self, timestamp, account_id_1, account_id_2):
        """Merge account_id_2 into account_id_1, then delete account_id_2.

        Moves balance, outgoing, payments, history, and pending cashbacks.
        False if either id is missing or they are the same.
        """
        raise NotImplementedError

    def get_balance(self, timestamp, account_id, time_at):
        """Balance at time_at after cashbacks due at timestamp."""
        raise NotImplementedError
