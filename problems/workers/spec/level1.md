# Workers level 1

Office register.

- `add_worker(worker_id, position, compensation)` returns `"true"` if created, `"false"` if the id exists.
- `register(worker_id, timestamp)` toggles in/out. Returns `"registered"`, or `"invalid_request"` if the worker is missing.
- `get(worker_id)` returns total finished time in the office as a string, or `""`.
