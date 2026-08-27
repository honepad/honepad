<?php

class Account
{
    public string $accountId;
    public int $balance = 0;
    public int $outgoing = 0;
    public array $payments = [];
    public int $createdAt;
    public array $balanceHistory;

    public function __construct(string $accountId, int $createdAt)
    {
        $this->accountId = $accountId;
        $this->createdAt = $createdAt;
        $this->balanceHistory = [[$createdAt, 0]];
    }

    public function recordBalance(int $timestamp): void
    {
        $this->balanceHistory[] = [$timestamp, $this->balance];
    }

    public function deposit(int $amount): int
    {
        $this->balance += $amount;
        return $this->balance;
    }

    public function withdraw(int $amount): bool
    {
        if ($this->balance < $amount) {
            return false;
        }
        $this->balance -= $amount;
        $this->outgoing += $amount;
        return true;
    }

    public function getBalanceAt(int $timeAt): ?int
    {
        if ($timeAt < $this->createdAt) {
            return null;
        }
        $result = null;
        foreach ($this->balanceHistory as [$ts, $balance]) {
            if ($ts <= $timeAt) {
                $result = $balance;
            } else {
                break;
            }
        }
        return $result;
    }
}

class Simulation
{
    public const CASHBACK_DELAY = 24 * 60 * 60 * 1000;

    private array $accounts = [];
    private int $paymentCounter = 0;
    private array $pendingCashbacks = [];

    private function processCashbacks(int $timestamp): void
    {
        while ($this->pendingCashbacks !== [] && $this->pendingCashbacks[0][0] <= $timestamp) {
            [$cbTs, $accountId, $amount, $paymentId] = array_shift($this->pendingCashbacks);
            if (array_key_exists($accountId, $this->accounts)) {
                $account = $this->accounts[$accountId];
                $account->deposit($amount);
                $account->payments[$paymentId] = 'CASHBACK_RECEIVED';
                $account->recordBalance($cbTs);
            }
        }
    }

    public function createAccount(int $timestamp, string $accountId): bool
    {
        $this->processCashbacks($timestamp);
        if (array_key_exists($accountId, $this->accounts)) {
            return false;
        }
        $this->accounts[$accountId] = new Account($accountId, $timestamp);
        return true;
    }

    public function deposit(int $timestamp, string $accountId, int $amount): ?int
    {
        $this->processCashbacks($timestamp);
        if (!array_key_exists($accountId, $this->accounts)) {
            return null;
        }
        $account = $this->accounts[$accountId];
        $result = $account->deposit($amount);
        $account->recordBalance($timestamp);
        return $result;
    }

    public function transfer(
        int $timestamp,
        string $sourceAccountId,
        string $targetAccountId,
        int $amount,
    ): ?int {
        $this->processCashbacks($timestamp);
        if (
            !array_key_exists($sourceAccountId, $this->accounts)
            || !array_key_exists($targetAccountId, $this->accounts)
        ) {
            return null;
        }
        if ($sourceAccountId === $targetAccountId) {
            return null;
        }
        $source = $this->accounts[$sourceAccountId];
        $target = $this->accounts[$targetAccountId];
        if (!$source->withdraw($amount)) {
            return null;
        }
        $target->deposit($amount);
        $source->recordBalance($timestamp);
        $target->recordBalance($timestamp);
        return $source->balance;
    }

    public function topSpenders(int $timestamp, int $n): array
    {
        $this->processCashbacks($timestamp);
        $ids = array_keys($this->accounts);
        usort($ids, function (string $a, string $b): int {
            $d = $this->accounts[$b]->outgoing <=> $this->accounts[$a]->outgoing;
            return $d !== 0 ? $d : ($a <=> $b);
        });
        $top = array_slice($ids, 0, $n);
        return array_map(fn ($id) => $id . '(' . $this->accounts[$id]->outgoing . ')', $top);
    }

    public function pay(int $timestamp, string $accountId, int $amount): ?string
    {
        $this->processCashbacks($timestamp);
        if (!array_key_exists($accountId, $this->accounts)) {
            return null;
        }
        $account = $this->accounts[$accountId];
        if (!$account->withdraw($amount)) {
            return null;
        }
        $this->paymentCounter += 1;
        $paymentId = 'payment' . $this->paymentCounter;
        $account->payments[$paymentId] = 'IN_PROGRESS';
        $account->recordBalance($timestamp);
        $this->pendingCashbacks[] = [
            $timestamp + self::CASHBACK_DELAY,
            $accountId,
            intdiv($amount * 2, 100),
            $paymentId,
        ];
        return $paymentId;
    }

    public function getPaymentStatus(int $timestamp, string $accountId, string $payment): ?string
    {
        $this->processCashbacks($timestamp);
        if (!array_key_exists($accountId, $this->accounts)) {
            return null;
        }
        $account = $this->accounts[$accountId];
        if (!array_key_exists($payment, $account->payments)) {
            return null;
        }
        return $account->payments[$payment];
    }

    public function mergeAccounts(int $timestamp, string $accountId1, string $accountId2): bool
    {
        $this->processCashbacks($timestamp);
        if ($accountId1 === $accountId2) {
            return false;
        }
        if (
            !array_key_exists($accountId1, $this->accounts)
            || !array_key_exists($accountId2, $this->accounts)
        ) {
            return false;
        }
        $account1 = $this->accounts[$accountId1];
        $account2 = $this->accounts[$accountId2];
        $account1->balance += $account2->balance;
        $account1->outgoing += $account2->outgoing;
        $account1->payments = array_merge($account1->payments, $account2->payments);
        $account1->balanceHistory = array_merge($account1->balanceHistory, $account2->balanceHistory);
        usort($account1->balanceHistory, fn ($a, $b) => $a[0] <=> $b[0]);
        $account1->createdAt = min($account1->createdAt, $account2->createdAt);
        $account1->recordBalance($timestamp);
        $this->pendingCashbacks = array_map(
            fn ($row) => $row[1] === $accountId2
                ? [$row[0], $accountId1, $row[2], $row[3]]
                : $row,
            $this->pendingCashbacks,
        );
        unset($this->accounts[$accountId2]);
        return true;
    }

    public function getBalance(int $timestamp, string $accountId, int $timeAt): ?int
    {
        $this->processCashbacks($timestamp);
        if (!array_key_exists($accountId, $this->accounts)) {
            return null;
        }
        return $this->accounts[$accountId]->getBalanceAt($timeAt);
    }
}
