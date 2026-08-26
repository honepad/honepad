# Bank system level 4

- `merge_accounts(timestamp, keep, drop)` moves balance, outgoing, payments, history, and pending cashbacks onto `keep`, then deletes `drop`. False if either id is missing or they are the same.
- `get_balance(timestamp, account_id, time_at)` returns the balance recorded at or before `time_at`, after applying cashbacks due at `timestamp`.
