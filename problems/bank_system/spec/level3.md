# Bank system level 3

- `pay(timestamp, account_id, amount)` withdraws now and returns `paymentN` (global counter). Null if missing or insufficient funds. Status starts `IN_PROGRESS`. 2 percent cashback (integer divide) arrives after 24 hours in milliseconds (`86400000`).
- `get_payment_status(timestamp, account_id, payment)` returns `IN_PROGRESS` or `CASHBACK_RECEIVED`, or null if the account or payment is wrong.

Apply due cashbacks at the start of every operation.
