# Work sources

`next_work_source` in `STATE.json` is authoritative.

Priority (first match wins):

1. `human_gate` set: stop.
2. `ci`: red or missing main run.
3. `issues`: accepted `ready` issues.
4. `contract` / `implement`: next slice from `pr_plan_cursor`.
5. `prove`: `honepad run` on python3 then another CI language.
6. `improve`: one MPI perspective per cycle.
7. `adversary`: after a land.
8. `expand`: next language adapter / reference solution.

## PR plan cursor

- `pr-2` ICA language adapters that replay the same traces
- `pr-3` file_storage traces
- `pr-4` workers traces
- `pr-5` timer unlock of levels
- `pr-6` remaining GCA runners that Ubuntu can execute

`--concurrency 1`. One ready PR.
