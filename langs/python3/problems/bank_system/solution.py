"""Reference bank system. Traces ported from public LibreSignal tests (MIT)."""

from __future__ import annotations

from collections import deque


class Account:
    def __init__(self, account_id: str, created_at: int) -> None:
        self.account_id = account_id
        self.balance = 0
        self.outgoing = 0
        self.payments: dict[str, str] = {}
        self.created_at = created_at
        self.balance_history: list[tuple[int, int]] = [(created_at, 0)]

    def record_balance(self, timestamp: int) -> None:
        self.balance_history.append((timestamp, self.balance))

    def deposit(self, amount: int) -> int:
        self.balance += amount
        return self.balance

    def withdraw(self, amount: int) -> bool:
        if self.balance < amount:
            return False
        self.balance -= amount
        self.outgoing += amount
        return True

    def get_balance_at(self, time_at: int) -> int | None:
        if time_at < self.created_at:
            return None
        result = None
        for ts, balance in self.balance_history:
            if ts <= time_at:
                result = balance
            else:
                break
        return result


class Simulation:
    CASHBACK_DELAY = 24 * 60 * 60 * 1000

    def __init__(self) -> None:
        self.accounts: dict[str, Account] = {}
        self.payment_counter = 0
        self.pending_cashbacks: deque[tuple[int, str, int, str]] = deque()

    def _process_cashbacks(self, timestamp: int) -> None:
        while self.pending_cashbacks and self.pending_cashbacks[0][0] <= timestamp:
            cb_timestamp, account_id, amount, payment_id = self.pending_cashbacks.popleft()
            if account_id in self.accounts:
                account = self.accounts[account_id]
                account.deposit(amount)
                account.payments[payment_id] = "CASHBACK_RECEIVED"
                account.record_balance(cb_timestamp)

    def create_account(self, timestamp: int, account_id: str) -> bool:
        self._process_cashbacks(timestamp)
        if account_id in self.accounts:
            return False
        self.accounts[account_id] = Account(account_id, timestamp)
        return True

    def deposit(self, timestamp: int, account_id: str, amount: int) -> int | None:
        self._process_cashbacks(timestamp)
        if account_id not in self.accounts:
            return None
        account = self.accounts[account_id]
        result = account.deposit(amount)
        account.record_balance(timestamp)
        return result

    def transfer(
        self,
        timestamp: int,
        source_account_id: str,
        target_account_id: str,
        amount: int,
    ) -> int | None:
        self._process_cashbacks(timestamp)
        if source_account_id not in self.accounts or target_account_id not in self.accounts:
            return None
        if source_account_id == target_account_id:
            return None
        source = self.accounts[source_account_id]
        target = self.accounts[target_account_id]
        if not source.withdraw(amount):
            return None
        target.deposit(amount)
        source.record_balance(timestamp)
        target.record_balance(timestamp)
        return source.balance

    def top_spenders(self, timestamp: int, n: int) -> list[str]:
        self._process_cashbacks(timestamp)
        ordered = sorted(
            self.accounts.keys(),
            key=lambda acc: (-self.accounts[acc].outgoing, acc),
        )
        return [f"{acc}({self.accounts[acc].outgoing})" for acc in ordered[:n]]

    def pay(self, timestamp: int, account_id: str, amount: int) -> str | None:
        self._process_cashbacks(timestamp)
        if account_id not in self.accounts:
            return None
        account = self.accounts[account_id]
        if not account.withdraw(amount):
            return None
        self.payment_counter += 1
        payment_id = f"payment{self.payment_counter}"
        account.payments[payment_id] = "IN_PROGRESS"
        account.record_balance(timestamp)
        cashback_amount = amount * 2 // 100
        self.pending_cashbacks.append(
            (timestamp + self.CASHBACK_DELAY, account_id, cashback_amount, payment_id)
        )
        return payment_id

    def get_payment_status(self, timestamp: int, account_id: str, payment: str) -> str | None:
        self._process_cashbacks(timestamp)
        if account_id not in self.accounts:
            return None
        account = self.accounts[account_id]
        if payment not in account.payments:
            return None
        return account.payments[payment]

    def merge_accounts(self, timestamp: int, account_id_1: str, account_id_2: str) -> bool:
        self._process_cashbacks(timestamp)
        if account_id_1 == account_id_2:
            return False
        if account_id_1 not in self.accounts or account_id_2 not in self.accounts:
            return False
        account1 = self.accounts[account_id_1]
        account2 = self.accounts[account_id_2]
        account1.balance += account2.balance
        account1.outgoing += account2.outgoing
        account1.payments.update(account2.payments)
        account1.balance_history.extend(account2.balance_history)
        account1.balance_history.sort(key=lambda x: x[0])
        account1.created_at = min(account1.created_at, account2.created_at)
        account1.record_balance(timestamp)
        pending = list(self.pending_cashbacks)
        self.pending_cashbacks.clear()
        for cb_ts, acc_id, amount, payment_id in pending:
            if acc_id == account_id_2:
                acc_id = account_id_1
            self.pending_cashbacks.append((cb_ts, acc_id, amount, payment_id))
        del self.accounts[account_id_2]
        return True

    def get_balance(self, timestamp: int, account_id: str, time_at: int) -> int | None:
        self._process_cashbacks(timestamp)
        if account_id not in self.accounts:
            return None
        return self.accounts[account_id].get_balance_at(time_at)
