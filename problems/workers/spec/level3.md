# Workers level 3

- `promote(worker_id, new_position, new_compensation, start_timestamp)` queues one pending change. Applied on the next enter at or after `start_timestamp`. Returns `"success"`, or `"invalid_request"` if the worker is missing or a promo is already pending.
- `calc_salary(worker_id, start_timestamp, end_timestamp)` returns pay for finished sessions overlapping the window: duration * session rate. Empty string if the worker is missing.
