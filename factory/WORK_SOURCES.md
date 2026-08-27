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
- `pr-7` rust ICA runner for the same traces
- `pr-8` ruby ICA runner for the same traces
- `pr-9` php ICA runner for the same traces
- `pr-10` java ICA runner for the same traces
- `pr-11` typescript ICA runner for the same traces
- `pr-12` csharp ICA runner for the same traces
- `pr-13` kotlin ICA runner for the same traces
- `pr-14` cpp ICA runner for the same traces
- `pr-15` swift ICA runner for the same traces
- `pr-16` prove python3+go on all problems
- `pr-17` auto-approve on ready_for_review
- `pr-18` first MPI pass on the runner
- `pr-19` next MPI (QA: stub fails for every script lang)
- `pr-20` next MPI (timer remaining_s after mocked clock)
- `pr-21` next MPI (unlock does not skip a level)
- `pr-22` next MPI (start --reset clears unlock)
- `pr-23` next MPI (start different problem replaces session)
- `pr-24` next MPI (start same problem keeps unlock)
- `pr-25` next MPI (expired timer remaining_s is 0)
- `pr-26` next MPI (CLI run --kind stub does not unlock)
- `pr-27` next MPI (start --level 1 after unlock still prints L1 spec)
- `pr-28` next MPI (start without --level after unlock prints current spec)
- `pr-29` next MPI (explicit --level 4 run still works with a session)
- `pr-30` next MPI (run without session defaults to python3 level 4)
- `pr-31` share temp-dir compile for go rust java csharp kotlin cpp swift
- `pr-32` next MPI (QA: go stub fails bank traces)

`--concurrency 1`. One ready PR.
