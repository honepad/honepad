# File storage level 4

- `backup_user(user_id)` stores that user's current files. Overwrites a prior backup. Returns the file count, or `""` if the user is missing.
- `restore_user(user_id)` deletes the user's live files, then restores the latest backup. Names owned by another user are skipped. No backup means delete live files and return `"0"`. Merge deletes the dropped user's backup.
